//
//  GeckoSessionSettings.swift
//  Reynard
//
//  Created by Minh Ton on 28/6/26.
//

import UIKit

public struct WebsiteModeSetting: Equatable {
    public static let mobile = WebsiteModeSetting(
        userAgentOverride: nil,
        userAgentMode: 0,
        viewportMode: 0
    )
    
    public let userAgentOverride: String?
    public let userAgentMode: Int
    public let viewportMode: Int
    
    public init(userAgentOverride: String?, userAgentMode: Int, viewportMode: Int) {
        self.userAgentOverride = userAgentOverride
        self.userAgentMode = userAgentMode
        self.viewportMode = viewportMode
    }
}

public struct PageZoomSetting: Equatable {
    public static let `default` = PageZoomSetting(level: 100)
    
    public let level: Int
    
    public var scale: CGFloat {
        return CGFloat(level) / 100
    }
    
    public init(level: Int) {
        self.level = level
    }
}

public struct GeckoSessionSettings: Equatable {
    public static let `default` = GeckoSessionSettings(
        websiteMode: .mobile,
        pageZoom: .default
    )
    
    public let websiteMode: WebsiteModeSetting
    public let pageZoom: PageZoomSetting
    
    public init(
        websiteMode: WebsiteModeSetting,
        pageZoom: PageZoomSetting
    ) {
        self.websiteMode = websiteMode
        self.pageZoom = pageZoom
    }
}
