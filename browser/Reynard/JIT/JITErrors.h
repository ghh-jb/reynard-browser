//
//  JITErrors.h
//  Reynard
//
//  Created by Minh Ton on 22/3/26.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const ErrorDomain;

FOUNDATION_EXPORT NSString *const ErrorCategory;

typedef NS_ENUM(NSInteger, ErrorGroup) {
  ErrorGroupUnknown = 0,
  ErrorGroupSharedSetup = 1,
  ErrorGroupModernPath = 2,
  ErrorGroupLegacyPath = 3,
  ErrorGroupPairing = 4,
  ErrorGroupTLS = 5,
  ErrorGroupProtocol = 6,
  ErrorGroupTrollStore = 7,
};

typedef NS_ERROR_ENUM(ErrorDomain, ErrorCode){
    // Pairing and bootstrap setup
    PairingFileMissing = -1,
    PairingFilePathUnavailable = -2,
    PairingFileLoadFailed = -3,
    PairingFileMissingCredentials = -4,
    HostCertificateParseFailed = -5,
    HostPrivateKeyParseFailed = -6,
    TLSIdentityCreateFailed = -7,
    InvalidTargetAddress = -8,
    DeviceProviderAllocationFailed = -9,
    DeviceProviderCreateFailed = -10,
    PairingFileReadFailed = -11,
    HeartbeatConnectFailed = -12,

    // Legacy service bootstrap
    LockdowndConnectFailed = -13,
    ProviderPairingFileFetchFailed = -14,
    LockdowndSessionStartFailed = -15,
    LockdowndStartServiceFailed = -16,
    LegacyServiceTLSNotEnabled = -17,

    // Modern (iOS 17.4+) attach path
    ProcessControlCreateFailed = -18,
    RemoteServerConnectFailed = -19,
    DebugProxyConnectFailed = -20,
    NoAckConfigureFailed = -21,
    AttachDebugProxyFailed = -22,
    SessionAllocationFailed = -23,

    // Protocol handling and command execution
    DebugCommandCreateFailed = -24,
    DebugCommandSendFailed = -25,
    UnexpectedRegisterWriteResponse = -26,
    UnexpectedNoAckResponse = -27,
    MemoryPrepareReadFailed = -28,
    UnexpectedPrepareRegionResponse = -29,

    // Legacy TLS and packet transport
    LegacyTLSConfigurationFailed = -30,
    LegacyTLSConnectionMissing = -31,
    LegacyTLSConnectionClosed = -32,
    LegacyTLSReadFailed = -33,
    LegacyProtocolNackReceived = -34,
    LegacyProtocolPayloadTimeout = -35,
    LegacyProtocolChecksumTimeout = -36,
    LegacyProtocolChecksumMismatch = -37,
    LegacyCommandEncodingFailed = -38,
    LegacyOutputConnectionMissing = -39,
    LegacySocketCreateFailed = -40,
    LegacySocketInvalidAddress = -41,
    LegacySocketConnectFailed = -42,

    // Wrapper-level legacy operation failures
    LegacySocketTLSSetupFailed = -43,
    LegacyDebugCommandPacketFailed = -44,
    LegacyDebugCommandResponseFailed = -45,

    // Developer Disk Image mounting
    DDIMountPathResolveFailed = -46,
    DDIFileReadFailed = -47,
    ImageMounterConnectFailed = -48,
    DDIDeviceVersionReadFailed = -49,
    DDIDeviceVersionInvalid = -50,
    DDIMountStateQueryFailed = -51,
    LegacyDDIMountFailed = -52,
    UniqueChipIDReadFailed = -53,
    UniqueChipIDInvalid = -54,
    ModernDDIMountFailed = -55,

    // Runtime connectivity monitoring
    EndpointConnectivityLost = -56,

    // RPPairing tunnel
    TunnelCreateFailed = -57,

    // TrollStore ptrace attach path
    TSPtraceHelperMissing = -58,
    TSPtraceHelperAttachFailed = -59,
    TSPtraceHelperTerminated = -60,
};

NSString *ErrorDescription(ErrorCode code);
ErrorGroup ErrorGroupForCode(ErrorCode code);
NSError *MakeError(ErrorCode code);

NS_ASSUME_NONNULL_END
