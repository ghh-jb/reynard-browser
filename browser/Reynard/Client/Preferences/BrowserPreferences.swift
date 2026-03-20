//
//  BrowserPreferences.swift
//  Reynard
//
//  Created by Minh Ton on 10/3/26.
//

import Foundation

final class BrowserPreferences {
    enum SearchEngine: String, CaseIterable {
        case google
        case yahoo
        case bing
        case brave
        case duckDuckGo
        case ecosia
        case custom
        
        var displayName: String {
            switch self {
            case .google:
                return "Google"
            case .yahoo:
                return "Yahoo"
            case .bing:
                return "Bing"
            case .brave:
                return "Brave"
            case .duckDuckGo:
                return "DuckDuckGo"
            case .ecosia:
                return "Ecosia"
            case .custom:
                return "Custom"
            }
        }
        
        var searchTemplate: String? {
            switch self {
            case .google:
                return "https://www.google.com/search?q=%s"
            case .yahoo:
                return "https://search.yahoo.com/search?p=%s"
            case .bing:
                return "https://www.bing.com/search?q=%s"
            case .brave:
                return "https://search.brave.com/search?q=%s"
            case .duckDuckGo:
                return "https://duckduckgo.com/?q=%s"
            case .ecosia:
                return "https://www.ecosia.org/search?q=%s"
            case .custom:
                return nil
            }
        }
    }
    
    private enum Keys {
        static let searchEngine = "BrowserPreferences.searchEngine"
        static let customSearchTemplate = "BrowserPreferences.customSearchTemplate"
        static let jitEnabled = "BrowserPreferences.jitEnabled"
        static let useAndroidUserAgent = "BrowserPreferences.useAndroidUserAgent"
    }
    
    static let shared = BrowserPreferences()
    
    private let defaults: UserDefaults
    private let fileManager: FileManager
    
    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
        registerDefaults()
    }
    
    var searchEngine: SearchEngine {
        get {
            let rawValue = defaults.string(forKey: Keys.searchEngine) ?? SearchEngine.google.rawValue
            return SearchEngine(rawValue: rawValue) ?? .google
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.searchEngine)
        }
    }
    
    var customSearchTemplate: String {
        get { defaults.string(forKey: Keys.customSearchTemplate) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.customSearchTemplate) }
    }
    
    var isCustomSearchTemplateValid: Bool {
        isValidCustomSearchTemplate(customSearchTemplate)
    }
    
    var hasPairingFile: Bool {
        fileManager.fileExists(atPath: pairingFileURL.path)
    }
    
    var isJITEnabled: Bool {
        get {
            guard hasPairingFile else {
                return false
            }
            return defaults.bool(forKey: Keys.jitEnabled)
        }
        set {
            defaults.set(hasPairingFile && newValue, forKey: Keys.jitEnabled)
        }
    }
    
    var useAndroidUserAgent: Bool {
        get { defaults.object(forKey: Keys.useAndroidUserAgent) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.useAndroidUserAgent) }
    }
    
    var androidUserAgentOverride: String? {
        guard useAndroidUserAgent else {
            return nil
        }
        
        return "Mozilla/5.0 (Android 15; Mobile; rv:149.0) Gecko/149.0 Firefox/149.0"
    }
    
    var pairingFileURL: URL {
        documentsDirectory.appendingPathComponent("pairingFile.plist", isDirectory: false)
    }
    
    var searchEngineSummary: String {
        searchEngine.displayName
    }
    
    func searchURL(for query: String) -> String {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let template: String
        switch searchEngine {
        case .custom where isCustomSearchTemplateValid:
            template = customSearchTemplate
        case let engine:
            template = engine.searchTemplate ?? SearchEngine.google.searchTemplate!
        }
        
        return template.replacingOccurrences(of: "%s", with: encodedQuery)
    }
    
    func isValidCustomSearchTemplate(_ value: String) -> Bool {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.contains("%s") else {
            return false
        }
        
        let candidate = trimmedValue.replacingOccurrences(of: "%s", with: "reynard")
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty else {
            return false
        }
        
        return true
    }
    
    func installPairingFile(from sourceURL: URL) throws {
        let destinationURL = pairingFileURL
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        let normalizedSourceURL = sourceURL.standardizedFileURL
        let normalizedDestinationURL = destinationURL.standardizedFileURL
        
        guard normalizedSourceURL != normalizedDestinationURL else {
            isJITEnabled = false
            return
        }
        
        if fileManager.fileExists(atPath: normalizedDestinationURL.path) {
            try fileManager.removeItem(at: normalizedDestinationURL)
        }
        
        try fileManager.copyItem(at: normalizedSourceURL, to: normalizedDestinationURL)
        isJITEnabled = false
    }
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.searchEngine: SearchEngine.google.rawValue,
            Keys.customSearchTemplate: "",
            Keys.jitEnabled: false,
            Keys.useAndroidUserAgent: true,
        ])
    }
}
