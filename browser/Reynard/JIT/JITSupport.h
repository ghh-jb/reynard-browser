//
//  JITSupport.h
//  Reynard
//
//  Created by Minh Ton on 11/03/2026.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

typedef struct DeviceProvider DeviceProvider;
typedef void (^DeviceLogHandler)(NSString *message);

DeviceProvider * _Nullable deviceProviderCreateVerified(
                                                        NSString *pairingFilePath,
                                                        NSString *targetAddress,
                                                        NSError * _Nullable * _Nullable error);
void deviceProviderFree(DeviceProvider * _Nullable provider);

BOOL deviceEnableIOS17(int32_t pid,
                       DeviceProvider *provider,
                       DeviceLogHandler _Nullable logHandler,
                       NSError * _Nullable * _Nullable error);
BOOL deviceEnableLegacy(int32_t pid,
                        DeviceProvider *provider,
                        DeviceLogHandler _Nullable logHandler,
                        NSError * _Nullable * _Nullable error);

NS_ASSUME_NONNULL_END
