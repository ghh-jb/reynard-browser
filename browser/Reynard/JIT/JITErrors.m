//
//  JITErrors.m
//  Reynard
//
//  Created by Minh Ton on 22/3/26.
//

#import "JITErrors.h"

NSErrorDomain const ErrorDomain = @"Reynard.JIT";
NSString *const ErrorCategory = @"ErrorCategory";

NSString *ErrorDescription(ErrorCode code) {
    switch (code) {
        case PairingFileMissing:
            return @"Pairing file was not found.";
        case PairingFilePathUnavailable:
            return @"Unable to resolve pairing file path.";
        case PairingFileLoadFailed:
            return @"Failed to load pairing file.";
        case PairingFileMissingCredentials:
            return @"Pairing file is missing certificate or private key data.";
        case HostCertificateParseFailed:
            return @"Failed to parse host certificate from pairing file.";
        case HostPrivateKeyParseFailed:
            return @"Failed to parse host private key from pairing file.";
        case TLSIdentityCreateFailed:
            return @"Failed to create TLS identity from pairing data.";
        case InvalidTargetAddress:
            return @"Target address is invalid.";
        case DeviceProviderAllocationFailed:
            return @"Failed to allocate device provider.";
        case DeviceProviderCreateFailed:
            return @"Failed to create device provider.";
        case PairingFileReadFailed:
            return @"Failed to read pairing file for provider.";
        case HeartbeatConnectFailed:
            return @"Failed to connect heartbeat service.";
        case HeartbeatExchangeFailed:
            return @"Heartbeat exchange failed.";
        case LockdowndConnectFailed:
            return @"Failed to connect lockdownd service.";
        case ProviderPairingFileFetchFailed:
            return @"Failed to fetch pairing file from provider.";
        case LockdowndSessionStartFailed:
            return @"Failed to start lockdownd session.";
        case LockdowndStartServiceFailed:
            return @"Failed to start legacy debug service.";
        case LegacyServiceTLSNotEnabled:
            return @"Legacy debug service did not enable TLS.";
        case ProcessControlCreateFailed:
            return @"Failed to create process control client.";
        case CoreDeviceConnectFailed:
            return @"Failed to connect CoreDevice proxy.";
        case CoreDeviceRSDPortResolveFailed:
            return @"Failed to resolve RSD port.";
        case CoreDeviceAdapterCreateFailed:
            return @"Failed to create CoreDevice TCP adapter.";
        case AdapterStreamConnectFailed:
            return @"Failed to connect adapter stream.";
        case RSDHandshakeCreateFailed:
            return @"Failed to create RSD handshake.";
        case RemoteServerConnectFailed:
            return @"Failed to connect remote server.";
        case DebugProxyConnectFailed:
            return @"Failed to connect debug proxy.";
        case NoAckConfigureFailed:
            return @"Failed to configure no-ack mode.";
        case AttachDebugProxyFailed:
            return @"Failed to attach debug proxy.";
        case SessionAllocationFailed:
            return @"Failed to allocate debug session.";
        case DebugCommandCreateFailed:
            return @"Failed to create debug command.";
        case DebugCommandSendFailed:
            return @"Failed to send debug command.";
        case UnexpectedRegisterWriteResponse:
            return @"Unexpected register write response.";
        case UnexpectedNoAckResponse:
            return @"Unexpected no-ack response.";
        case MemoryPrepareReadFailed:
            return @"Failed to read source memory for prepare-region.";
        case UnexpectedPrepareRegionResponse:
            return @"Unexpected prepare-region response.";
        case RXAllocationEmptyResponse:
            return @"RX allocation returned empty response.";
        case RXAllocationInvalidAddress:
            return @"RX allocation returned invalid address.";
        case LegacyTLSConfigurationFailed:
            return @"Legacy TLS configuration failed.";
        case LegacyTLSConnectionMissing:
            return @"Legacy TLS connection is missing.";
        case LegacyTLSConnectionClosed:
            return @"Legacy TLS connection was closed by peer.";
        case LegacyTLSReadFailed:
            return @"Failed to read data from legacy TLS connection.";
        case LegacyProtocolNackReceived:
            return @"Legacy protocol NACK received.";
        case LegacyProtocolPayloadTimeout:
            return @"Timed out while reading legacy protocol payload.";
        case LegacyProtocolChecksumTimeout:
            return @"Timed out while reading legacy protocol checksum.";
        case LegacyProtocolChecksumMismatch:
            return @"Legacy protocol checksum mismatch.";
        case LegacyCommandEncodingFailed:
            return @"Failed to encode legacy debug command.";
        case LegacyOutputConnectionMissing:
            return @"Legacy output debug connection is missing.";
        case LegacySocketCreateFailed:
            return @"Failed to create legacy debug socket.";
        case LegacySocketInvalidAddress:
            return @"Invalid legacy debug socket address.";
        case LegacySocketConnectFailed:
            return @"Failed to connect legacy debug socket.";
        case LegacySocketTLSSetupFailed:
            return @"Failed to complete TLS setup for legacy debug socket.";
        case LegacyDebugCommandPacketFailed:
            return @"Failed sending legacy debug command packet.";
        case LegacyDebugCommandResponseFailed:
            return @"Failed reading legacy debug command response.";
        case LegacyContinuePacketFailed:
            return @"Failed sending legacy continue packet.";
        case LegacyContinueResponseFailed:
            return @"Failed reading legacy continue response.";
        case DDIMountPathResolveFailed:
            return @"Unable to resolve the DDI directory path.";
        case DDIFileReadFailed:
            return @"Failed to read required DDI files from disk.";
        case ImageMounterConnectFailed:
            return @"Failed to connect MobileImageMounter service.";
        case DDIDeviceVersionReadFailed:
            return @"Failed to read ProductVersion from lockdownd.";
        case DDIDeviceVersionInvalid:
            return @"Device ProductVersion format is invalid.";
        case DDIMountStateQueryFailed:
            return @"Failed to query current DDI mount state.";
        case LegacyDDIMountFailed:
            return @"Failed to mount legacy DeveloperDiskImage.";
        case UniqueChipIDReadFailed:
            return @"Failed to read UniqueChipID from lockdownd.";
        case UniqueChipIDInvalid:
            return @"UniqueChipID value is invalid.";
        case ModernDDIMountFailed:
            return @"Failed to mount personalized DDI image.";
        case EndpointConnectivityLost:
            return @"Lost TCP connectivity to the JIT debug endpoint.";
    }
    
    return @"Unknown error.";
}

ErrorGroup ErrorGroupForCode(ErrorCode code) {
    switch (code) {
        case PairingFileMissing:
        case PairingFilePathUnavailable:
        case PairingFileLoadFailed:
        case PairingFileMissingCredentials:
        case HostCertificateParseFailed:
        case HostPrivateKeyParseFailed:
        case TLSIdentityCreateFailed:
        case PairingFileReadFailed:
            return ErrorGroupPairing;
        case InvalidTargetAddress:
        case DeviceProviderAllocationFailed:
        case DeviceProviderCreateFailed:
        case HeartbeatConnectFailed:
        case HeartbeatExchangeFailed:
        case DDIMountPathResolveFailed:
        case DDIFileReadFailed:
        case ImageMounterConnectFailed:
        case DDIDeviceVersionReadFailed:
        case DDIDeviceVersionInvalid:
        case EndpointConnectivityLost:
            return ErrorGroupSharedSetup;
        case ProcessControlCreateFailed:
        case CoreDeviceConnectFailed:
        case CoreDeviceRSDPortResolveFailed:
        case CoreDeviceAdapterCreateFailed:
        case AdapterStreamConnectFailed:
        case RSDHandshakeCreateFailed:
        case RemoteServerConnectFailed:
        case DebugProxyConnectFailed:
        case NoAckConfigureFailed:
        case AttachDebugProxyFailed:
        case SessionAllocationFailed:
        case UniqueChipIDReadFailed:
        case UniqueChipIDInvalid:
        case ModernDDIMountFailed:
            return ErrorGroupModernPath;
        case LockdowndConnectFailed:
        case ProviderPairingFileFetchFailed:
        case LockdowndSessionStartFailed:
        case LockdowndStartServiceFailed:
        case LegacyServiceTLSNotEnabled:
        case LegacyOutputConnectionMissing:
        case LegacySocketCreateFailed:
        case LegacySocketInvalidAddress:
        case LegacySocketConnectFailed:
        case LegacySocketTLSSetupFailed:
        case LegacyDDIMountFailed:
            return ErrorGroupLegacyPath;
        case LegacyTLSConfigurationFailed:
        case LegacyTLSConnectionMissing:
        case LegacyTLSConnectionClosed:
        case LegacyTLSReadFailed:
            return ErrorGroupTLS;
        case DebugCommandCreateFailed:
        case DebugCommandSendFailed:
        case UnexpectedRegisterWriteResponse:
        case UnexpectedNoAckResponse:
        case MemoryPrepareReadFailed:
        case UnexpectedPrepareRegionResponse:
        case RXAllocationEmptyResponse:
        case RXAllocationInvalidAddress:
        case LegacyProtocolNackReceived:
        case LegacyProtocolPayloadTimeout:
        case LegacyProtocolChecksumTimeout:
        case LegacyProtocolChecksumMismatch:
        case LegacyCommandEncodingFailed:
        case LegacyDebugCommandPacketFailed:
        case LegacyDebugCommandResponseFailed:
        case LegacyContinuePacketFailed:
        case LegacyContinueResponseFailed:
        case DDIMountStateQueryFailed:
            return ErrorGroupProtocol;
    }
    
    return ErrorGroupUnknown;
}

NSError *MakeError(ErrorCode code) {
    return [NSError errorWithDomain:ErrorDomain
                               code:code
                           userInfo:@{
        NSLocalizedDescriptionKey: ErrorDescription(code),
        ErrorCategory: @(ErrorGroupForCode(code)),
    }];
}
