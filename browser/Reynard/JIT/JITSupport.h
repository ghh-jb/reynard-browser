//
//  JITSupport.h
//  Reynard
//
//  Created by Minh Ton on 11/3/2026.
//

@import Foundation;

#import "IdeviceFFI.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct DeviceProvider DeviceProvider;
typedef void (^DeviceLogHandler)(NSString *message);

typedef struct {
    AdapterHandle *adapter;
    RsdHandshakeHandle *handshake;
    RemoteServerHandle *remoteServer;
    DebugProxyHandle *debugProxy;
} DebugSession;

dispatch_queue_t debugServiceQueue(void);

DeviceProvider * _Nullable createDeviceProvider(NSString *pairingFilePath,
                                                NSString *targetAddress,
                                                NSError * _Nullable * _Nullable error);

BOOL sendDebugCommand(DebugProxyHandle *debugProxy, NSString *commandString, NSString * _Nullable * _Nullable responseOut, NSError * _Nullable * _Nullable error);
BOOL configureNoAckMode(DebugProxyHandle *debugProxy, NSString * _Nullable * _Nullable responseOut, NSError * _Nullable * _Nullable error);
BOOL connectDebugSession(DeviceProvider *provider, DebugSession *session, NSError * _Nullable * _Nullable error);
void runDebugService(int32_t pid, DebugSession *session, DeviceLogHandler _Nullable logHandler);

void freeDebugSession(DebugSession *session);
void freeDeviceProvider(DeviceProvider * _Nullable provider);

NS_ASSUME_NONNULL_END
