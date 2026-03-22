//
//  JITEnabler.m
//  Reynard
//
//  Created by Minh Ton on 11/3/26.
//

#import "JITEnabler.h"
#import "JITSupport.h"
#import "JITUtils.h"

@interface JITEnabler ()

@property(nonatomic, assign) DeviceProvider *sharedProvider;
@property(nonatomic, strong) dispatch_queue_t providerQueue;

- (DeviceProvider *)getProvider:(NSError **)error;

@end

@implementation JITEnabler

+ (JITEnabler *)shared {
    static JITEnabler *sharedEnabler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedEnabler = [[self alloc] init];
    });
    return sharedEnabler;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sharedProvider = NULL;
        _providerQueue = dispatch_queue_create("me.minh-ton.jit.enabler.provider", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)enableJITForPID:(int32_t)pid logHandler:(LogHandler)logHandler error:(NSError **)error {
    if (@available(iOS 17.4, *)) {
        // For iOS 17.4 and later
        // Thanks StikDebug!
        // https://github.com/StephenDev0/StikDebug
        
        DeviceProvider *provider = [self getProvider:error];
        if (!provider) return NO;
        
        DebugSession session = {0};
        IdeviceFfiError *ffiError = NULL;
        
        if (!connectDebugSession(provider, &session, error)) return NO;
        
        ProcessControlHandle *processControl = NULL;
        ffiError = process_control_new(session.remoteServer, &processControl);
        if (ffiError) {
            if (error) *error = MakeError(ProcessControlCreateFailed);
            idevice_error_free(ffiError);
            freeDebugSession(&session);
            return NO;
        }
        
        ffiError = process_control_disable_memory_limit(processControl, (uint64_t)pid);
        process_control_free(processControl);
        if (ffiError) {
            logger([NSString stringWithFormat:@"disable_memory_limit failed for pid %d: %s", pid, ffiError->message ?: "unknown error"], logHandler);
            idevice_error_free(ffiError);
        }
        
        NSError *commandError = nil;
        NSString *noAckResponse = nil;
        if (!configureNoAckMode(session.debugProxy, &noAckResponse, &commandError)) {
            if (error) *error = commandError ?: MakeError(NoAckConfigureFailed);
            freeDebugSession(&session);
            return NO;
        }
        
        logger([NSString stringWithFormat:@"QStartNoAckMode result for pid %d: %@", pid, noAckResponse ?: @"<no response>"], logHandler);
        
        NSString *attachCommand = [NSString stringWithFormat:@"vAttach;%X", pid];
        NSString *attachResponse = nil;
        if (!sendDebugCommand(session.debugProxy, attachCommand, &attachResponse, &commandError)) {
            if (error) *error = commandError ?: MakeError(AttachDebugProxyFailed);
            freeDebugSession(&session);
            return NO;
        }
        
        logger([NSString stringWithFormat:@"Attach response for pid %d: %@", pid, attachResponse.length > 0 ? @"<stop packet>" : @"<no response>"], logHandler);
        
        DebugSession *persistentSession = malloc(sizeof(*persistentSession));
        if (!persistentSession) {
            freeDebugSession(&session);
            if (error) *error = MakeError(SessionAllocationFailed);
            return NO;
        }
        
        *persistentSession = session;
        session.adapter = NULL;
        session.handshake = NULL;
        session.remoteServer = NULL;
        session.debugProxy = NULL;
        
        DeviceLogHandler copiedHandler = [logHandler copy];
        dispatch_async(debugServiceQueue(), ^{
            runDebugService(pid, persistentSession, copiedHandler);
        });
        
        logger([NSString stringWithFormat:@"Debug session started for pid %d", pid], logHandler);
        
        return YES;
    } else {
        DeviceProvider *provider = [self getProvider:error];
        if (!provider) return NO;
        
        uint16_t debugPort = 0;
        if (!startLegacyDebugService(provider, &debugPort, error)) return NO;
        
        LegacyDebugSession *legacySession = calloc(1, sizeof(*legacySession));
        if (!legacySession) {
            if (error) *error = MakeError(SessionAllocationFailed);
            return NO;
        }
        
        legacySession->connection.socketFD = -1;
        legacySession->connection.sslContext = NULL;
        
        if (!connectLegacyDebugSocket(@"10.7.0.1", debugPort, &legacySession->connection, error)) {
            free(legacySession);
            return NO;
        }
        
        NSString *attachResponse = nil;
        NSString *attachCommand = [NSString stringWithFormat:@"vAttach;%08X", (uint32_t)pid];
        if (!sendLegacyDebugCommand(&legacySession->connection, attachCommand, &attachResponse, error)) {
            closeLegacyDebugConnection(&legacySession->connection);
            free(legacySession);
            return NO;
        }
        
        logger([NSString stringWithFormat:@"Legacy attach response for pid %d: %@", pid, attachResponse.length > 0 ? attachResponse : @"<no response>"], logHandler);
        
        DeviceLogHandler copiedHandler = [logHandler copy];
        dispatch_async(debugServiceQueue(), ^{
            runLegacyDebugService(pid, legacySession, copiedHandler);
        });
        
        logger([NSString stringWithFormat:@"Legacy debug session started for pid %d", pid], logHandler);
        
        return YES;
    }
    
    return NO;
}

- (DeviceProvider *)getProvider:(NSError **)error {
    __block DeviceProvider *provider = NULL;
    __block NSError *providerError = nil;
    dispatch_sync(self.providerQueue, ^{
        if (!self.sharedProvider) self.sharedProvider = createDeviceProvider([self pairingFilePath], @"10.7.0.1", &providerError);
        provider = self.sharedProvider;
    });
    
    if (!provider && error) *error = providerError;
    return provider;
}

- (void)dealloc {
    if (_sharedProvider) {
        freeDeviceProvider(_sharedProvider);
        _sharedProvider = NULL;
    }
}

- (NSString *)pairingFilePath {
    NSURL *documentsDirectory = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    return [[documentsDirectory URLByAppendingPathComponent:@"pairingFile.plist"] path];
}

@end
