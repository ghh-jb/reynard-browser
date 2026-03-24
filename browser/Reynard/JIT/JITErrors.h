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
    HeartbeatExchangeFailed = -13,

    // Legacy service bootstrap
    LockdowndConnectFailed = -14,
    ProviderPairingFileFetchFailed = -15,
    LockdowndSessionStartFailed = -16,
    LockdowndStartServiceFailed = -17,
    LegacyServiceTLSNotEnabled = -18,

    // Modern (iOS 17.4+) attach path
    ProcessControlCreateFailed = -19,
    CoreDeviceConnectFailed = -20,
    CoreDeviceRSDPortResolveFailed = -21,
    CoreDeviceAdapterCreateFailed = -22,
    AdapterStreamConnectFailed = -23,
    RSDHandshakeCreateFailed = -24,
    RemoteServerConnectFailed = -25,
    DebugProxyConnectFailed = -26,
    NoAckConfigureFailed = -27,
    AttachDebugProxyFailed = -28,
    SessionAllocationFailed = -29,

    // Protocol handling and command execution
    DebugCommandCreateFailed = -30,
    DebugCommandSendFailed = -31,
    UnexpectedRegisterWriteResponse = -32,
    UnexpectedNoAckResponse = -33,
    MemoryPrepareReadFailed = -34,
    UnexpectedPrepareRegionResponse = -35,
    RXAllocationEmptyResponse = -36,
    RXAllocationInvalidAddress = -37,

    // Legacy TLS and packet transport
    LegacyTLSConfigurationFailed = -38,
    LegacyTLSConnectionMissing = -39,
    LegacyTLSConnectionClosed = -40,
    LegacyTLSReadFailed = -41,
    LegacyProtocolNackReceived = -42,
    LegacyProtocolPayloadTimeout = -43,
    LegacyProtocolChecksumTimeout = -44,
    LegacyProtocolChecksumMismatch = -45,
    LegacyCommandEncodingFailed = -46,
    LegacyOutputConnectionMissing = -47,
    LegacySocketCreateFailed = -48,
    LegacySocketInvalidAddress = -49,
    LegacySocketConnectFailed = -50,

    // Wrapper-level legacy operation failures
    LegacySocketTLSSetupFailed = -51,
    LegacyDebugCommandPacketFailed = -52,
    LegacyDebugCommandResponseFailed = -53,
    LegacyContinuePacketFailed = -54,
    LegacyContinueResponseFailed = -55,

    // Developer Disk Image mounting
    DDIMountPathResolveFailed = -56,
    DDIFileReadFailed = -57,
    ImageMounterConnectFailed = -58,
    DDIDeviceVersionReadFailed = -59,
    DDIDeviceVersionInvalid = -60,
    DDIMountStateQueryFailed = -61,
    LegacyDDIMountFailed = -62,
    UniqueChipIDReadFailed = -63,
    UniqueChipIDInvalid = -64,
    ModernDDIMountFailed = -65,

    // Runtime connectivity monitoring
    EndpointConnectivityLost = -66,
};

NSString *ErrorDescription(ErrorCode code);
ErrorGroup ErrorGroupForCode(ErrorCode code);
NSError *MakeError(ErrorCode code);

NS_ASSUME_NONNULL_END
