//
//  UserAgentController.swift
//  Reynard
//
//  Created by Minh Ton on 21/4/26.
//

import Foundation

final class UserAgentController {
    static let shared = UserAgentController()
    
    private init() {}
    
    // It's sad to have this function, because Gecko + iOS
    // is a super weird combination that websites don't expect!
    func userAgent(for urlString: String) -> String? {
        let host = extractHost(from: urlString)
        
        let geckoVersion = Bundle.main.object(forInfoDictionaryKey: "GeckoVersion") as? String ?? ""
        let geckoMajorVersion = geckoVersion.split(whereSeparator: { !$0.isNumber }).first.map(String.init) ?? "0"
        let chromeMajorVersion = (Int(geckoMajorVersion) ?? 0) + 4
        
        let androidMobileUserAgent = "Mozilla/5.0 (Android 15; Mobile; rv:\(geckoMajorVersion).0) Gecko/\(geckoMajorVersion).0 Firefox/\(geckoMajorVersion).0"
        let androidDesktopUserAgent = "Mozilla/5.0 (X11; Linux x86_64; rv:\(geckoMajorVersion).0) Gecko/20100101 Firefox/\(geckoMajorVersion).0"
        let defaultMobileUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X; Mobile; rv:\(geckoMajorVersion).0) Gecko/\(geckoMajorVersion).0 Firefox/\(geckoMajorVersion).0"
        let defaultDesktopUserAgent = "Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X; rv:\(geckoMajorVersion).0) Gecko/\(geckoMajorVersion).0 Firefox/\(geckoMajorVersion).0"
        let googleMobileUserAgent = "Mozilla/5.0 (Linux; Android 15; Nexus 5 Build/MRA58N) FxQuantum/\(geckoMajorVersion).0 AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(chromeMajorVersion).0.0.0 Mobile Safari/537.36"
        
        let prefs = BrowserPreferences.shared
        // Always use the Android mobile user agent for AMO to
        // allow addons installation.
        if host == "addons.mozilla.org" {
            return androidMobileUserAgent
        }
        
        // Addon setting pages also require the Android user agent to work properly.
        if urlString.starts(with: "moz-extension://") {
            return androidMobileUserAgent
        }
        
        // I have so many people reporting broken UI issues, login
        // issues, etc on Google services, so this is a compatibility
        // hack stolen from the Google Search Fixer extension.
        if prefs.useAndroidUserAgent && !prefs.requestDesktopWebsite,
           host?.split(separator: ".").contains("google") == true {
            return googleMobileUserAgent
        }
        
        let shouldUseAndroidUserAgent = prefs.useAndroidUserAgent || (host.map { host in
            prefs.androidUserAgentDomains.contains { domainMatches(host: host, domain: $0) }
        } ?? false)
        
        switch (shouldUseAndroidUserAgent, prefs.requestDesktopWebsite) {
        case (true, true):
            return androidDesktopUserAgent
        case (true, false):
            return androidMobileUserAgent
        case (false, true):
            return defaultDesktopUserAgent
        default:
            return defaultMobileUserAgent
        }
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
    
    private func domainMatches(host: String, domain: String) -> Bool {
        let normalizedDomain = domain.lowercased()
        return host == normalizedDomain || host.hasSuffix("." + normalizedDomain)
    }
}
