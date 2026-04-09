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
@property(nonatomic, assign) BOOL didEnsureDDIMounted;
@property(nonatomic, strong) dispatch_source_t ddiMountedMonitor;

- (DeviceProvider *)getProvider:(NSError **)error;
- (void)startDDIMonitor;
- (void)stopDDIMonitor;

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
        _didEnsureDDIMounted = NO;
        _ddiMountedMonitor = nil;
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
        
        if (!connectDebugSession(provider, &session, @"10.7.0.1", error)) return NO;
        
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
        
        registerJITEndpointForPID(pid, @"10.7.0.1", 49152, -1);
        
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
        
        registerJITEndpointForPID(pid, @"10.7.0.1", debugPort, legacySession->connection.socketFD);
        
        DeviceLogHandler copiedHandler = [logHandler copy];
        dispatch_async(debugServiceQueue(), ^{
            runLegacyDebugService(pid, legacySession, copiedHandler);
        });
        
        logger([NSString stringWithFormat:@"Legacy debug session started for pid %d", pid], logHandler);
        
        return YES;
    }
    
    return NO;
}

- (void)detachAllJITSessions {
    resetJITEndpointMonitor();
    dispatch_sync(debugSessionStateQueue(), ^{
        NSMutableSet<NSNumber *> *active = activeDebugSessionPIDs();
        NSMutableSet<NSNumber *> *detachRequested = detachRequestedDebugSessionPIDs();
        [detachRequested unionSet:active];
    });
}

- (DeviceProvider *)getProvider:(NSError **)error {
    __block DeviceProvider *provider = NULL;
    __block NSError *providerError = nil;
    
    dispatch_sync(self.providerQueue, ^{
        if (!self.sharedProvider) {
            self.sharedProvider = createDeviceProvider(pairingFilePath(), @"10.7.0.1", &providerError);
            self.didEnsureDDIMounted = NO;
        }
        
        if (self.sharedProvider && !self.didEnsureDDIMounted) {
            if (!ensureDDIMounted(self.sharedProvider, &providerError)) {
                provider = NULL;
                return;
            }
            self.didEnsureDDIMounted = YES;
            
            // Not sure why but it's quite unreliable. So commented.
            // But still it's very unlikely that the DDI is unmounted I guess?
            // [self startDDIMonitor];
        }
        
        provider = self.sharedProvider;
    });
    
    if (!provider && error) *error = providerError;
    return provider;
}

- (void)startDDIMonitor {
    if (self.ddiMountedMonitor) return;
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.providerQueue);
    if (!timer) return;
    
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), NSEC_PER_SEC, 0);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (!strongSelf.sharedProvider || !strongSelf.didEnsureDDIMounted) return;
        
        size_t mountedDeviceCount = getMountedDeviceCount(strongSelf.sharedProvider);
        if (mountedDeviceCount > 0) return;
        
        [strongSelf stopDDIMonitor];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"me-minh-ton.jit.ddimonitor" object:nil userInfo:nil];
        });
    });
    
    self.ddiMountedMonitor = timer;
    dispatch_resume(timer);
}

- (void)stopDDIMonitor {
    if (!self.ddiMountedMonitor) return;
    dispatch_source_cancel(self.ddiMountedMonitor);
    self.ddiMountedMonitor = nil;
}

- (void)dealloc {
    resetJITEndpointMonitor();
    // [self stopDDIMonitor];
    if (_sharedProvider) {
        freeDeviceProvider(_sharedProvider);
        _sharedProvider = NULL;
    }
}

@end
