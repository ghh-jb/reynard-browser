//
//  JITEnabler.m
//  Reynard
//
//  Created by Minh Ton on 11/3/26.
//

#import "JITEnabler.h"

#import "JITSupport.h"

static NSString *const enablerErrorDomain = @"JITEnabler";

@interface JITEnabler ()

@property (nonatomic, assign) DeviceProvider *sharedProvider;
@property (nonatomic, strong) dispatch_queue_t providerQueue;

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description;
- (void)emitLog:(NSString *)message handler:(LogHandler)handler;
- (DeviceProvider *)verifiedProvider:(NSError **)error;

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

- (BOOL)enableForProcessIdentifier:(int32_t)pid
                        logHandler:(LogHandler)logHandler
                             error:(NSError **)error {
    if (pid <= 0) {
        if (error) {
            *error = [self errorWithCode:-1 description:@"Invalid child process identifier."];
        }
        return NO;
    }
    
    [self emitLog:[NSString stringWithFormat:@"Preparing idevice provider for pid %d", pid]
          handler:logHandler];
    DeviceProvider *provider = [self verifiedProvider:error];
    if (!provider) {
        return NO;
    }
    
    [self emitLog:[NSString stringWithFormat:@"Verified idevice provider for pid %d", pid]
          handler:logHandler];
    
    BOOL success = NO;
    if (@available(iOS 17, *)) {
        success = deviceEnableIOS17(pid, provider, logHandler, error);
    } else {
        success = deviceEnableLegacy(pid, provider, logHandler, error);
    }
    
    return success;
}

- (DeviceProvider *)verifiedProvider:(NSError **)error {
    __block DeviceProvider *provider = NULL;
    dispatch_sync(self.providerQueue, ^{
        if (!self.sharedProvider) {
            self.sharedProvider = deviceProviderCreateVerified([self pairingFilePath],
                                                               self.targetAddress,
                                                               error);
        }
        provider = self.sharedProvider;
    });
    return provider;
}

- (void)dealloc {
    if (_sharedProvider) {
        deviceProviderFree(_sharedProvider);
        _sharedProvider = NULL;
    }
}

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description {
    return [NSError errorWithDomain:enablerErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

- (void)emitLog:(NSString *)message handler:(LogHandler)handler {
    if (handler) {
        handler(message);
    }
}

- (NSString *)targetAddress {
    return @"10.7.0.1";
}

- (NSString *)pairingFilePath {
    NSURL *documentsDirectory = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                       inDomains:NSUserDomainMask].firstObject;
    return [[documentsDirectory URLByAppendingPathComponent:@"pairingFile.plist"] path];
}

@end
