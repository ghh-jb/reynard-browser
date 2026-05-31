//
//  ContentPermission.swift
//  Reynard
//
//  Created by Minh Ton on 22/2/26.
//

import Foundation

public struct ContentPermission {
    public enum Permission: String {
        case camera = "camera"
        case microphone = "microphone"
        case geolocation = "geolocation"
        case desktopNotification = "desktop-notification"
        case persistentStorage = "persistent-storage"
        case webxr = "xr"
        case autoplay = "autoplay-media"
        case mediaKeySystemAccess = "media-key-system-access"
        case tracking = "trackingprotection"
        case storageAccess = "storage-access"
        case localDeviceAccess = "loopback-network"
        case localNetworkAccess = "local-network"
    }
    
    public enum Value: Int32 {
        case prompt = 3
        case deny = 2
        case allow = 1
        case blockAll = 5
    }
    
    public let uri: String
    public let thirdPartyOrigin: String?
    public let privateMode: Bool
    public let permission: Permission?
    public let value: Value
    public let rawValue: Int32
    public let contextId: String?
    let principal: String
    let rawPermission: String
    
    static func fromDictionary(_ dict: [String: Any?]) -> ContentPermission {
        let rawValue = (dict["value"] as? NSNumber)?.int32Value ?? ContentPermission.Value.prompt.rawValue
        guard let rawPerm = dict["perm"] as? String else {
            return ContentPermission(
                uri: dict["uri"] as? String ?? "",
                thirdPartyOrigin: nil,
                privateMode: dict["privateMode"] as? Bool ?? false,
                permission: nil,
                value: .prompt,
                rawValue: rawValue,
                contextId: dict["contextId"] as? String,
                principal: dict["principal"] as? String ?? "",
                rawPermission: ""
            )
        }
        
        var parsedPermission = Permission(rawValue: rawPerm)
        var parsedThirdPartyOrigin = dict["thirdPartyOrigin"] as? String
        
        if rawPerm.starts(with: "3rdPartyStorage^") {
            parsedThirdPartyOrigin = String(rawPerm.dropFirst(16))
            parsedPermission = .storageAccess
        } else if rawPerm.starts(with: "3rdPartyFrameStorage^") {
            parsedThirdPartyOrigin = String(rawPerm.dropFirst(21))
            parsedPermission = .storageAccess
        } else if rawPerm == "trackingprotection-pb" {
            parsedPermission = .tracking
        } else if rawPerm == "geo" {
            parsedPermission = .geolocation
        }
        
        return ContentPermission(
            uri: dict["uri"] as? String ?? "",
            thirdPartyOrigin: parsedThirdPartyOrigin,
            privateMode: dict["privateMode"] as? Bool ?? false,
            permission: parsedPermission,
            value: Value(rawValue: rawValue) ?? .prompt,
            rawValue: rawValue,
            contextId: dict["contextId"] as? String,
            principal: dict["principal"] as? String ?? "",
            rawPermission: rawPerm
        )
    }
    
    public var alertTitle: String? {
        let host = Self.permissionHost(from: uri)
        switch permission {
        case .geolocation:
            return "Allow \(host) to use your location?"
        case .desktopNotification:
            return "Allow \(host) to send notifications?"
        case .persistentStorage:
            return "Allow \(host) to store data in persistent storage?"
        case .mediaKeySystemAccess:
            return "Allow \(host) to play DRM-controlled content?"
        case .storageAccess:
            return "Allow \(Self.permissionHost(from: thirdPartyOrigin)) to use its cookies on \(host)?"
        case .localDeviceAccess:
            return "Allow \(host) to access other apps and services on this device?"
        case .localNetworkAccess:
            return "Allow \(host) to access apps and services on devices connected to your local network?"
        case .camera,
                .microphone,
                .webxr,
                .autoplay,
                .tracking,
            nil:
            return nil
        }
    }
    
    public var alertMessage: String? {
        switch permission {
        case .storageAccess:
            return "You may want to block access if it’s not clear why \(Self.permissionHost(from: thirdPartyOrigin)) needs this data."
        case .camera,
                .microphone,
                .geolocation,
                .desktopNotification,
                .persistentStorage,
                .webxr,
                .autoplay,
                .mediaKeySystemAccess,
                .tracking,
                .localDeviceAccess,
                .localNetworkAccess,
            nil:
            return nil
        }
    }
    
    var geckoDictionary: [String: Any?] {
        [
            "uri": uri,
            "thirdPartyOrigin": thirdPartyOrigin,
            "privateMode": privateMode,
            "perm": rawPermission,
            "value": rawValue,
            "contextId": contextId,
            "principal": principal,
        ]
    }
    
    public static func mediaAlertTitle(uri: String, videoRequested: Bool, audioRequested: Bool) -> String {
        let host = permissionHost(from: uri)
        switch (videoRequested, audioRequested) {
        case (true, true):
            return "Allow \(host) to use your camera and microphone?"
        case (true, false):
            return "Allow \(host) to use your camera?"
        case (false, true):
            return "Allow \(host) to use your microphone?"
        case (false, false):
            return "Allow \(host) to use your camera and microphone?"
        }
    }
    
    public static func permissionHost(from rawURI: String?) -> String {
        guard let rawURI,
              let url = URL(string: rawURI),
              let host = url.host,
              !host.isEmpty else {
            return "This site"
        }
        
        return host
    }
}
