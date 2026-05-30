//
//  ContentPermission.swift
//  Reynard
//
//  Created by Minh Ton on 22/2/26.
//

import Foundation
import UIKit

public struct ContentPermission {
    public enum Permission: String {
        case geolocation = "geolocation"
        case desktopNotification = "desktop-notification"
        case persistentStorage = "persistent-storage"
        case webxr = "xr"
        case autoplayInaudible = "autoplay-media-inaudible"
        case autoplayAudible = "autoplay-media-audible"
        case mediaKeySystemAccess = "media-key-system-access"
        case tracking = "trackingprotection"
        case storageAccess = "storage-access"
    }
    
    public enum Value: Int32 {
        case prompt = 3
        case deny = 2
        case allow = 1
    }
    
    public let uri: String
    public let thirdPartyOrigin: String?
    public let privateMode: Bool
    public let permission: Permission?
    public let value: Value
    public let contextId: String?
    
    static func fromDictionary(_ dict: [String: Any?]) -> ContentPermission {
        guard let rawPerm = dict["perm"] as? String else {
            return ContentPermission(
                uri: dict["uri"] as? String ?? "",
                thirdPartyOrigin: nil,
                privateMode: dict["privateMode"] as? Bool ?? false,
                permission: nil,
                value: .prompt,
                contextId: nil
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
        }
        
        let parsedValue: Value
        if let number = dict["value"] as? NSNumber, let value = Value(rawValue: number.int32Value) {
            parsedValue = value
        } else if let int32Value = dict["value"] as? Int32, let value = Value(rawValue: int32Value) {
            parsedValue = value
        } else {
            parsedValue = .prompt
        }
        
        return ContentPermission(
            uri: dict["uri"] as? String ?? "",
            thirdPartyOrigin: parsedThirdPartyOrigin,
            privateMode: dict["privateMode"] as? Bool ?? false,
            permission: parsedPermission,
            value: parsedValue,
            contextId: nil
        )
    }
}

private enum PermissionEvents: String, CaseIterable {
    case contentPermission = "GeckoView:ContentPermission"
    case mediaPermission = "GeckoView:MediaPermission"
}

private struct MediaPermissionSource {
    let rawId: String
    
    static func fromDictionary(_ dict: [String: Any?]) -> MediaPermissionSource {
        MediaPermissionSource(rawId: (dict["rawId"] as? String) ?? (dict["id"] as? String) ?? "")
    }
}

@MainActor
private func resolvePermissionPresenter(session: GeckoSession) -> UIViewController? {
    guard let childView = session.window?.view(),
          let geckoView = childView.superview else {
        return nil
    }
    
    return geckoView.nearestViewController()?.topPresentedController()
}

private func permissionHost(from rawURI: String?) -> String {
    guard let rawURI,
          let url = URL(string: rawURI),
          let host = url.host,
          !host.isEmpty else {
        return "This site"
    }
    
    return host
}

private func mediaPermissionResourceName(videoRequested: Bool, audioRequested: Bool) -> String {
    switch (videoRequested, audioRequested) {
    case (true, true):
        return "Camera and Microphone"
    case (true, false):
        return "Camera"
    case (false, true):
        return "Microphone"
    case (false, false):
        return "Device"
    }
}

@MainActor
private func requestContentPermission(
    session: GeckoSession,
    permission: ContentPermission
) async -> ContentPermission.Value {
    guard permission.permission == .geolocation,
          let presenter = resolvePermissionPresenter(session: session) else {
        return .deny
    }
    
    let host = permissionHost(from: permission.uri)
    return await withCheckedContinuation { continuation in
        let title = "\"\(host)\" Would Like to Use Your Location"
        let alert = UIAlertController(
            title: title,
            message: nil,
            preferredStyle: .alert
        )
        let attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 17)
            ]
        )
        alert.setValue(attributedTitle, forKey: "attributedTitle")
        alert.addAction(UIAlertAction(title: "Don't Allow", style: .cancel) { _ in
            continuation.resume(returning: .deny)
        })
        alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in
            continuation.resume(returning: .allow)
        })
        presenter.present(alert, animated: true)
    }
}

@MainActor
private func requestMediaPermission(
    session: GeckoSession,
    host: String,
    resourceName: String
) async -> Bool {
    guard let presenter = resolvePermissionPresenter(session: session) else {
        return false
    }
    
    return await withCheckedContinuation { continuation in
        let title = "\"\(host)\" Would Like to Access the \(resourceName)"
        let alert = UIAlertController(
            title: title,
            message: nil,
            preferredStyle: .alert
        )
        let attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 17)
            ]
        )
        alert.setValue(attributedTitle, forKey: "attributedTitle")
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            continuation.resume(returning: false)
        })
        alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in
            continuation.resume(returning: true)
        })
        presenter.present(alert, animated: true)
    }
}

func newPermissionHandler(_ session: GeckoSession) -> GeckoSessionHandler {
    GeckoSessionHandler(
        moduleName: "GeckoViewPermission",
        events: PermissionEvents.allCases.map(\.rawValue),
        session: session
    ) { @MainActor _, _, type, message in
        guard let event = PermissionEvents(rawValue: type) else {
            throw GeckoHandlerError("unknown message \(type)")
        }
        
        switch event {
        case .contentPermission:
            let permission = ContentPermission.fromDictionary(message ?? [:])
            guard permission.permission == .geolocation else {
                return ContentPermission.Value.prompt.rawValue
            }
            
            return await requestContentPermission(
                session: session,
                permission: permission
            ).rawValue
            
        case .mediaPermission:
            let videoSources = (message?["video"] as? [[String: Any?]])?.map(MediaPermissionSource.fromDictionary)
            let audioSources = (message?["audio"] as? [[String: Any?]])?.map(MediaPermissionSource.fromDictionary)
            let videoRequested = videoSources != nil
            let audioRequested = audioSources != nil
            guard videoSources != nil || audioSources != nil else {
                return false
            }
            
            guard videoSources?.first != nil || videoSources == nil,
                  audioSources?.first != nil || audioSources == nil else {
                return false
            }
            
            let host = permissionHost(from: message?["uri"] as? String)
            let resourceName = mediaPermissionResourceName(
                videoRequested: videoRequested,
                audioRequested: audioRequested
            )
            
            guard await requestMediaPermission(
                session: session,
                host: host,
                resourceName: resourceName
            ) else {
                return false
            }
            
            let response: [String: Any] = [
                "video": videoSources?.first?.rawId as Any? ?? NSNull(),
                "audio": audioSources?.first?.rawId as Any? ?? NSNull(),
            ]
            return response
        }
    }
}
