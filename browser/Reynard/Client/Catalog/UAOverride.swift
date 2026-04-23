//
//  UAOverride.swift
//  Reynard
//
//  Created by Minh Ton on 21/4/26.
//

import Foundation

final class UAOverride {
    static let shared = UAOverride()
    
    private static let remoteURL = "https://github.com/minh-ton/reynard-browser/releases/download/0.0.1-a1/ua-override.json"
    private static let cachedFileName = "ua-override.json"
    
    struct Profile {
        let userAgent: String
        let sites: [String]
    }
    
    private let queue = DispatchQueue(label: "me.minh-ton.reynard.ua-override", attributes: .concurrent)
    private var _cachedProfiles: [Profile] = []
    
    private var cachedProfiles: [Profile] {
        queue.sync { _cachedProfiles }
    }
    
    var defaultSites: [String] {
        queue.sync {
            _cachedProfiles.flatMap(\.sites).sorted()
        }
    }
    
    private init() {
        _cachedProfiles = Self.loadFromDisk()
        fetchRemote()
    }
    
    private static func cachedFileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(cachedFileName)
    }
    
    private static func parseProfiles(from data: Data) -> [Profile] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        var profiles: [Profile] = []
        for (_, value) in json {
            guard let entry = value as? [String: Any],
                  let ua = entry["user-agent"] as? String,
                  let sites = entry["sites"] as? [String] else { continue }
            profiles.append(Profile(userAgent: ua, sites: sites))
        }
        return profiles
    }
    
    private static func loadFromDisk() -> [Profile] {
        guard let data = try? Data(contentsOf: cachedFileURL()) else { return [] }
        return parseProfiles(from: data)
    }
    
    private func fetchRemote() {
        DispatchQueue.global(qos: .background).async {
            guard let url = URL(string: Self.remoteURL),
                  let data = try? Data(contentsOf: url) else { return }
            
            let profiles = Self.parseProfiles(from: data)
            try? FileManager.default.removeItem(at: Self.cachedFileURL())
            try? data.write(to: Self.cachedFileURL())
            
            self.queue.async(flags: .barrier) {
                self._cachedProfiles = profiles
            }
        }
    }
    
    func userAgent(for urlString: String) -> String? {
        guard let host = extractHost(from: urlString) else { return nil }
        
        for profile in cachedProfiles {
            if profile.sites.contains(where: { domainMatches(host: host, domain: $0) }) {
                return profile.userAgent
            }
        }
        
        let androidUA = "Mozilla/5.0 (Android 15; Mobile; rv:150.0) Gecko/150.0 Firefox/150.0"
        
        let prefs = BrowserPreferences.shared
        if prefs.useAndroidUserAgent {
            return androidUA
        }
        
        let userDomains = prefs.androidUserAgentDomains
        if userDomains.contains(where: { domainMatches(host: host, domain: $0) }) {
            return androidUA
        }
        
        return nil
    }
    
    private func extractHost(from urlString: String) -> String? {
        if let h = URL(string: urlString)?.host?.lowercased() { return h }
        if let h = URL(string: "https://" + urlString)?.host?.lowercased() { return h }
        return nil
    }
    
    private func domainMatches(host: String, domain: String) -> Bool {
        let d = domain.lowercased()
        return host == d || host.hasSuffix("." + d)
    }
}
