//
//  GeckoSessionController.swift
//  Reynard
//
//  Created by Minh Ton on 21/4/26.
//

import Foundation
import GeckoView

enum WebsiteModeNavigationAction {
    case reload
    case load(String)
}

final class GeckoSessionController {
    static let shared = GeckoSessionController()
    
    private enum SessionMode {
        static let mobile = 0
        static let desktop = 1
    }
    
    private var tabHostDesktopOverrides: [UUID: [String: Bool]] = [:]
    
    private init() {}
    
    // It's sad to have this function, because Gecko + iOS
    // is a super weird combination that websites don't expect!
    func sessionSettings(for urlString: String, tabID: UUID?) -> GeckoSessionSettings {
        let host = extractHost(from: urlString)
        
        let geckoVersion = Bundle.main.object(forInfoDictionaryKey: "GeckoVersion") as? String ?? ""
        let geckoMajorVersion = geckoVersion.split(whereSeparator: { !$0.isNumber }).first.map(String.init) ?? "0"
        let chromeMajorVersion = (Int(geckoMajorVersion) ?? 0) + 4
        
        let androidMobileUserAgent = "Mozilla/5.0 (Android 15; Mobile; rv:\(geckoMajorVersion).0) Gecko/\(geckoMajorVersion).0 Firefox/\(geckoMajorVersion).0"
        let androidDesktopUserAgent = "Mozilla/5.0 (X11; Linux x86_64; rv:\(geckoMajorVersion).0) Gecko/20100101 Firefox/\(geckoMajorVersion).0"
        let googleMobileUserAgent = "Mozilla/5.0 (Linux; Android 15; Nexus 5 Build/MRA58N) FxQuantum/\(geckoMajorVersion).0 AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(chromeMajorVersion).0.0.0 Mobile Safari/537.36"
        
        let requestDesktopWebsite = tabID.flatMap { tabID in
            isDesktopMode(for: urlString, tabID: tabID)
        } ?? Prefs.BrowsingSettings.requestDesktopWebsite
        let requestedMode = requestDesktopWebsite ? SessionMode.desktop : SessionMode.mobile
        
        // Always use the Android mobile user agent for AMO to
        // allow addons installation.
        if host == "addons.mozilla.org" {
            return GeckoSessionSettings(
                userAgentOverride: androidMobileUserAgent,
                userAgentMode: SessionMode.mobile,
                viewportMode: SessionMode.mobile
            )
        }
        
        // Addon setting pages also require the Android user agent to work properly.
        if urlString.starts(with: "moz-extension://") {
            return GeckoSessionSettings(
                userAgentOverride: androidMobileUserAgent,
                userAgentMode: SessionMode.mobile,
                viewportMode: SessionMode.mobile
            )
        }
        
        // I have so many people reporting broken UI issues, login
        // issues, etc on Google services, so this is a compatibility
        // hack stolen from the Google Search Fixer extension.
        if Prefs.CompatibilitySettings.useAndroidUserAgent && !requestDesktopWebsite,
           host?.split(separator: ".").contains("google") == true {
            return GeckoSessionSettings(
                userAgentOverride: googleMobileUserAgent,
                userAgentMode: SessionMode.mobile,
                viewportMode: SessionMode.mobile
            )
        }
        
        let shouldUseAndroidUserAgent = Prefs.CompatibilitySettings.useAndroidUserAgent || (host.map { host in
            Prefs.CompatibilitySettings.androidUserAgentDomains.contains { domainMatches(host: host, domain: $0) }
        } ?? false)
        
        switch (shouldUseAndroidUserAgent, requestDesktopWebsite) {
        case (true, true):
            return GeckoSessionSettings(
                userAgentOverride: androidDesktopUserAgent,
                userAgentMode: requestedMode,
                viewportMode: requestedMode
            )
        case (true, false):
            return GeckoSessionSettings(
                userAgentOverride: androidMobileUserAgent,
                userAgentMode: requestedMode,
                viewportMode: requestedMode
            )
        default:
            return GeckoSessionSettings(
                userAgentOverride: nil,
                userAgentMode: requestedMode,
                viewportMode: requestedMode
            )
        }
    }
    
    func isDesktopMode(for urlString: String, tabID: UUID) -> Bool? {
        guard let host = extractHost(from: urlString),
              urlString.starts(with: "moz-extension://") == false,
              host != "addons.mozilla.org" else {
            return nil
        }
        
        let overrides = tabHostDesktopOverrides[tabID]
        return overrides?[host] ?? overrides?.first(where: {
            domainMatches(host: host, domain: $0.key) || domainMatches(host: $0.key, domain: host)
        })?.value ?? Prefs.BrowsingSettings.requestDesktopWebsite
    }
    
    func changeWebsiteMode(for urlString: String, tabID: UUID) -> WebsiteModeNavigationAction? {
        guard let host = extractHost(from: urlString),
              let isDesktop = isDesktopMode(for: urlString, tabID: tabID) else {
            return nil
        }
        
        let newSetting = !isDesktop
        let overrideURL = desktopModeOverrideURL(for: urlString, isDesktopModeEnabled: newSetting)
        let overrideHost = overrideURL.flatMap(extractHost)
        var overrides = tabHostDesktopOverrides[tabID] ?? [:]
        
        for relatedHost in overrideHostsToUpdate(for: host, overrideHost: overrideHost, existingOverrides: overrides) {
            overrides.removeValue(forKey: relatedHost)
        }
        
        if newSetting == Prefs.BrowsingSettings.requestDesktopWebsite {
            if overrides.isEmpty {
                tabHostDesktopOverrides.removeValue(forKey: tabID)
            } else {
                tabHostDesktopOverrides[tabID] = overrides
            }
        } else {
            overrides[overrideHost ?? host] = newSetting
            tabHostDesktopOverrides[tabID] = overrides
        }
        
        if let overrideURL {
            return .load(overrideURL)
        }
        
        return .reload
    }
    
    func clearOverrides(forTabID tabID: UUID) {
        tabHostDesktopOverrides.removeValue(forKey: tabID)
    }
    
    func extractHost(from urlString: String) -> String? {
        if let host = URL(string: urlString)?.host?.lowercased() {
            return host
        }
        
        if let host = URL(string: "https://" + urlString)?.host?.lowercased() {
            return host
        }
        
        return nil
    }
    
    func checkForMobileSite(_ urlString: String) -> String? {
        guard var components = URLComponents(string: urlString),
              let host = components.host else {
            return nil
        }
        
        let normalizedHost = host.lowercased()
        let prefixes = ["m.", "mobile."]
        guard let prefix = prefixes.first(where: { normalizedHost.hasPrefix($0) }) else {
            return nil
        }
        
        components.host = String(normalizedHost.dropFirst(prefix.count))
        return components.url?.absoluteString
    }
    
    private func domainMatches(host: String, domain: String) -> Bool {
        let normalizedDomain = domain.lowercased()
        return host == normalizedDomain || host.hasSuffix("." + normalizedDomain)
    }
    
    private func desktopModeOverrideURL(for urlString: String, isDesktopModeEnabled: Bool) -> String? {
        guard isDesktopModeEnabled else {
            return nil
        }
        
        return checkForMobileSite(urlString)
    }
    
    private func overrideHostsToUpdate(for host: String, overrideHost: String?, existingOverrides: [String: Bool]) -> Set<String> {
        var relatedHosts: Set<String> = [host]
        if let overrideHost {
            relatedHosts.insert(overrideHost)
        }
        
        for existingHost in existingOverrides.keys {
            if relatedHosts.contains(where: {
                domainMatches(host: existingHost, domain: $0) || domainMatches(host: $0, domain: existingHost)
            }) {
                relatedHosts.insert(existingHost)
            }
        }
        
        return relatedHosts
    }
}
