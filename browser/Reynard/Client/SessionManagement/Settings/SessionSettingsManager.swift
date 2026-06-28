//
//  SessionSettingsManager.swift
//  Reynard
//
//  Created by Minh Ton on 28/6/26.
//

import Foundation
import GeckoView

final class SessionSettingsManager {
    let websiteMode: WebsiteModeSettingManager
    let pageZoom: PageZoomSettingManager
    
    init(
        websiteMode: WebsiteModeSettingManager = WebsiteModeSettingManager(),
        pageZoom: PageZoomSettingManager = PageZoomSettingManager()
    ) {
        self.websiteMode = websiteMode
        self.pageZoom = pageZoom
    }
    
    func settings(for url: String?, tabID: UUID?) -> GeckoSessionSettings {
        guard let url else {
            return .default
        }
        
        return GeckoSessionSettings(
            websiteMode: websiteMode.setting(for: url, tabID: tabID),
            pageZoom: pageZoom.setting(for: url)
        )
    }
    
    func needsUpdate(
        for session: GeckoSession,
        currentURL: String?,
        requestedURL: String,
        tabID: UUID
    ) -> Bool {
        guard let currentURL,
              let currentHost = DomainMatcher.host(from: currentURL),
              let requestedHost = DomainMatcher.host(from: requestedURL),
              currentHost != requestedHost else {
            return false
        }
        return session.settings != settings(for: requestedURL, tabID: tabID)
    }
}
