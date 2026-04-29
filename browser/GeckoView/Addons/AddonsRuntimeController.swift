//
//  AddonsRuntimeController.swift
//  Reynard
//
//  Created by Minh Ton on 28/4/26.
//

import Foundation

public enum AddonInstallMethod: String {
    case manager
}

public enum AddonEnableSource: String {
    case user
    case app
}

public enum AddonActionKind {
    case browser
    case page
}

public struct AddonAction {
    public let kind: AddonActionKind
    public let title: String?
    public let enabled: Bool?
    public let badgeText: String?
    public let popup: String?
    public let patternMatching: Bool
    
    init(kind: AddonActionKind, dictionary: [String: Any?]) {
        self.kind = kind
        title = dictionary["title"] as? String
        badgeText = dictionary["badgeText"] as? String
        popup = dictionary["popup"] as? String
        patternMatching = dictionary["patternMatching"] as? Bool ?? false
        
        if patternMatching {
            enabled = true
        } else if let value = dictionary["enabled"] as? Bool {
            enabled = value
        } else if let number = dictionary["enabled"] as? NSNumber {
            enabled = number.boolValue
        } else {
            enabled = nil
        }
    }
    
    public func merged(with defaultAction: AddonAction) -> AddonAction {
        AddonAction(
            kind: kind,
            title: title ?? defaultAction.title,
            enabled: enabled ?? defaultAction.enabled,
            badgeText: badgeText ?? defaultAction.badgeText,
            popup: popup ?? defaultAction.popup,
            patternMatching: patternMatching || defaultAction.patternMatching
        )
    }
    
    private init(
        kind: AddonActionKind,
        title: String?,
        enabled: Bool?,
        badgeText: String?,
        popup: String?,
        patternMatching: Bool
    ) {
        self.kind = kind
        self.title = title
        self.enabled = enabled
        self.badgeText = badgeText
        self.popup = popup
        self.patternMatching = patternMatching
    }
}

public struct AddonMetaData {
    public let name: String?
    public let description: String?
    public let version: String
    public let iconURL: String?
    public let optionsPageURL: String?
    public let openOptionsPageInTab: Bool
    public let enabled: Bool
    public let allowedInPrivateBrowsing: Bool
    public let baseURL: String
    public let requiredPermissions: [String]
    public let requiredOrigins: [String]
    public let optionalPermissions: [String]
    public let optionalOrigins: [String]
    public let grantedOptionalPermissions: [String]
    public let grantedOptionalOrigins: [String]
    public let downloadURL: String?
    public let amoListingURL: String?
    public let disabledFlags: [String]
    
    init(dictionary: [String: Any?]) {
        name = dictionary["name"] as? String
        description = dictionary["description"] as? String
        version = dictionary["version"] as? String ?? ""
        iconURL = Self.resolveIconURL(from: dictionary["icons"] ?? nil)
        optionsPageURL = dictionary["optionsPageURL"] as? String
        openOptionsPageInTab = dictionary["openOptionsPageInTab"] as? Bool ?? false
        enabled = dictionary["enabled"] as? Bool ?? false
        allowedInPrivateBrowsing = dictionary["privateBrowsingAllowed"] as? Bool ?? false
        baseURL = dictionary["baseURL"] as? String ?? ""
        requiredPermissions = dictionary["requiredPermissions"] as? [String] ?? []
        requiredOrigins = dictionary["requiredOrigins"] as? [String] ?? []
        optionalPermissions = dictionary["optionalPermissions"] as? [String] ?? []
        optionalOrigins = dictionary["optionalOrigins"] as? [String] ?? []
        grantedOptionalPermissions = dictionary["grantedOptionalPermissions"] as? [String] ?? []
        grantedOptionalOrigins = dictionary["grantedOptionalOrigins"] as? [String] ?? []
        downloadURL = dictionary["downloadUrl"] as? String
        amoListingURL = dictionary["amoListingURL"] as? String
        disabledFlags = dictionary["disabledFlags"] as? [String] ?? []
    }
    
    private static func resolveIconURL(from value: Any?) -> String? {
        let entries: [(String, Any?)]
        if let dictionary = value as? [String: Any?] {
            entries = Array(dictionary)
        } else if let dictionary = value as? [NSNumber: Any?] {
            entries = dictionary.map { ($0.key.stringValue, $0.value) }
        } else {
            return nil
        }
        
        let resolvedEntries = entries
            .compactMap { key, value -> (Int, String)? in
                guard let size = Int(key) else {
                    return nil
                }
                if let url = value as? String {
                    return (size, url)
                }
                if let url = value as? NSString {
                    return (size, url as String)
                }
                return nil
            }
        
        let preferredMinimumSize = 32
        let rasterEntries = resolvedEntries.filter { !$0.1.lowercased().hasSuffix(".svg") }
        if let preferredRaster = rasterEntries
            .sorted(by: { lhs, rhs in
                let lhsDelta = max(lhs.0 - preferredMinimumSize, 0)
                let rhsDelta = max(rhs.0 - preferredMinimumSize, 0)
                if lhsDelta == rhsDelta {
                    return lhs.0 < rhs.0
                }
                return lhsDelta < rhsDelta
            })
                .first {
            return preferredRaster.1
        }
        
        return resolvedEntries
            .sorted(by: { lhs, rhs in
                let lhsDelta = max(lhs.0 - preferredMinimumSize, 0)
                let rhsDelta = max(rhs.0 - preferredMinimumSize, 0)
                if lhsDelta == rhsDelta {
                    return lhs.0 < rhs.0
                }
                return lhsDelta < rhsDelta
            })
            .first?.1
    }
}

public final class Addon: NSObject {
    public let id: String
    public let locationURI: String
    public let isBuiltIn: Bool
    public let flags: Int
    public private(set) var metaData: AddonMetaData
    
    public internal(set) var browserAction: AddonAction?
    public internal(set) var pageAction: AddonAction?
    
    init(dictionary: [String: Any?]) {
        id = dictionary["webExtensionId"] as? String ?? ""
        locationURI = dictionary["locationURI"] as? String ?? ""
        isBuiltIn = dictionary["isBuiltIn"] as? Bool ?? false
        if let intValue = dictionary["webExtensionFlags"] as? Int {
            flags = intValue
        } else if let number = dictionary["webExtensionFlags"] as? NSNumber {
            flags = number.intValue
        } else {
            flags = 0
        }
        
        metaData = AddonMetaData(
            dictionary: dictionary["metaData"] as? [String: Any?] ?? [:]
        )
    }
    
    func update(from dictionary: [String: Any?]) {
        metaData = AddonMetaData(
            dictionary: dictionary["metaData"] as? [String: Any?] ?? [:]
        )
    }
}

public struct AddonCreateTabDetails {
    public let active: Bool?
    public let index: Int?
    public let url: String?
    
    init(dictionary: [String: Any?]) {
        active = dictionary["active"] as? Bool
        if let intValue = dictionary["index"] as? Int {
            index = intValue
        } else if let number = dictionary["index"] as? NSNumber {
            index = number.intValue
        } else {
            index = nil
        }
        url = dictionary["url"] as? String
    }
}

public struct AddonUpdateTabDetails {
    public let active: Bool?
    public let url: String?
    
    init(dictionary: [String: Any?]) {
        active = dictionary["active"] as? Bool
        url = dictionary["url"] as? String
    }
}

public struct AddonInstallFailure: Error {
    public let code: String?
    public let extensionID: String?
    public let extensionName: String?
    public let extensionVersion: String?
}

public protocol AddonEmbedderDelegate: AnyObject {
    func addonsController(_ controller: AddonsRuntimeController, didUpdate addon: Addon)
    func addonsController(_ controller: AddonsRuntimeController, didFailInstall failure: AddonInstallFailure)
    func addonsController(_ controller: AddonsRuntimeController, didUpdate action: AddonAction, for addon: Addon, session: GeckoSession?)
    func addonsController(_ controller: AddonsRuntimeController, didRequestOpenPopup popupURL: String, for addon: Addon, action: AddonAction, session: GeckoSession?)
    func addonsController(_ controller: AddonsRuntimeController, didRequestOpenOptionsPageFor addon: Addon)
    func addonsController(_ controller: AddonsRuntimeController, createNewTabFor addon: Addon, details: AddonCreateTabDetails, newSessionID: String) -> Bool
    func addonsController(_ controller: AddonsRuntimeController, updateTab session: GeckoSession, for addon: Addon, details: AddonUpdateTabDetails) -> AllowOrDeny
    func addonsController(_ controller: AddonsRuntimeController, closeTab session: GeckoSession, for addon: Addon) -> AllowOrDeny
}

public extension AddonEmbedderDelegate {
    func addonsController(_ controller: AddonsRuntimeController, didUpdate addon: Addon) {}
    func addonsController(_ controller: AddonsRuntimeController, didFailInstall failure: AddonInstallFailure) {}
    func addonsController(_ controller: AddonsRuntimeController, didUpdate action: AddonAction, for addon: Addon, session: GeckoSession?) {}
    func addonsController(_ controller: AddonsRuntimeController, didRequestOpenPopup popupURL: String, for addon: Addon, action: AddonAction, session: GeckoSession?) {}
    func addonsController(_ controller: AddonsRuntimeController, didRequestOpenOptionsPageFor addon: Addon) {}
    func addonsController(_ controller: AddonsRuntimeController, createNewTabFor addon: Addon, details: AddonCreateTabDetails, newSessionID: String) -> Bool { false }
    func addonsController(_ controller: AddonsRuntimeController, updateTab session: GeckoSession, for addon: Addon, details: AddonUpdateTabDetails) -> AllowOrDeny { .deny }
    func addonsController(_ controller: AddonsRuntimeController, closeTab session: GeckoSession, for addon: Addon) -> AllowOrDeny { .deny }
}

enum AddonRuntimeEvent: String, CaseIterable {
    case browserActionUpdate = "GeckoView:BrowserAction:Update"
    case browserActionOpenPopup = "GeckoView:BrowserAction:OpenPopup"
    case pageActionUpdate = "GeckoView:PageAction:Update"
    case pageActionOpenPopup = "GeckoView:PageAction:OpenPopup"
    case openOptionsPage = "GeckoView:WebExtension:OpenOptionsPage"
    case newTab = "GeckoView:WebExtension:NewTab"
    case installPrompt = "GeckoView:WebExtension:InstallPrompt"
    case optionalPrompt = "GeckoView:WebExtension:OptionalPrompt"
    case updatePrompt = "GeckoView:WebExtension:UpdatePrompt"
    case installationFailed = "GeckoView:WebExtension:OnInstallationFailed"
    case optionalPermissionsChanged = "GeckoView:WebExtension:OnOptionalPermissionsChanged"
    case ready = "GeckoView:WebExtension:OnReady"
    case disabling = "GeckoView:WebExtension:OnDisabling"
    case disabled = "GeckoView:WebExtension:OnDisabled"
    case enabling = "GeckoView:WebExtension:OnEnabling"
    case enabled = "GeckoView:WebExtension:OnEnabled"
    case uninstalling = "GeckoView:WebExtension:OnUninstalling"
    case uninstalled = "GeckoView:WebExtension:OnUninstalled"
    case installing = "GeckoView:WebExtension:OnInstalling"
    case installed = "GeckoView:WebExtension:OnInstalled"
}

final class AddonSessionListener: GeckoEventListenerInternal {
    weak var session: GeckoSession?
    
    init(session: GeckoSession) {
        self.session = session
    }
    
    let events: [String] = [
        "GeckoView:BrowserAction:Update",
        "GeckoView:BrowserAction:OpenPopup",
        "GeckoView:PageAction:Update",
        "GeckoView:PageAction:OpenPopup",
        "GeckoView:WebExtension:OpenOptionsPage",
        "GeckoView:WebExtension:NewTab",
        "GeckoView:WebExtension:UpdateTab",
        "GeckoView:WebExtension:CloseTab",
    ]
    
    @MainActor
    func handleMessage(type: String, message: [String: Any?]?) async throws -> Any? {
        guard let session else {
            throw GeckoHandlerError("session has been destroyed")
        }
        return try await AddonsRuntimeController.shared.handleSessionEvent(
            type: type,
            message: message,
            session: session
        )
    }
}

public final class AddonsRuntimeController: NSObject, GeckoEventListenerInternal {
    public static let shared = AddonsRuntimeController()
    
    public weak var delegate: AddonEmbedderDelegate? {
        didSet {
            if delegate == nil {
                attachedActionDelegateAddonIDs.removeAll()
            }
            guard delegate != nil else {
                return
            }
            Task { @MainActor in
                _ = try? await self.list()
                self.notifyActionDelegateAttached()
            }
        }
    }
    
    private var addonsByID: [String: Addon] = [:]
    private var attachedActionDelegateAddonIDs = Set<String>()
    private var installCounter = 0
    
    public var installedAddons: [Addon] {
        Array(addonsByID.values).sorted {
            ($0.metaData.name ?? $0.id).localizedCaseInsensitiveCompare($1.metaData.name ?? $1.id) == .orderedAscending
        }
    }
    
    private override init() {
        super.init()
        for event in AddonRuntimeEvent.allCases {
            GeckoEventDispatcherWrapper.runtimeInstance.addListener(type: event.rawValue, listener: self)
        }
    }
    
    func register(sessionListener: AddonSessionListener) {
        guard let session = sessionListener.session else {
            return
        }
        for event in sessionListener.events {
            session.dispatcher.addListener(type: event, listener: sessionListener)
        }
    }
    
    public func list() async throws -> [Addon] {
        let response = try await GeckoEventDispatcherWrapper.runtimeInstance.query(type: "GeckoView:WebExtension:List")
        guard let dictionary = response as? [String: Any?] else {
            return Array(addonsByID.values)
        }
        
        let entries = dictionary["extensions"] as? [[String: Any?]] ?? []
        let listedAddonIDs = Set(entries.compactMap { $0["webExtensionId"] as? String })
        let staleAddonIDs = addonsByID.keys.filter { listedAddonIDs.contains($0) == false }
        let removedAddons = staleAddonIDs.compactMap { removeAddon(byID: $0) }
        let _ = entries.map { self.upsertAddon(from: $0) }
        removedAddons.forEach { delegate?.addonsController(self, didUpdate: $0) }
        return installedAddons
    }
    
    public func addon(byID id: String) async throws -> Addon? {
        if let cached = addonsByID[id] {
            return cached
        }
        
        let response = try await GeckoEventDispatcherWrapper.runtimeInstance.query(
            type: "GeckoView:WebExtension:Get",
            message: ["extensionId": id]
        )
        guard let dictionary = response as? [String: Any?],
              let extensionDictionary = dictionary["extension"] as? [String: Any?] else {
            return nil
        }
        
        return upsertAddon(from: extensionDictionary)
    }
    
    public func install(url: String, installMethod: AddonInstallMethod? = nil) async throws -> Addon {
        installCounter += 1
        let response = try await GeckoEventDispatcherWrapper.runtimeInstance.query(
            type: "GeckoView:WebExtension:Install",
            message: [
                "locationUri": url,
                "installId": "reynard-\(installCounter)",
                "installMethod": installMethod?.rawValue as Any,
            ]
        )
        guard let dictionary = response as? [String: Any?],
              let extensionDictionary = dictionary["extension"] as? [String: Any?] else {
            throw GeckoHandlerError("Invalid install response")
        }
        let addon = upsertAddon(from: extensionDictionary)
        delegate?.addonsController(self, didUpdate: addon)
        return addon
    }
    
    public func enable(_ addon: Addon, source: AddonEnableSource = .user) async throws -> Addon {
        try await mutateAddon(
            type: "GeckoView:WebExtension:Enable",
            message: ["webExtensionId": addon.id, "source": source.rawValue]
        )
    }
    
    public func disable(_ addon: Addon, source: AddonEnableSource = .user) async throws -> Addon {
        try await mutateAddon(
            type: "GeckoView:WebExtension:Disable",
            message: ["webExtensionId": addon.id, "source": source.rawValue]
        )
    }
    
    public func uninstall(_ addon: Addon) async throws {
        _ = try await GeckoEventDispatcherWrapper.runtimeInstance.query(
            type: "GeckoView:WebExtension:Uninstall",
            message: ["webExtensionId": addon.id]
        )
        if let removedAddon = removeAddon(byID: addon.id) {
            delegate?.addonsController(self, didUpdate: removedAddon)
        }
    }
    
    public func update(_ addon: Addon) async throws -> Addon? {
        let response = try await GeckoEventDispatcherWrapper.runtimeInstance.query(
            type: "GeckoView:WebExtension:Update",
            message: ["webExtensionId": addon.id]
        )
        guard let dictionary = response as? [String: Any?],
              let extensionDictionary = dictionary["extension"] as? [String: Any?] else {
            return nil
        }
        let updated = upsertAddon(from: extensionDictionary)
        delegate?.addonsController(self, didUpdate: updated)
        return updated
    }
    
    public func clickAction(kind: AddonActionKind, addon: Addon) async throws -> String? {
        let event = kind == .browser ? "GeckoView:BrowserAction:Click" : "GeckoView:PageAction:Click"
        let response = try await GeckoEventDispatcherWrapper.runtimeInstance.query(
            type: event,
            message: ["extensionId": addon.id]
        )
        return response as? String
    }
    
    private func mutateAddon(type: String, message: [String: Any?]) async throws -> Addon {
        let response = try await GeckoEventDispatcherWrapper.runtimeInstance.query(type: type, message: message)
        guard let dictionary = response as? [String: Any?],
              let extensionDictionary = dictionary["extension"] as? [String: Any?] else {
            throw GeckoHandlerError("Invalid extension response")
        }
        let updated = upsertAddon(from: extensionDictionary)
        delegate?.addonsController(self, didUpdate: updated)
        return updated
    }
    
    @MainActor
    func handleSessionEvent(type: String, message: [String: Any?]?, session: GeckoSession) async throws -> Any? {
        switch type {
        case "GeckoView:BrowserAction:Update":
            try await handleActionUpdate(kind: .browser, message: message, session: session)
            return nil
        case "GeckoView:PageAction:Update":
            try await handleActionUpdate(kind: .page, message: message, session: session)
            return nil
        case "GeckoView:BrowserAction:OpenPopup":
            try await handleOpenPopup(kind: .browser, message: message, session: session)
            return nil
        case "GeckoView:PageAction:OpenPopup":
            try await handleOpenPopup(kind: .page, message: message, session: session)
            return nil
        case "GeckoView:WebExtension:OpenOptionsPage":
            guard let extensionID = message?["extensionId"] as? String,
                  let addon = try await addon(byID: extensionID) else {
                throw GeckoHandlerError("runtime.openOptionsPage is not supported")
            }
            delegate?.addonsController(self, didRequestOpenOptionsPageFor: addon)
            return nil
        case "GeckoView:WebExtension:NewTab":
            guard let extensionID = message?["extensionId"] as? String,
                  let newSessionID = message?["newSessionId"] as? String,
                  let addon = try await addon(byID: extensionID) else {
                return false
            }
            let details = AddonCreateTabDetails(
                dictionary: message?["createProperties"] as? [String: Any?] ?? [:]
            )
            return delegate?.addonsController(
                self,
                createNewTabFor: addon,
                details: details,
                newSessionID: newSessionID
            ) ?? false
        case "GeckoView:WebExtension:UpdateTab":
            guard let extensionID = message?["extensionId"] as? String,
                  let addon = try await addon(byID: extensionID) else {
                throw GeckoHandlerError("tabs.update is not supported")
            }
            let details = AddonUpdateTabDetails(
                dictionary: message?["updateProperties"] as? [String: Any?] ?? [:]
            )
            if delegate?.addonsController(self, updateTab: session, for: addon, details: details) == .allow {
                return nil
            }
            throw GeckoHandlerError("tabs.update is not supported")
        case "GeckoView:WebExtension:CloseTab":
            guard let extensionID = message?["extensionId"] as? String,
                  let addon = try await addon(byID: extensionID) else {
                throw GeckoHandlerError("tabs.remove is not supported")
            }
            if delegate?.addonsController(self, closeTab: session, for: addon) == .allow {
                return nil
            }
            throw GeckoHandlerError("tabs.remove is not supported")
        default:
            throw GeckoHandlerError("Unhandled WebExtension session event \(type)")
        }
    }
    
    @MainActor
    public func handleMessage(type: String, message: [String: Any?]?) async throws -> Any? {
        guard let event = AddonRuntimeEvent(rawValue: type) else {
            throw GeckoHandlerError("unknown message \(type)")
        }
        
        switch event {
        case .browserActionUpdate:
            try await handleActionUpdate(kind: .browser, message: message, session: nil)
            return nil
        case .pageActionUpdate:
            try await handleActionUpdate(kind: .page, message: message, session: nil)
            return nil
        case .browserActionOpenPopup:
            try await handleOpenPopup(kind: .browser, message: message, session: nil)
            return nil
        case .pageActionOpenPopup:
            try await handleOpenPopup(kind: .page, message: message, session: nil)
            return nil
        case .openOptionsPage:
            guard let extensionID = message?["extensionId"] as? String,
                  let addon = try await addon(byID: extensionID) else {
                throw GeckoHandlerError("runtime.openOptionsPage is not supported")
            }
            delegate?.addonsController(self, didRequestOpenOptionsPageFor: addon)
            return nil
        case .newTab:
            guard let extensionID = message?["extensionId"] as? String,
                  let newSessionID = message?["newSessionId"] as? String,
                  let addon = try await addon(byID: extensionID) else {
                return false
            }
            let details = AddonCreateTabDetails(
                dictionary: message?["createProperties"] as? [String: Any?] ?? [:]
            )
            return delegate?.addonsController(
                self,
                createNewTabFor: addon,
                details: details,
                newSessionID: newSessionID
            ) ?? false
        case .installPrompt:
            return [
                "allow": true,
                "privateBrowsingAllowed": false,
                "isTechnicalAndInteractionDataGranted": false,
            ]
        case .optionalPrompt, .updatePrompt:
            return ["allow": false]
        case .installationFailed:
            let failure = AddonInstallFailure(
                code: stringValue(message?["error"]),
                extensionID: stringValue(message?["addonId"]),
                extensionName: stringValue(message?["addonName"]),
                extensionVersion: stringValue(message?["addonVersion"])
            )
            delegate?.addonsController(self, didFailInstall: failure)
            return nil
        case .uninstalled:
            if let removedAddon = removeAddon(from: message) {
                delegate?.addonsController(self, didUpdate: removedAddon)
            }
            return nil
        case .optionalPermissionsChanged, .ready, .disabling, .disabled, .enabling, .enabled, .uninstalling, .installing, .installed:
            if let extensionDictionary = message?["extension"] as? [String: Any?] {
                let addon = upsertAddon(from: extensionDictionary)
                delegate?.addonsController(self, didUpdate: addon)
            }
            return nil
        }
    }
    
    private func notifyActionDelegateAttached() {
        for addon in addonsByID.values {
            notifyActionDelegateAttached(for: addon)
        }
    }
    
    private func notifyActionDelegateAttached(for addon: Addon) {
        guard delegate != nil,
              attachedActionDelegateAddonIDs.contains(addon.id) == false else {
            return
        }
        
        attachedActionDelegateAddonIDs.insert(addon.id)
        GeckoEventDispatcherWrapper.runtimeInstance.dispatch(
            type: "GeckoView:ActionDelegate:Attached",
            message: ["extensionId": addon.id]
        )
    }
    
    private func upsertAddon(from dictionary: [String: Any?]) -> Addon {
        let id = dictionary["webExtensionId"] as? String ?? ""
        if let existing = addonsByID[id] {
            existing.update(from: dictionary)
            notifyActionDelegateAttached(for: existing)
            return existing
        }
        let created = Addon(dictionary: dictionary)
        addonsByID[id] = created
        notifyActionDelegateAttached(for: created)
        return created
    }
    
    private func removeAddon(from message: [String: Any?]?) -> Addon? {
        guard let addonID = addonID(from: message) else {
            return nil
        }
        return removeAddon(byID: addonID)
    }
    
    private func removeAddon(byID addonID: String) -> Addon? {
        attachedActionDelegateAddonIDs.remove(addonID)
        return addonsByID.removeValue(forKey: addonID)
    }
    
    private func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }
    
    private func addonID(from message: [String: Any?]?) -> String? {
        if let extensionID = message?["extensionId"] as? String,
           extensionID.isEmpty == false {
            return extensionID
        }
        
        if let addonID = stringValue(message?["addonId"]),
           addonID.isEmpty == false {
            return addonID
        }
        
        if let extensionDictionary = message?["extension"] as? [String: Any?],
           let addonID = extensionDictionary["webExtensionId"] as? String,
           addonID.isEmpty == false {
            return addonID
        }
        
        return nil
    }
    
    private func action(
        kind: AddonActionKind,
        from message: [String: Any?]?
    ) -> AddonAction? {
        guard let dictionary = message?["action"] as? [String: Any?] else {
            return nil
        }
        return AddonAction(kind: kind, dictionary: dictionary)
    }
    
    private func handleActionUpdate(
        kind: AddonActionKind,
        message: [String: Any?]?,
        session: GeckoSession?
    ) async throws {
        guard let extensionID = message?["extensionId"] as? String,
              let action = action(kind: kind, from: message),
              let addon = try await addon(byID: extensionID) else {
            return
        }
        
        if session == nil {
            if kind == .browser {
                addon.browserAction = action
            } else {
                addon.pageAction = action
            }
        }
        delegate?.addonsController(self, didUpdate: action, for: addon, session: session)
    }
    
    private func handleOpenPopup(
        kind: AddonActionKind,
        message: [String: Any?]?,
        session: GeckoSession?
    ) async throws {
        guard let extensionID = message?["extensionId"] as? String,
              let addon = try await addon(byID: extensionID),
              let action = action(kind: kind, from: message),
              let popupURL = message?["popupUri"] as? String,
              !popupURL.isEmpty else {
            return
        }
        delegate?.addonsController(
            self,
            didRequestOpenPopup: popupURL,
            for: addon,
            action: action,
            session: session
        )
    }
}
