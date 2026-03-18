//
//  JITSupport.m
//  Reynard
//
//  Created by Minh Ton on 11/3/2026.
//

#import "JITSupport.h"
#import "JITUtils.h"
#import "IdeviceFFI.h"

#include <arpa/inet.h>
#include <unistd.h>

static const char *providerLabel = "Reynard";
static const uint16_t lockdownPort = 62078;

struct DeviceProvider {
    IdeviceProviderHandle *handle;
    HeartbeatClientHandle *heartbeatClient;
    BOOL heartbeatRunning;
};

dispatch_queue_t debugServiceQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        queue = dispatch_queue_create("me.minh-ton.jit.debug-service", DISPATCH_QUEUE_CONCURRENT);
    });
    return queue;
}

static void startHeartbeat(DeviceProvider *provider) {
    dispatch_queue_t heartbeatQueue = dispatch_queue_create("me.minh-ton.jit.provider-heartbeat",DISPATCH_QUEUE_SERIAL);
    provider->heartbeatRunning = YES;
    
    dispatch_async(heartbeatQueue, ^{
        uint64_t currentInterval = 15;
        while (provider->heartbeatRunning) {
            uint64_t newInterval = 0;
            IdeviceFfiError *ffiError = heartbeat_get_marco(provider->heartbeatClient, currentInterval, &newInterval);
            
            if (!provider->heartbeatRunning) break;
            
            if (ffiError) {
                idevice_error_free(ffiError);
                break;
            }
            
            ffiError = heartbeat_send_polo(provider->heartbeatClient);
            if (ffiError) {
                idevice_error_free(ffiError);
                break;
            }
            
            currentInterval = (newInterval > 0) ? (newInterval + 5) : 15;
        }
    });
}

BOOL sendDebugCommand(DebugProxyHandle *debugProxy, NSString *commandString, NSString **responseOut, NSError **error) {
    DebugserverCommandHandle *command = debugserver_command_new(commandString.UTF8String, NULL, 0);
    if (!command) {
        if (error) *error = errorWithCode(-6, [NSString stringWithFormat:@"Failed to create debugserver command %@", commandString]);
        return NO;
    }
    
    char *response = NULL;
    IdeviceFfiError *ffiError = debug_proxy_send_command(debugProxy, command, &response);
    debugserver_command_free(command);
    
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithFormat:@"Debug command %@ failed: %@", commandString, [NSString stringWithUTF8String:ffiError->message ?: "unknown error"]];
            *error = errorWithCode(ffiError->code, description);
        }
        
        idevice_error_free(ffiError);
        if (response) idevice_string_free(response);
        return NO;
    }
    
    if (responseOut) *responseOut = response ? [NSString stringWithUTF8String:response] : nil;
    if (response) idevice_string_free(response);
    
    return YES;
}

static BOOL forwardSignalStop(DebugProxyHandle *debugProxy, NSString *signal, NSString *threadID, NSError **error) {
    NSString *continueCommand = [NSString stringWithFormat:@"vCont;S%@:%@", signal, threadID];
    NSString *stopResponse = nil;
    return sendDebugCommand(debugProxy, continueCommand, &stopResponse, error);
}

static BOOL writeRegisterValue(DebugProxyHandle *debugProxy, NSString *registerName, uint64_t value, NSString *threadID, NSError **error) {
    NSString *response = nil;
    NSString *command = [NSString stringWithFormat:@"P%@=%@;thread:%@;", registerName, encodeLittleEndianHex64(value), threadID];
    
    if (!sendDebugCommand(debugProxy, command, &response, error)) return NO;
    if (response.length > 0 && ![response isEqualToString:@"OK"]) {
        if (error) *error = errorWithCode(-7, [NSString stringWithFormat:@"Unexpected register write response %@", response]);
        return NO;
    }
    
    return YES;
}

BOOL configureNoAckMode(DebugProxyHandle *debugProxy, NSString **responseOut, NSError **error) {
    for (NSUInteger ackCount = 0; ackCount < 2; ackCount++) {
        IdeviceFfiError *ffiError = debug_proxy_send_ack(debugProxy);
        if (!ffiError) continue;
        
        if (error) {
            NSString *description = [NSString stringWithFormat:@"Failed to send debug ACK: %@", [NSString stringWithUTF8String:ffiError->message ?: "unknown error"]];
            *error = errorWithCode(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        return NO;
    }
    
    NSString *response = nil;
    if (!sendDebugCommand(debugProxy, @"QStartNoAckMode", &response, error)) return NO;
    if (response.length > 0 && ![response isEqualToString:@"OK"]) {
        if (error) *error = errorWithCode(-9, [NSString stringWithFormat:@"Unexpected no-ack response %@", response]);
        return NO;
    }
    
    debug_proxy_set_ack_mode(debugProxy, 0);
    if (responseOut) {
        *responseOut = response;
    }
    return YES;
}

BOOL connectDebugSession(DeviceProvider *provider, DebugSession *session, NSError **error) {
    IdeviceFfiError *ffiError = NULL;
    CoreDeviceProxyHandle *coreDevice = NULL;
    ReadWriteOpaque *stream = NULL;
    
    ffiError = core_device_proxy_connect(provider->handle, &coreDevice);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to connect CoreDeviceProxy."];
            *error = errorWithCode(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        return NO;
    }
    
    uint16_t rsdPort = 0;
    ffiError = core_device_proxy_get_server_rsd_port(coreDevice, &rsdPort);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to resolve RSD port."];
            *error = errorWithCode(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        core_device_proxy_free(coreDevice);
        return NO;
    }
    
    ffiError = core_device_proxy_create_tcp_adapter(coreDevice, &session->adapter);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to create CoreDevice adapter."];
            *error = errorWithCode(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        core_device_proxy_free(coreDevice);
        return NO;
    }
    coreDevice = NULL;
    
    ffiError = adapter_connect(session->adapter, rsdPort, &stream);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to connect adapter stream."];
            *error = errorWithCode(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        freeDebugSession(session);
        return NO;
    }
    
    ffiError = rsd_handshake_new(stream, &session->handshake);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to complete RSD handshake."];
            *error = errorWithCode(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        freeDebugSession(session);
        return NO;
    }
    stream = NULL;
    
    ffiError = remote_server_connect_rsd(session->adapter, session->handshake, &session->remoteServer);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to connect remote server."];
            *error = errorWithCode(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        freeDebugSession(session);
        return NO;
    }
    
    ffiError = debug_proxy_connect_rsd(session->adapter, session->handshake, &session->debugProxy);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to connect debug proxy."];
            *error = errorWithCode(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        freeDebugSession(session);
        return NO;
    }
    
    return YES;
}

static BOOL prepareMemoryRegion(DebugProxyHandle *debugProxy, uint64_t startAddress, uint64_t regionSize, uint64_t writableSourceAddress, NSError **error) {
    uint64_t size = regionSize == 0 ? 0x4000 : regionSize;
    
    for (uint64_t currentAddress = startAddress; currentAddress < startAddress + size; currentAddress += 0x4000) {
        uint64_t sourceAddress = currentAddress;
        if (writableSourceAddress != 0) sourceAddress = writableSourceAddress + (currentAddress - startAddress);
        
        NSString *existingByte = nil;
        NSString *readCommand = [NSString stringWithFormat:@"m%llx,1", sourceAddress];
        if (!sendDebugCommand(debugProxy, readCommand, &existingByte, error)) return NO;
        
        if (!existingByte || existingByte.length < 2) {
            if (error && !*error)
                *error = errorWithCode(-12, [NSString stringWithFormat:@"Failed to read prepare-region byte at 0x%llx (source 0x%llx)", currentAddress, sourceAddress]);
            return NO;
        }
        
        NSString *command = [NSString stringWithFormat:@"M%llx,1:%@", currentAddress, [existingByte substringToIndex:2]];
        NSString *response = nil;
        
        if (!sendDebugCommand(debugProxy, command, &response, error)) return NO;
        if (response.length > 0 && ![response isEqualToString:@"OK"]) {
            if (error) *error = errorWithCode(-7, [NSString stringWithFormat:@"Unexpected prepare-region response %@", response]);
            return NO;
        }
    }
    
    return YES;
}

static BOOL allocateRXRegion(DebugProxyHandle *debugProxy, uint64_t regionSize, uint64_t *addressOut, NSError **error) {
    NSString *response = nil;
    NSString *command = [NSString stringWithFormat:@"_M%llx,rx", regionSize];
    
    if (!sendDebugCommand(debugProxy, command, &response, error)) return NO;
    
    if (response.length == 0) {
        if (error) *error = errorWithCode(-10, @"RX allocation returned an empty response.");
        return NO;
    }
    
    uint64_t address = 0;
    NSScanner *scanner = [NSScanner scannerWithString:response];
    if (![scanner scanHexLongLong:&address]) {
        if (error) *error = errorWithCode(-11, [NSString stringWithFormat:@"RX allocation returned invalid address %@", response]);
        return NO;
    }
    
    if (addressOut) *addressOut = address;
    return YES;
}

void runDebugService(int32_t pid, DebugSession *session, DeviceLogHandler logHandler) {
    NSError *commandError = nil;
    BOOL exitPacketPresent = NO;
    BOOL detachedByCommand = NO;
    
    while (YES) {
        NSString *stopResponse = nil;
        commandError = nil;
        
        if (!sendDebugCommand(session->debugProxy, @"c", &stopResponse, &commandError)) {
            if (!isNotConnectedError(commandError)) logger([NSString stringWithFormat:@"Debug loop ended for pid %d: %@", pid, commandError.localizedDescription ?: @"continue failed"], logHandler);
            break;
        }
        
        if ([stopResponse hasPrefix:@"W"] || [stopResponse hasPrefix:@"X"]) {
            exitPacketPresent = YES;
            logger([NSString stringWithFormat:@"Target exited for pid %d with packet %@", pid, stopResponse], logHandler);
            break;
        }
        
        NSString *threadID = packetField(stopResponse, @"thread");
        NSString *pcField = packetField(stopResponse, @"20");
        NSString *x0Field = packetField(stopResponse, @"00");
        NSString *x1Field = packetField(stopResponse, @"01");
        NSString *x2Field = packetField(stopResponse, @"02");
        NSString *x16Field = packetField(stopResponse, @"10");
        
        uint64_t pc = parseLittleEndianHex64(pcField);
        uint64_t x0 = x0Field ? parseLittleEndianHex64(x0Field) : 0;
        uint64_t x1 = x1Field ? parseLittleEndianHex64(x1Field) : 0;
        uint64_t x2 = x2Field ? parseLittleEndianHex64(x2Field) : 0;
        uint64_t x16 = x16Field ? parseLittleEndianHex64(x16Field) : 0;
        
        NSString *instructionResponse = nil;
        NSString *readInstruction = [NSString stringWithFormat:@"m%llx,4", pc];
        if (!sendDebugCommand(session->debugProxy, readInstruction, &instructionResponse, &commandError)) instructionResponse = nil;
        
        uint32_t instruction = (uint32_t)parseLittleEndianHex64(instructionResponse ?: @"");
        if (instructionResponse.length == 0 || !instructionIsBreakpoint(instruction)) {
            NSString *signal = packetSignal(stopResponse);
            if (signal && !forwardSignalStop(session->debugProxy, signal, threadID, &commandError)) break;
            continue;
        }
        
        uint16_t breakpointImmediate = (instruction >> 5) & 0xffff;
        uint64_t executableAddress = x0;
        
        if (breakpointImmediate == 0xf00d) {
            if (!threadID || !x16Field) break;
            if (!writeRegisterValue(session->debugProxy, @"20", pc + 4, threadID, &commandError)) break;
            
            if (x16 == 0) {
                detachedByCommand = YES;
                
                NSString *detachResponse = nil;
                NSError *detachError = nil;
                if (sendDebugCommand(session->debugProxy, @"D", &detachResponse, &detachError)) {
                    logger([NSString stringWithFormat:@"Detach response for pid %d: %@", pid, detachResponse ?: @"<no response>"], logHandler);
                } else if (!isNotConnectedError(detachError)) {
                    logger([NSString stringWithFormat:@"Detach failed for pid %d: %@", pid, detachError.localizedDescription ?: @"detach failed"], logHandler);
                }
                break;
            }
            
            if (x16 == 1) {
                if (!x1Field) break;
                
                if (executableAddress == 0) {
                    if (!allocateRXRegion(session->debugProxy, x1, &executableAddress, &commandError)) break;
                    logger([NSString stringWithFormat:@"Allocated RX region for pid %d at 0x%llx size=0x%llx", pid, executableAddress, x1], logHandler);
                }
                
                if (!prepareMemoryRegion(session->debugProxy, executableAddress, x1, 0, &commandError)) break;
                if (!writeRegisterValue(session->debugProxy, @"0", executableAddress, threadID, &commandError)) break;
                continue;
            }
            
            if (x16 == 2) {
                logger([NSString stringWithFormat:@"Received unsupported 0xf00d x16 command 0x%llx for pid %d", x16, pid], logHandler);
                if (!writeRegisterValue(session->debugProxy, @"0", 0xE0000002ull, threadID, &commandError)) break;
                continue;
            }
            
            logger([NSString stringWithFormat:@"Received unknown 0xf00d x16 command 0x%llx for pid %d", x16, pid], logHandler);
            if (!writeRegisterValue(session->debugProxy, @"0", (0xE0000000ull | (x16 & 0xffffull)), threadID, &commandError)) break;
            continue;
        } else if (breakpointImmediate == 0x69) {
            if (!x0Field || !x1Field) break;
            
            uint64_t regionSize = x2 != 0 ? x2 : x1;
            uint64_t writableSourceAddress = x2 != 0 ? x1 : 0;
            
            if (!prepareMemoryRegion(session->debugProxy, x0, regionSize, writableSourceAddress, &commandError)) break;
            if (!writeRegisterValue(session->debugProxy, @"20", pc + 4, threadID, &commandError)) break;
        } else {
            continue;
        }
    }
    
    if (!exitPacketPresent && !detachedByCommand) {
        NSString *detachResponse = nil;
        NSError *detachError = nil;
        if (sendDebugCommand(session->debugProxy, @"D", &detachResponse, &detachError)) {
            logger([NSString stringWithFormat:@"Detach response for pid %d: %@", pid, detachResponse ?: @"<no response>"], logHandler);
        } else if (!isNotConnectedError(detachError)) {
            logger([NSString stringWithFormat:@"Detach failed for pid %d: %@", pid, detachError.localizedDescription ?: @"detach failed"], logHandler);
        }
    }
    
    freeDebugSession(session);
    free(session);
}

DeviceProvider *createDeviceProvider(NSString *pairingFilePath, NSString *targetAddress, NSError **error) {
    if (![[NSFileManager defaultManager] fileExistsAtPath:pairingFilePath]) {
        if (error) *error = errorWithCode(-2, @"Pairing file not found in Documents.");
        return NULL;
    }
    
    IdevicePairingFile *pairingFile = NULL;
    IdeviceFfiError *ffiError = idevice_pairing_file_read(pairingFilePath.fileSystemRepresentation, &pairingFile);
    
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to read pairing file."];
            *error = errorWithCode(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        return NULL;
    }
    
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_port = htons(lockdownPort);
    
    if (inet_pton(AF_INET, targetAddress.UTF8String, &address.sin_addr) != 1) {
        idevice_pairing_file_free(pairingFile);
        if (error) *error = errorWithCode(-3, @"Invalid target IP address.");
        return NULL;
    }
    
    IdeviceProviderHandle *providerHandle = NULL;
    ffiError = idevice_tcp_provider_new((const struct sockaddr *)&address, pairingFile, providerLabel, &providerHandle);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to create idevice provider."];
            *error = errorWithCode(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        return NULL;
    }
    
    HeartbeatClientHandle *heartbeatClient = NULL;
    ffiError = heartbeat_connect(providerHandle, &heartbeatClient);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to connect heartbeat service."];
            *error = errorWithCode(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        idevice_provider_free(providerHandle);
        return NULL;
    }
    
    uint64_t nextInterval = 0;
    ffiError = heartbeat_get_marco(heartbeatClient, 15, &nextInterval);
    if (!ffiError) ffiError = heartbeat_send_polo(heartbeatClient);
    
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Heartbeat failed."];
            *error = errorWithCode(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        heartbeat_client_free(heartbeatClient);
        idevice_provider_free(providerHandle);
        return NULL;
    }
    
    DeviceProvider *provider = malloc(sizeof(*provider));
    if (!provider) {
        idevice_provider_free(providerHandle);
        if (error) *error = errorWithCode(-5, @"Failed to allocate device provider.");
        return NULL;
    }
    
    provider->handle = providerHandle;
    provider->heartbeatClient = heartbeatClient;
    provider->heartbeatRunning = NO;
    
    startHeartbeat(provider);
    
    return provider;
}

void freeDebugSession(DebugSession *session) {
    if (session->debugProxy) { debug_proxy_free(session->debugProxy); session->debugProxy = NULL; }
    if (session->remoteServer) { remote_server_free(session->remoteServer); session->remoteServer = NULL; }
    if (session->handshake) { rsd_handshake_free(session->handshake); session->handshake = NULL; }
    if (session->adapter) { adapter_free(session->adapter); session->adapter = NULL; }
}

void freeDeviceProvider(DeviceProvider *provider) {
    if (!provider) return;
    provider->heartbeatRunning = NO;
    if (provider->heartbeatClient) { heartbeat_client_free(provider->heartbeatClient); provider->heartbeatClient = NULL; }
    if (provider->handle) { idevice_provider_free(provider->handle); provider->handle = NULL; }
    free(provider);
}
