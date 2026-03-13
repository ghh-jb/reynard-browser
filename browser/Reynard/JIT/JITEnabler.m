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

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description;
- (void)emitLog:(NSString *)message handler:(LogHandler)handler;

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
    DeviceProvider *provider = deviceProviderCreateVerified([self pairingFilePath],
                                                            self.targetAddress,
                                                            error);
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
    
    deviceProviderFree(provider);
    return success;
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
