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

func searchQuery(forSearchURL value: String?, preferences: BrowserPreferences = .shared) -> String? {
    guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmedValue.isEmpty,
          let templateComponents = URLComponents(string: resolvedSearchTemplate(for: preferences)),
          let actualComponents = URLComponents(string: trimmedValue),
          templateComponents.scheme?.lowercased() == actualComponents.scheme?.lowercased(),
          templateComponents.host?.lowercased() == actualComponents.host?.lowercased(),
          normalizedPath(templateComponents.path) == normalizedPath(actualComponents.path),
          let templateQueryItem = templateComponents.queryItems?.first(where: { $0.value?.contains("%s") == true }),
          let actualValue = actualComponents.queryItems?.first(where: { $0.name == templateQueryItem.name })?.value else {
        return nil
    }
    
    let fixedTemplateQueryItems = templateComponents.queryItems?.filter { $0.name != templateQueryItem.name } ?? []
    for item in fixedTemplateQueryItems {
        guard let actualItem = actualComponents.queryItems?.first(where: { $0.name == item.name }),
              actualItem.value == item.value else {
            return nil
        }
    }
    
    guard let templateValue = templateQueryItem.value else {
        return normalizedSearchQueryValue(actualValue)
    }
    
    let templateParts = templateValue.components(separatedBy: "%s")
    guard templateParts.count == 2 else {
        return normalizedSearchQueryValue(actualValue)
    }
    
    let prefix = templateParts[0]
    let suffix = templateParts[1]
    guard actualValue.hasPrefix(prefix),
          actualValue.hasSuffix(suffix) else {
        return nil
    }
    
    let startIndex = actualValue.index(actualValue.startIndex, offsetBy: prefix.count)
    let endIndex = actualValue.index(actualValue.endIndex, offsetBy: -suffix.count)
    guard startIndex <= endIndex else {
        return nil
    }
    
    return normalizedSearchQueryValue(String(actualValue[startIndex..<endIndex]))
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

private func normalizedPath(_ value: String) -> String {
    value.isEmpty ? "/" : value
}

private func normalizedSearchQueryValue(_ value: String) -> String {
    value.replacingOccurrences(of: "+", with: " ")
}
