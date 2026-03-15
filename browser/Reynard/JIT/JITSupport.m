//
//  JITSupport.m
//  Reynard
//
//  Created by Minh Ton on 11/03/2026.
//

#import "JITSupport.h"

#include <arpa/inet.h>
#include <unistd.h>

#import "IdeviceFFI.h"

static NSString *const supportErrorDomain = @"JITSupport";
static const char *providerLabel = "Reynard";
static const uint16_t lockdownPort = 62078;
struct DeviceProvider {
    IdeviceProviderHandle *handle;
    HeartbeatClientHandle *heartbeatClient;
    BOOL heartbeatRunning;
};

typedef struct {
    AdapterHandle *adapter;
    RsdHandshakeHandle *handshake;
    RemoteServerHandle *remoteServer;
    DebugProxyHandle *debugProxy;
} DebugSession;

static dispatch_queue_t debugServiceQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("me.minh-ton.jit.debug-service", DISPATCH_QUEUE_CONCURRENT);
    });
    return queue;
}

static NSError *createError(NSInteger code, NSString *description) {
    return [NSError errorWithDomain:supportErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

static void emitLog(NSString *message, DeviceLogHandler logHandler) {
    if (logHandler) {
        logHandler(message);
    }
}

static void DebugSessionFree(DebugSession *session) {
    if (session->debugProxy) {
        debug_proxy_free(session->debugProxy);
        session->debugProxy = NULL;
    }
    if (session->remoteServer) {
        remote_server_free(session->remoteServer);
        session->remoteServer = NULL;
    }
    if (session->handshake) {
        rsd_handshake_free(session->handshake);
        session->handshake = NULL;
    }
    if (session->adapter) {
        adapter_free(session->adapter);
        session->adapter = NULL;
    }
}

static void startProviderHeartbeat(DeviceProvider *provider) {
    if (!provider || !provider->heartbeatClient) {
        return;
    }
    
    dispatch_queue_t heartbeatQueue = dispatch_queue_create("me.minh-ton.jit.provider-heartbeat",
                                                            DISPATCH_QUEUE_SERIAL);
    provider->heartbeatRunning = YES;
    
    dispatch_async(heartbeatQueue, ^{
        uint64_t currentInterval = 15;
        while (provider->heartbeatRunning) {
            uint64_t newInterval = 0;
            IdeviceFfiError *ffiError = heartbeat_get_marco(provider->heartbeatClient,
                                                            currentInterval,
                                                            &newInterval);
            if (!provider->heartbeatRunning) {
                break;
            }
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

static BOOL sendDebugCommand(DebugProxyHandle *debugProxy,
                             NSString *commandString,
                             NSString **responseOut,
                             NSError **error) {
    DebugserverCommandHandle *command = debugserver_command_new(commandString.UTF8String, NULL, 0);
    if (!command) {
        if (error) {
            *error = createError(-6, [NSString stringWithFormat:@"Failed to create debugserver command %@", commandString]);
        }
        return NO;
    }
    
    char *response = NULL;
    IdeviceFfiError *ffiError = debug_proxy_send_command(debugProxy, command, &response);
    debugserver_command_free(command);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithFormat:@"Debug command %@ failed: %@",
                                     commandString,
                                     [NSString stringWithUTF8String:ffiError->message ?: "unknown error"]];
            *error = createError(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        if (response) {
            idevice_string_free(response);
        }
        return NO;
    }
    
    if (responseOut) {
        *responseOut = response ? [NSString stringWithUTF8String:response] : nil;
    }
    if (response) {
        idevice_string_free(response);
    }
    return YES;
}

static BOOL readDebugResponse(DebugProxyHandle *debugProxy,
                              NSString **responseOut,
                              NSError **error) {
    char *response = NULL;
    IdeviceFfiError *ffiError = debug_proxy_read_response(debugProxy, &response);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithFormat:@"Failed to read debug response: %@",
                                     [NSString stringWithUTF8String:ffiError->message ?: "unknown error"]];
            *error = createError(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        if (response) {
            idevice_string_free(response);
        }
        return NO;
    }
    
    if (responseOut) {
        *responseOut = response ? [NSString stringWithUTF8String:response] : nil;
    }
    if (response) {
        idevice_string_free(response);
    }
    return YES;
}

static uint64_t parseLittleEndianHex64(NSString *hexString) {
    uint64_t value = 0;
    NSUInteger length = hexString.length;
    for (NSUInteger index = 0; index + 1 < length; index += 2) {
        NSString *byteString = [hexString substringWithRange:NSMakeRange(index, 2)];
        unsigned byteValue = 0;
        [[NSScanner scannerWithString:byteString] scanHexInt:&byteValue];
        value |= ((uint64_t)(byteValue & 0xff)) << ((index / 2) * 8);
    }
    return value;
}

static uint32_t parseLittleEndianHex32(NSString *hexString) {
    return (uint32_t)parseLittleEndianHex64(hexString);
}

static BOOL parseHexU64(NSString *hexString, uint64_t *valueOut) {
    if (hexString.length == 0) {
        return NO;
    }
    
    unsigned long long parsed = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    if (![scanner scanHexLongLong:&parsed]) {
        return NO;
    }
    
    if (valueOut) {
        *valueOut = (uint64_t)parsed;
    }
    return YES;
}

static NSString *encodeLittleEndianHex64(uint64_t value) {
    NSMutableString *hex = [NSMutableString stringWithCapacity:16];
    for (NSUInteger index = 0; index < 8; index++) {
        [hex appendFormat:@"%02llx", (value >> (index * 8)) & 0xffull];
    }
    return hex;
}

static NSString *registerWriteCommand(NSString *registerName,
                                      uint64_t value,
                                      NSString *threadID) {
    return [NSString stringWithFormat:@"P%@=%@;thread:%@;",
            registerName,
            encodeLittleEndianHex64(value),
            threadID];
}

static NSData *dataFromHexString(NSString *hexString) {
    if (hexString.length == 0 || (hexString.length % 2) != 0) {
        return nil;
    }
    
    NSMutableData *data = [NSMutableData dataWithLength:hexString.length / 2];
    uint8_t *bytes = (uint8_t *)data.mutableBytes;
    for (NSUInteger index = 0; index < hexString.length; index += 2) {
        NSString *byteString = [hexString substringWithRange:NSMakeRange(index, 2)];
        unsigned byteValue = 0;
        if (![[NSScanner scannerWithString:byteString] scanHexInt:&byteValue]) {
            return nil;
        }
        bytes[index / 2] = (uint8_t)(byteValue & 0xffu);
    }
    return data;
}

static NSArray<NSString *> *packetFields(NSString *packet, NSString *fieldName) {
    NSMutableArray<NSString *> *fields = [NSMutableArray array];
    NSString *needle = [fieldName stringByAppendingString:@":"];
    NSRange searchRange = NSMakeRange(0, packet.length);
    while (searchRange.length > 0) {
        NSRange startRange = [packet rangeOfString:needle options:0 range:searchRange];
        if (startRange.location == NSNotFound) {
            break;
        }
        
        NSUInteger valueStart = NSMaxRange(startRange);
        if (valueStart >= packet.length) {
            break;
        }
        
        NSRange valueSearchRange = NSMakeRange(valueStart, packet.length - valueStart);
        NSRange endRange = [packet rangeOfString:@";" options:0 range:valueSearchRange];
        if (endRange.location == NSNotFound) {
            break;
        }
        
        [fields addObject:[packet substringWithRange:NSMakeRange(valueStart,
                                                                 endRange.location - valueStart)]];
        NSUInteger nextStart = NSMaxRange(endRange);
        if (nextStart >= packet.length) {
            break;
        }
        searchRange = NSMakeRange(nextStart, packet.length - nextStart);
    }
    
    return fields;
}

static NSString *formatHexBytes(NSData *data) {
    if (data.length == 0) {
        return @"";
    }
    
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSMutableString *result = [NSMutableString stringWithCapacity:data.length * 2];
    for (NSUInteger index = 0; index < data.length; index++) {
        [result appendFormat:@"%02x", bytes[index]];
    }
    return result;
}

static NSString *packetField(NSString *packet, NSString *fieldName) {
    NSString *needle = [fieldName stringByAppendingString:@":"];
    NSRange startRange = [packet rangeOfString:needle];
    if (startRange.location == NSNotFound) {
        return nil;
    }
    
    NSUInteger valueStart = NSMaxRange(startRange);
    NSRange searchRange = NSMakeRange(valueStart, packet.length - valueStart);
    NSRange endRange = [packet rangeOfString:@";" options:0 range:searchRange];
    if (endRange.location == NSNotFound) {
        return nil;
    }
    return [packet substringWithRange:NSMakeRange(valueStart, endRange.location - valueStart)];
}

static NSString *readMemory(DebugProxyHandle *debugProxy,
                            uint64_t address,
                            NSUInteger byteCount,
                            NSError **error) {
    NSString *response = nil;
    NSString *command = [NSString stringWithFormat:@"m%llx,%lx",
                         address,
                         (unsigned long)byteCount];
    if (!sendDebugCommand(debugProxy, command, &response, error)) {
        return nil;
    }
    return response;
}

static void logMemorySample(DebugProxyHandle *debugProxy,
                            uint64_t address,
                            NSUInteger byteCount,
                            NSString *label,
                            DeviceLogHandler logHandler) {
    NSError *error = nil;
    NSString *hex = readMemory(debugProxy, address, byteCount, &error);
    if (!hex) {
        emitLog([NSString stringWithFormat:@"%@ read failed at 0x%llx: %@",
                 label,
                 address,
                 error.localizedDescription ?: @"memory read failed"],
                logHandler);
        return;
    }
    
    NSData *data = dataFromHexString(hex);
    if (!data) {
        emitLog([NSString stringWithFormat:@"%@ raw response at 0x%llx: %@",
                 label,
                 address,
                 hex],
                logHandler);
        return;
    }
    
    emitLog([NSString stringWithFormat:@"%@ at 0x%llx (%lu bytes): %@",
             label,
             address,
             (unsigned long)data.length,
             formatHexBytes(data)],
            logHandler);
}

static NSString *packetThreadID(NSString *packet) {
    NSRange startRange = [packet rangeOfString:@"thread:"];
    if (startRange.location == NSNotFound) {
        return nil;
    }
    NSUInteger valueStart = NSMaxRange(startRange);
    NSRange searchRange = NSMakeRange(valueStart, packet.length - valueStart);
    NSRange endRange = [packet rangeOfString:@";" options:0 range:searchRange];
    if (endRange.location == NSNotFound) {
        return nil;
    }
    return [packet substringWithRange:NSMakeRange(valueStart, endRange.location - valueStart)];
}

static NSString *packetSignal(NSString *packet) {
    if (packet.length < 3 || ![packet hasPrefix:@"T"]) {
        return nil;
    }
    return [packet substringWithRange:NSMakeRange(1, 2)];
}

static NSInteger packetIntegerField(NSString *packet, NSString *fieldName, BOOL *found) {
    NSString *field = packetField(packet, fieldName);
    if (found) {
        *found = field.length > 0;
    }
    return field.length > 0 ? field.integerValue : 0;
}

static BOOL instructionIsBreakpoint(uint32_t instruction) {
    return (instruction & 0xFFE0001Fu) == 0xD4200000u;
}

static BOOL connectionClosedError(NSError *error) {
    NSString *description = error.localizedDescription;
    if (!description) {
        return NO;
    }
    return [description containsString:@"UnexpectedEof"] ||
    [description containsString:@"BrokenPipe"] ||
    [description containsString:@"NotConnected"] ||
    [description containsString:@"channel closed"];
}

static NSString *normalizedSignalForMachException(NSString *signal,
                                                  NSInteger machExceptionType) {
    if (!signal.length) {
        return signal;
    }
    
    // debugserver can surface Mach exceptions as pseudo-signal 0x91.
    // Map them back to process-level POSIX signals so Gecko handlers run.
    if ([signal caseInsensitiveCompare:@"91"] == NSOrderedSame) {
        switch (machExceptionType) {
            case 1:  // EXC_BAD_ACCESS
                return @"0b";  // SIGSEGV
            case 2:  // EXC_BAD_INSTRUCTION
                return @"04";  // SIGILL
            case 3:  // EXC_ARITHMETIC
                return @"08";  // SIGFPE
            case 4:  // EXC_EMULATION
                return @"07";  // SIGEMT
            case 5:  // EXC_SOFTWARE
            case 6:  // EXC_BREAKPOINT
                return @"05";  // SIGTRAP
            default:
                return signal;
        }
    }
    
    return signal;
}

static BOOL forwardSignalStop(DebugProxyHandle *debugProxy,
                              NSString *signal,
                              NSString *threadID,
                              int32_t pid,
                              BOOL singleStep,
                              DeviceLogHandler logHandler,
                              NSString **stopResponseOut,
                              NSError **error) {
    NSString *action = singleStep ? @"S" : @"C";
    NSString *continueCommand = [NSString stringWithFormat:@"vCont;%@%@:%@",
                                 action,
                                 signal,
                                 threadID];
    NSString *stopResponse = nil;
    if (!sendDebugCommand(debugProxy, continueCommand, &stopResponse, error)) {
        NSString *errorDescription = (error && *error) ? (*error).localizedDescription : @"signal continue failed";
        emitLog([NSString stringWithFormat:@"Failed to forward signal %@ for pid %d thread %@: %@",
                 signal,
                 pid,
                 threadID,
                 errorDescription],
                logHandler);
        return NO;
    }
    if (stopResponseOut) {
        *stopResponseOut = stopResponse;
    }
    return YES;
}

static BOOL prepareMemoryRegion(DebugProxyHandle *debugProxy,
                                uint64_t startAddress,
                                uint64_t regionSize,
                                uint64_t writableSourceAddress,
                                DeviceLogHandler logHandler,
                                NSError **error) {
    uint64_t size = regionSize == 0 ? 0x4000 : regionSize;
    
    for (uint64_t currentAddress = startAddress;
         currentAddress < startAddress + size;
         currentAddress += 0x4000) {
        uint64_t sourceAddress = currentAddress;
        if (writableSourceAddress != 0) {
            sourceAddress = writableSourceAddress + (currentAddress - startAddress);
        }
        
        NSString *existingByte = readMemory(debugProxy, sourceAddress, 1, error);
        if (!existingByte || existingByte.length < 2) {
            if (error && !*error) {
                *error = createError(-12,
                                     [NSString stringWithFormat:@"Failed to read prepare-region byte at 0x%llx (source 0x%llx)",
                                      currentAddress,
                                      sourceAddress]);
            }
            return NO;
        }
        
        NSString *command = [NSString stringWithFormat:@"M%llx,1:%@",
                             currentAddress,
                             [existingByte substringToIndex:2]];
        NSString *response = nil;
        if (!sendDebugCommand(debugProxy, command, &response, error)) {
            return NO;
        }
        if (response.length > 0 && ![response isEqualToString:@"OK"]) {
            if (error) {
                *error = createError(-7,
                                     [NSString stringWithFormat:@"Unexpected prepare-region response %@",
                                      response]);
            }
            return NO;
        }
    }
    
    return YES;
}

static BOOL allocateRXRegion(DebugProxyHandle *debugProxy,
                             uint64_t regionSize,
                             uint64_t *addressOut,
                             NSError **error) {
    NSString *response = nil;
    NSString *command = [NSString stringWithFormat:@"_M%llx,rx", regionSize];
    if (!sendDebugCommand(debugProxy, command, &response, error)) {
        return NO;
    }
    if (response.length == 0) {
        if (!readDebugResponse(debugProxy, &response, error)) {
            return NO;
        }
    }
    if (response.length == 0) {
        if (error) {
            *error = createError(-10, @"RX allocation returned an empty response.");
        }
        return NO;
    }
    
    uint64_t address = 0;
    NSScanner *scanner = [NSScanner scannerWithString:response];
    if (![scanner scanHexLongLong:&address]) {
        if (error) {
            *error = createError(-11,
                                 [NSString stringWithFormat:@"RX allocation returned invalid address %@",
                                  response]);
        }
        return NO;
    }
    
    if (addressOut) {
        *addressOut = address;
    }
    return YES;
}

static void runIOS17DebugService(int32_t pid,
                                 DebugSession *session,
                                 DeviceLogHandler logHandler) {
    NSError *detachError = nil;
    NSString *detachResponse = nil;
    BOOL targetExited = NO;
    
    NSError *commandError = nil;
    NSString *queuedStopResponse = nil;
    NSString *lastMachFaultThreadID = nil;
    uint64_t lastMachFaultPC = 0;
    NSInteger lastMachFaultType = 0;
    NSUInteger repeatedMachFaultCount = 0;
    // Stay in ack mode. The persistent child-process JIT loop sees heavy trap
    // traffic and has shown better channel stability without switching to
    // QStartNoAckMode.
    
    while (YES) {
        NSString *stopResponse = nil;
        commandError = nil;
        if (queuedStopResponse.length > 0) {
            stopResponse = queuedStopResponse;
            queuedStopResponse = nil;
        } else {
            if (!sendDebugCommand(session->debugProxy, @"c", &stopResponse, &commandError)) {
                NSString *description = commandError.localizedDescription ?: @"continue failed";
                if ([description containsString:@"UnexpectedEof"]) {
                    targetExited = YES;
                    emitLog([NSString stringWithFormat:@"Debug service target exited for pid %d: %@",
                             pid,
                             description],
                            logHandler);
                } else {
                    emitLog([NSString stringWithFormat:@"Debug service ended for pid %d: %@",
                             pid,
                             description],
                            logHandler);
                }
                break;
            }
        }
        
        if (stopResponse.length == 0 || [stopResponse isEqualToString:@"OK"]) {
            do {
                if (!readDebugResponse(session->debugProxy, &stopResponse, &commandError)) {
                    emitLog([NSString stringWithFormat:@"Debug service ended for pid %d while waiting for a stop packet: %@",
                             pid,
                             commandError.localizedDescription ?: @"response read failed"],
                            logHandler);
                    goto detach;
                }
                if (stopResponse.length == 0) {
                    usleep(10000);
                }
            } while (stopResponse.length == 0);
        }
        
        if ([stopResponse hasPrefix:@"W"] || [stopResponse hasPrefix:@"X"]) {
            targetExited = YES;
            emitLog([NSString stringWithFormat:@"Debug service target exited for pid %d with packet %@",
                     pid,
                     stopResponse],
                    logHandler);
            break;
        }
        
        NSString *threadID = packetThreadID(stopResponse);
        NSString *pcField = packetField(stopResponse, @"20");
        NSString *x0Field = packetField(stopResponse, @"00");
        NSString *x1Field = packetField(stopResponse, @"01");
        NSString *x2Field = packetField(stopResponse, @"02");
        NSString *x8Field = packetField(stopResponse, @"08");
        NSString *x9Field = packetField(stopResponse, @"09");
        NSString *x10Field = packetField(stopResponse, @"0a");
        NSString *x16Field = packetField(stopResponse, @"10");
        NSString *x17Field = packetField(stopResponse, @"11");
        NSString *x28Field = packetField(stopResponse, @"1c");
        NSString *x29Field = packetField(stopResponse, @"1d");
        NSString *x30Field = packetField(stopResponse, @"1e");
        NSString *trapField = packetField(stopResponse, @"a2");
        BOOL hasMachExceptionType = NO;
        NSInteger machExceptionType = packetIntegerField(stopResponse, @"metype", &hasMachExceptionType);
        if (!threadID || !pcField) {
            NSString *signal = packetSignal(stopResponse);
            if (threadID && signal) {
                emitLog([NSString stringWithFormat:@"Forwarding partial debug stop for pid %d thread %@ with signal %@: %@",
                         pid,
                         threadID,
                         signal,
                         stopResponse],
                        logHandler);
                if (!forwardSignalStop(session->debugProxy, signal, threadID,
                                       pid, YES, logHandler,
                                       &queuedStopResponse, &commandError)) {
                    break;
                }
                continue;
            }
            
            emitLog([NSString stringWithFormat:@"Unhandled debug stop for pid %d: %@",
                     pid,
                     stopResponse],
                    logHandler);
            break;
        }
        
        NSString *selectGeneralThreadCommand = [NSString stringWithFormat:@"Hg%@", threadID];
        NSString *selectGeneralThreadResponse = nil;
        if (!sendDebugCommand(session->debugProxy,
                              selectGeneralThreadCommand,
                              &selectGeneralThreadResponse,
                              &commandError)) {
            emitLog([NSString stringWithFormat:@"Failed to select general thread %@ for pid %d: %@",
                     threadID,
                     pid,
                     commandError.localizedDescription ?: @"thread select failed"],
                    logHandler);
            break;
        }
        if (selectGeneralThreadResponse.length > 0 && ![selectGeneralThreadResponse isEqualToString:@"OK"]) {
            emitLog([NSString stringWithFormat:@"Unexpected general thread selection response for pid %d thread %@: %@",
                     pid,
                     threadID,
                     selectGeneralThreadResponse],
                    logHandler);
            break;
        }
        
        uint64_t pc = parseLittleEndianHex64(pcField);
        uint64_t x0 = x0Field ? parseLittleEndianHex64(x0Field) : 0;
        uint64_t x1 = x1Field ? parseLittleEndianHex64(x1Field) : 0;
        uint64_t x2 = x2Field ? parseLittleEndianHex64(x2Field) : 0;
        uint64_t x8 = x8Field ? parseLittleEndianHex64(x8Field) : 0;
        uint64_t x9 = x9Field ? parseLittleEndianHex64(x9Field) : 0;
        uint64_t x10 = x10Field ? parseLittleEndianHex64(x10Field) : 0;
        uint64_t x28 = x28Field ? parseLittleEndianHex64(x28Field) : 0;
        uint64_t x29 = x29Field ? parseLittleEndianHex64(x29Field) : 0;
        uint64_t x16 = x16Field ? parseLittleEndianHex64(x16Field) : 0;
        uint64_t x17 = x17Field ? parseLittleEndianHex64(x17Field) : 0;
        uint64_t x30 = x30Field ? parseLittleEndianHex64(x30Field) : 0;
        NSArray<NSString *> *machExceptionData = packetFields(stopResponse, @"medata");
        
        if (hasMachExceptionType && machExceptionType != 6) {
            BOOL sameMachFault = lastMachFaultThreadID &&
            [lastMachFaultThreadID isEqualToString:threadID] &&
            lastMachFaultPC == pc &&
            lastMachFaultType == machExceptionType;
            if (sameMachFault) {
                repeatedMachFaultCount += 1;
            } else {
                lastMachFaultThreadID = [threadID copy];
                lastMachFaultPC = pc;
                lastMachFaultType = machExceptionType;
                repeatedMachFaultCount = 1;
            }
            
            BOOL shouldLogFaultDetails = repeatedMachFaultCount == 1 || (repeatedMachFaultCount % 64 == 0);
            uint64_t pageStart = pc & ~0x3fffull;
            
            // Re-prepare the current executable page when debugserver reports an
            // execute fault at the program counter. This mirrors the regular
            // brk #0x69 page-prepare flow and can recover transient RX state.
            if (machExceptionType == 1 && machExceptionData.count >= 2) {
                uint64_t faultAddress = 0;
                if (parseHexU64(machExceptionData[1], &faultAddress) && faultAddress == pc) {
                    if (repeatedMachFaultCount == 1 || repeatedMachFaultCount == 3 ||
                        (repeatedMachFaultCount % 64 == 0)) {
                        emitLog([NSString stringWithFormat:@"Attempting executable-page recovery for pid %d thread %@ at pc=0x%llx",
                                 pid,
                                 threadID,
                                 pc],
                                logHandler);
                    }
                    
                    NSError *repairError = nil;
                    if (prepareMemoryRegion(session->debugProxy,
                                            pageStart,
                                            0x4000,
                                            0,
                                            logHandler,
                                            &repairError)) {
                        if (repeatedMachFaultCount == 1 || repeatedMachFaultCount == 3 ||
                            (repeatedMachFaultCount % 64 == 0)) {
                            emitLog([NSString stringWithFormat:@"Recovered executable-page state for pid %d thread %@ at page 0x%llx",
                                     pid,
                                     threadID,
                                     pageStart],
                                    logHandler);
                        }
                    } else if (repairError) {
                        if (repeatedMachFaultCount == 1 || repeatedMachFaultCount == 3 ||
                            (repeatedMachFaultCount % 64 == 0)) {
                            emitLog([NSString stringWithFormat:@"Executable-page recovery failed for pid %d thread %@: %@",
                                     pid,
                                     threadID,
                                     repairError.localizedDescription ?: @"unknown error"],
                                    logHandler);
                        }
                    }
                }
            }
            
            if (shouldLogFaultDetails) {
                NSString *machDataSummary = machExceptionData.count > 0 ? [machExceptionData componentsJoinedByString:@","] : @"<none>";
                emitLog([NSString stringWithFormat:@"Non-breakpoint Mach exception details pid=%d thread=%@ signal=%@ metype=%ld medata=%@ x8=0x%llx x9=0x%llx x10=0x%llx x16=0x%llx x17=0x%llx lr=0x%llx trap=%@",
                         pid,
                         threadID,
                         packetSignal(stopResponse) ?: @"<none>",
                         (long)machExceptionType,
                         machDataSummary,
                         x8,
                         x9,
                         x10,
                         x16,
                         x17,
                         x30,
                         trapField ?: @"<none>"],
                        logHandler);
                if (x28 != 0 || x29 != 0) {
                    emitLog([NSString stringWithFormat:@"Faulting frame registers pid=%d thread=%@ fp=0x%llx meta=0x%llx x0=0x%llx x1=0x%llx x8=0x%llx x9=0x%llx",
                             pid,
                             threadID,
                             x29,
                             x28,
                             x0,
                             x1,
                             x8,
                             x9],
                            logHandler);
                }
                logMemorySample(session->debugProxy, pc, 16, @"Faulting PC bytes", logHandler);
                logMemorySample(session->debugProxy, pageStart, 32, @"Faulting page start bytes", logHandler);
                if (x0 != 0) {
                    logMemorySample(session->debugProxy, x0, 16, @"Faulting x0 target bytes", logHandler);
                }
                if (x17 != 0) {
                    logMemorySample(session->debugProxy, x17, 64, @"Faulting x17 target bytes", logHandler);
                }
                if (x10 != 0) {
                    logMemorySample(session->debugProxy, x10, 128, @"Faulting x10 target bytes", logHandler);
                }
                if (x30 != 0) {
                    uint64_t lrSample = x30 >= 32 ? x30 - 32 : x30;
                    logMemorySample(session->debugProxy, lrSample, 192, @"Faulting LR context bytes", logHandler);
                    logMemorySample(session->debugProxy, x30 + 0xc0, 256, @"Faulting LR continuation bytes", logHandler);
                    logMemorySample(session->debugProxy, x30 + 0x1ac, 256, @"Faulting LR dispatch bytes", logHandler);
                    logMemorySample(session->debugProxy, x30 + 0x480, 256, @"Faulting LR fallback dispatch bytes", logHandler);
                    logMemorySample(session->debugProxy, x30 + 0x1320, 256, @"Faulting LR guard failure bytes", logHandler);
                    logMemorySample(session->debugProxy, x30 + 0x1a28, 256, @"Faulting LR terminal dispatch bytes", logHandler);
                }
                if (x29 != 0) {
                    uint64_t frameSample = x29 >= 32 ? x29 - 32 : x29;
                    logMemorySample(session->debugProxy, frameSample, 128, @"Faulting frame bytes", logHandler);
                }
                if (x28 != 0) {
                    logMemorySample(session->debugProxy, x28, 64, @"Faulting metadata bytes", logHandler);
                }
            } else if (repeatedMachFaultCount == 2) {
                emitLog([NSString stringWithFormat:@"Repeated non-breakpoint Mach exception detected for pid %d thread %@ at pc=0x%llx (metype=%ld)",
                         pid,
                         threadID,
                         pc,
                         (long)machExceptionType],
                        logHandler);
            }
            
            if (repeatedMachFaultCount == 1 || repeatedMachFaultCount == 3 ||
                (repeatedMachFaultCount % 64 == 0)) {
                emitLog([NSString stringWithFormat:@"Forwarding non-breakpoint Mach exception as signal to pid=%d thread=%@ count=%lu",
                         pid,
                         threadID,
                         (unsigned long)repeatedMachFaultCount],
                        logHandler);
            }
            
            NSString *signal = packetSignal(stopResponse);
            if (!signal) {
                emitLog([NSString stringWithFormat:@"Stopping debug service for pid %d after Mach exception without signal: %@",
                         pid,
                         stopResponse],
                        logHandler);
                break;
            }
            
            NSString *forwardSignal = normalizedSignalForMachException(signal,
                                                                       machExceptionType);
            emitLog([NSString stringWithFormat:@"Falling back to signal forwarding for Mach exception pid=%d thread=%@ (metype=%ld, signal=%@ -> %@)",
                     pid,
                     threadID,
                     (long)machExceptionType,
                     signal,
                     forwardSignal],
                    logHandler);
            if (!forwardSignalStop(session->debugProxy, forwardSignal, threadID, pid,
                                   YES, logHandler,
                                   &queuedStopResponse, &commandError)) {
                break;
            }
            continue;
        }
        
        lastMachFaultThreadID = nil;
        lastMachFaultPC = 0;
        lastMachFaultType = 0;
        repeatedMachFaultCount = 0;
        
        NSString *instructionResponse = nil;
        NSString *readInstruction = [NSString stringWithFormat:@"m%llx,4", pc];
        if (!sendDebugCommand(session->debugProxy, readInstruction, &instructionResponse, &commandError)) {
            instructionResponse = nil;
        }
        
        uint32_t instruction = parseLittleEndianHex32(instructionResponse ?: @"");
        if (instructionResponse.length > 0 && !instructionIsBreakpoint(instruction)) {
            NSString *signal = packetSignal(stopResponse);
            if (!signal) {
                emitLog([NSString stringWithFormat:@"Unhandled non-breakpoint stop for pid %d without signal: %@",
                         pid,
                         stopResponse],
                        logHandler);
                break;
            }
            
            if (!forwardSignalStop(session->debugProxy, signal, threadID, pid,
                                   YES, logHandler,
                                   &queuedStopResponse, &commandError)) {
                break;
            }
            
            continue;
        }
        
        uint16_t breakpointImmediate = (instruction >> 5) & 0xffff;
        if (breakpointImmediate == 0 && instructionResponse.length == 0 && trapField.length > 0) {
            uint32_t trapValue = parseLittleEndianHex32(trapField);
            if ([stopResponse hasPrefix:@"T05"]) {
                breakpointImmediate = trapValue & 0xffffu;
            }
        }
        uint64_t executableAddress = x0;
        BOOL resumeHandled = NO;
        if (breakpointImmediate == 0xf00d && x16 == 1) {
            if (!x1Field) {
                emitLog([NSString stringWithFormat:@"Stopping debug service for pid %d on brk #0xf00d without x1 register",
                         pid],
                        logHandler);
                break;
            }
            
            if (executableAddress == 0) {
                if (!allocateRXRegion(session->debugProxy, x1, &executableAddress, &commandError)) {
                    emitLog([NSString stringWithFormat:@"Failed to allocate RX region for pid %d: %@",
                             pid,
                             commandError.localizedDescription ?: @"allocation failed"],
                            logHandler);
                    break;
                }
                emitLog([NSString stringWithFormat:@"Allocated RX region for pid %d at 0x%llx size=0x%llx",
                         pid,
                         executableAddress,
                         x1],
                        logHandler);
            }
            
            if (!prepareMemoryRegion(session->debugProxy, executableAddress, x1, 0,
                                     logHandler, &commandError)) {
                if (connectionClosedError(commandError)) {
                    targetExited = YES;
                    emitLog([NSString stringWithFormat:@"Debug service target exited for pid %d during prepare",
                             pid],
                            logHandler);
                    break;
                }
                emitLog([NSString stringWithFormat:@"Failed to prepare executable region for pid %d: %@",
                         pid,
                         commandError.localizedDescription ?: @"prepare region failed"],
                        logHandler);
                break;
            }
            
            NSString *resumeCommand = registerWriteCommand(@"20",
                                                           pc + 4,
                                                           threadID);
            NSString *resumeResponse = nil;
            if (!sendDebugCommand(session->debugProxy, resumeCommand, &resumeResponse, &commandError)) {
                if (connectionClosedError(commandError)) {
                    targetExited = YES;
                    emitLog([NSString stringWithFormat:@"Debug service target exited for pid %d during resume after breakpoint 0x%04x",
                             pid,
                             breakpointImmediate],
                            logHandler);
                    break;
                }
                emitLog([NSString stringWithFormat:@"Failed to resume pid %d after breakpoint 0x%04x: %@",
                         pid,
                         breakpointImmediate,
                         commandError.localizedDescription ?: @"resume failed"],
                        logHandler);
                break;
            }
            if (resumeResponse.length > 0 && ![resumeResponse isEqualToString:@"OK"]) {
                emitLog([NSString stringWithFormat:@"Failed to advance PC for pid %d after breakpoint 0x%04x: %@",
                         pid,
                         breakpointImmediate,
                         resumeResponse],
                        logHandler);
                break;
            }
            resumeHandled = YES;
            
            NSString *setX0Response = nil;
            NSString *setX0Command = registerWriteCommand(@"0",
                                                          executableAddress,
                                                          threadID);
            if (!sendDebugCommand(session->debugProxy, setX0Command, &setX0Response, &commandError)) {
                if (connectionClosedError(commandError)) {
                    targetExited = YES;
                    emitLog([NSString stringWithFormat:@"Debug service target exited for pid %d while setting x0 after brk #0xf00d",
                             pid],
                            logHandler);
                    break;
                }
                emitLog([NSString stringWithFormat:@"Failed to set x0 for pid %d after brk #0xf00d: %@",
                         pid,
                         commandError.localizedDescription ?: @"set x0 failed"],
                        logHandler);
                break;
            }
            if (setX0Response.length > 0 && ![setX0Response isEqualToString:@"OK"]) {
                emitLog([NSString stringWithFormat:@"Unexpected x0 response for pid %d after brk #0xf00d: %@",
                         pid,
                         setX0Response],
                        logHandler);
                break;
            }
        } else if (breakpointImmediate == 0x69) {
            if (!x0Field || !x1Field) {
                emitLog([NSString stringWithFormat:@"Stopping debug service for pid %d on brk #0x0069 without required registers",
                         pid],
                        logHandler);
                break;
            }
            
            uint64_t regionSize = x2 != 0 ? x2 : x1;
            uint64_t writableSourceAddress = x2 != 0 ? x1 : 0;
            if (!prepareMemoryRegion(session->debugProxy,
                                     x0,
                                     regionSize,
                                     writableSourceAddress,
                                     logHandler,
                                     &commandError)) {
                if (connectionClosedError(commandError)) {
                    targetExited = YES;
                    emitLog([NSString stringWithFormat:@"Debug service target exited for pid %d during prepare",
                             pid],
                            logHandler);
                    break;
                }
                emitLog([NSString stringWithFormat:@"Failed to prepare executable region for pid %d: %@",
                         pid,
                         commandError.localizedDescription ?: @"prepare region failed"],
                        logHandler);
                break;
            }
        } else {
            NSString *signal = packetSignal(stopResponse);
            if (!signal) {
                emitLog([NSString stringWithFormat:@"Stopping debug service for pid %d on unhandled brk #0x%04x without signal", pid, breakpointImmediate],
                        logHandler);
                break;
            }
            
            emitLog([NSString stringWithFormat:@"Forwarding unhandled brk #0x%04x for pid %d thread %@ with signal %@",
                     breakpointImmediate,
                     pid,
                     threadID,
                     signal],
                    logHandler);
            
            if (!forwardSignalStop(session->debugProxy, signal, threadID, pid,
                                   NO, logHandler,
                                   &queuedStopResponse, &commandError)) {
                break;
            }
            continue;
        }
        
        if (!resumeHandled) {
            NSString *resumeCommand = registerWriteCommand(@"20",
                                                           pc + 4,
                                                           threadID);
            NSString *resumeResponse = nil;
            if (!sendDebugCommand(session->debugProxy, resumeCommand, &resumeResponse, &commandError)) {
                if (connectionClosedError(commandError)) {
                    targetExited = YES;
                    emitLog([NSString stringWithFormat:@"Debug service target exited for pid %d during resume after breakpoint 0x%04x",
                             pid,
                             breakpointImmediate],
                            logHandler);
                    break;
                }
                emitLog([NSString stringWithFormat:@"Failed to resume pid %d after breakpoint 0x%04x: %@",
                         pid,
                         breakpointImmediate,
                         commandError.localizedDescription ?: @"resume failed"],
                        logHandler);
                break;
            }
            if (resumeResponse.length > 0 && ![resumeResponse isEqualToString:@"OK"]) {
                emitLog([NSString stringWithFormat:@"Failed to advance PC for pid %d after breakpoint 0x%04x: %@",
                         pid,
                         breakpointImmediate,
                         resumeResponse],
                        logHandler);
                break;
            }
        }
        
    }
    
detach:
    if (!targetExited) {
        if (sendDebugCommand(session->debugProxy, @"D", &detachResponse, &detachError)) {
            emitLog([NSString stringWithFormat:@"Detached debug proxy from pid %d with response %@",
                     pid,
                     detachResponse ?: @"<no response>"],
                    logHandler);
        } else {
            emitLog([NSString stringWithFormat:@"Debug proxy detach for pid %d ended with %@",
                     pid,
                     detachError.localizedDescription ?: @"unknown error"],
                    logHandler);
        }
    }
    
    DebugSessionFree(session);
    free(session);
}

DeviceProvider *deviceProviderCreateVerified(NSString *pairingFilePath,
                                             NSString *targetAddress,
                                             NSError **error) {
    if (![[NSFileManager defaultManager] fileExistsAtPath:pairingFilePath]) {
        if (error) {
            *error = createError(-2, @"Pairing file not found in Documents.");
        }
        return NULL;
    }
    
    IdevicePairingFile *pairingFile = NULL;
    IdeviceFfiError *ffiError = idevice_pairing_file_read(pairingFilePath.fileSystemRepresentation,
                                                          &pairingFile);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to read pairing file."];
            *error = createError(ffiError->code, description);
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
        if (error) {
            *error = createError(-3, @"Invalid target IP address for JIT provider.");
        }
        return NULL;
    }
    
    IdeviceProviderHandle *providerHandle = NULL;
    ffiError = idevice_tcp_provider_new((const struct sockaddr *)&address,
                                        pairingFile,
                                        providerLabel,
                                        &providerHandle);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to create idevice provider."];
            *error = createError(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        return NULL;
    }
    
    HeartbeatClientHandle *heartbeatClient = NULL;
    ffiError = heartbeat_connect(providerHandle, &heartbeatClient);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to connect heartbeat service."];
            *error = createError(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        idevice_provider_free(providerHandle);
        return NULL;
    }
    
    uint64_t nextInterval = 0;
    ffiError = heartbeat_get_marco(heartbeatClient, 15, &nextInterval);
    if (!ffiError) {
        ffiError = heartbeat_send_polo(heartbeatClient);
    }
    
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Heartbeat verification failed."];
            *error = createError(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        heartbeat_client_free(heartbeatClient);
        idevice_provider_free(providerHandle);
        return NULL;
    }
    
    DeviceProvider *provider = malloc(sizeof(*provider));
    if (!provider) {
        idevice_provider_free(providerHandle);
        if (error) {
            *error = createError(-5, @"Failed to allocate JIT device provider.");
        }
        return NULL;
    }
    
    provider->handle = providerHandle;
    provider->heartbeatClient = heartbeatClient;
    provider->heartbeatRunning = NO;
    
    startProviderHeartbeat(provider);
    
    return provider;
}

void deviceProviderFree(DeviceProvider *provider) {
    if (!provider) {
        return;
    }
    provider->heartbeatRunning = NO;
    if (provider->heartbeatClient) {
        heartbeat_client_free(provider->heartbeatClient);
        provider->heartbeatClient = NULL;
    }
    if (provider->handle) {
        idevice_provider_free(provider->handle);
        provider->handle = NULL;
    }
    free(provider);
}

BOOL deviceEnableIOS17(int32_t pid,
                       DeviceProvider *provider,
                       DeviceLogHandler logHandler,
                       NSError **error) {
    DebugSession session = {0};
    IdeviceFfiError *ffiError = NULL;
    
    emitLog([NSString stringWithFormat:@"Connecting CoreDeviceProxy for pid %d", pid],
            logHandler);
    
    CoreDeviceProxyHandle *coreDevice = NULL;
    ffiError = core_device_proxy_connect(provider->handle, &coreDevice);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to connect CoreDeviceProxy."];
            *error = createError(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        return NO;
    }
    
    uint16_t rsdPort = 0;
    ffiError = core_device_proxy_get_server_rsd_port(coreDevice, &rsdPort);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to resolve RSD port."];
            *error = createError(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        core_device_proxy_free(coreDevice);
        return NO;
    }
    
    emitLog([NSString stringWithFormat:@"Resolved RSD port %u for pid %d", rsdPort, pid],
            logHandler);
    
    ffiError = core_device_proxy_create_tcp_adapter(coreDevice, &session.adapter);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to create CoreDevice adapter."];
            *error = createError(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        core_device_proxy_free(coreDevice);
        return NO;
    }
    coreDevice = NULL;
    
    ReadWriteOpaque *stream = NULL;
    ffiError = adapter_connect(session.adapter, rsdPort, &stream);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to connect adapter stream."];
            *error = createError(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        DebugSessionFree(&session);
        return NO;
    }
    
    ffiError = rsd_handshake_new(stream, &session.handshake);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to complete RSD handshake."];
            *error = createError(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        DebugSessionFree(&session);
        return NO;
    }
    
    ffiError = remote_server_connect_rsd(session.adapter, session.handshake, &session.remoteServer);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to connect remote server."];
            *error = createError(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        DebugSessionFree(&session);
        return NO;
    }
    
    ffiError = debug_proxy_connect_rsd(session.adapter, session.handshake, &session.debugProxy);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to connect debug proxy."];
            *error = createError(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        DebugSessionFree(&session);
        return NO;
    }
    
    emitLog([NSString stringWithFormat:@"Connected debug services for pid %d", pid],
            logHandler);
    
    ProcessControlHandle *processControl = NULL;
    ffiError = process_control_new(session.remoteServer, &processControl);
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to create process control client."];
            *error = createError(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        DebugSessionFree(&session);
        return NO;
    }
    
    ffiError = process_control_disable_memory_limit(processControl, (uint64_t)pid);
    process_control_free(processControl);
    if (ffiError) {
        NSString *description = [NSString stringWithUTF8String:ffiError->message ?: "Failed to disable child process memory limit."];
        emitLog([NSString stringWithFormat:@"Continuing without disable_memory_limit for pid %d: %@", pid, description],
                logHandler);
        idevice_error_free(ffiError);
    } else {
        emitLog([NSString stringWithFormat:@"Disabled child memory limit for pid %d", pid],
                logHandler);
    }
    
    char *response = NULL;
    char attachCommand[64];
    snprintf(attachCommand, sizeof(attachCommand), "vAttach;%X", pid);
    DebugserverCommandHandle *command = debugserver_command_new(attachCommand, NULL, 0);
    ffiError = debug_proxy_send_command(session.debugProxy, command, &response);
    debugserver_command_free(command);
    NSString *attachResponse = response ? [NSString stringWithUTF8String:response] : @"<no response>";
    if (response) {
        idevice_string_free(response);
        response = NULL;
    }
    if (ffiError) {
        if (error) {
            NSString *description = [NSString stringWithFormat:@"Failed to attach debug proxy: %@", [NSString stringWithUTF8String:ffiError->message ?: "unknown error"]];
            *error = createError(ffiError->code, description);
        }
        idevice_error_free(ffiError);
        DebugSessionFree(&session);
        return NO;
    }
    emitLog([NSString stringWithFormat:@"Attached debug proxy to pid %d with response %@", pid, attachResponse],
            logHandler);
    
    DebugSession *persistentSession = malloc(sizeof(*persistentSession));
    if (!persistentSession) {
        DebugSessionFree(&session);
        if (error) {
            *error = createError(-8, @"Failed to allocate persistent debug session.");
        }
        return NO;
    }
    *persistentSession = session;
    session.adapter = NULL;
    session.handshake = NULL;
    session.remoteServer = NULL;
    session.debugProxy = NULL;
    
    DeviceLogHandler copiedHandler = [logHandler copy];
    dispatch_async(debugServiceQueue(), ^{
        runIOS17DebugService(pid, persistentSession, copiedHandler);
    });
    
    emitLog([NSString stringWithFormat:@"JIT enablement verified, pid=%d", pid],
            logHandler);
    
    return YES;
}

BOOL deviceEnableLegacy(int32_t pid,
                        DeviceProvider *provider,
                        DeviceLogHandler logHandler,
                        NSError **error) {
    (void)pid;
    (void)provider;
    if (error) {
        *error = createError(-4,
                             @"Legacy pre-iOS 17 JIT enablement is not available.");
    }
    return NO;
}
