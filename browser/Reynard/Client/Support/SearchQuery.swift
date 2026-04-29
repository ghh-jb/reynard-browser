//
//  SearchQuery.swift
//  Reynard
//
//  Created by Minh Ton on 28/4/26.
//

import Foundation

func searchURL(for query: String, preferences: BrowserPreferences = .shared) -> String {
    let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    return resolvedSearchTemplate(for: preferences).replacingOccurrences(of: "%s", with: encodedQuery)
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

private func resolvedSearchTemplate(for preferences: BrowserPreferences) -> String {
    switch preferences.searchEngine {
    case .custom where isValidCustomSearchTemplate(preferences.customSearchTemplate):
        return preferences.customSearchTemplate
    case let engine:
        return engine.searchTemplate ?? BrowserPreferences.SearchEngine.google.searchTemplate!
    }
}
