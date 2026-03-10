//
//  LibraryTabBar.swift
//  Reynard
//
//  Created by Minh Ton on 9/3/26.
//

import UIKit

enum LibrarySection: Int, CaseIterable {
    case bookmarks
    case history
    case downloads
    case settings
    
    var title: String {
        switch self {
        case .bookmarks:
            return "Bookmarks"
        case .history:
            return "History"
        case .downloads:
            return "Downloads"
        case .settings:
            return "Settings"
        }
    }
    
    var symbolName: String {
        switch self {
        case .bookmarks:
            return "bookmark"
        case .history:
            return "clock"
        case .downloads:
            return "arrow.down.circle"
        case .settings:
            return "gearshape"
        }
    }
    
    var selectedSymbolName: String {
        switch self {
        case .bookmarks:
            return "bookmark.fill"
        case .history:
            return "clock.fill"
        case .downloads:
            return "arrow.down.circle.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
    
    var tabBarItem: UITabBarItem {
        let configuration = UIImage.SymbolConfiguration(pointSize: LibraryBarMetrics.iconSize, weight: .regular)
        let item = UITabBarItem(
            title: title,
            image: UIImage(systemName: symbolName, withConfiguration: configuration),
            selectedImage: UIImage(systemName: selectedSymbolName, withConfiguration: configuration)
        )
        item.tag = rawValue
        return item
    }
}

private enum LibraryBarMetrics {
    static let iconSize: CGFloat = 18
    static let titleFontSize: CGFloat = 10
}

enum LibraryTabBarStyle {
    static func apply(to tabBar: UITabBar) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: LibraryBarMetrics.titleFontSize, weight: .regular),
        ]
        
        configure(itemAppearance: appearance.stackedLayoutAppearance, titleAttributes: titleAttributes)
        configure(itemAppearance: appearance.inlineLayoutAppearance, titleAttributes: titleAttributes)
        configure(itemAppearance: appearance.compactInlineLayoutAppearance, titleAttributes: titleAttributes)
        
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = .label
        tabBar.unselectedItemTintColor = .secondaryLabel
    }
    
    private static func configure(itemAppearance: UITabBarItemAppearance, titleAttributes: [NSAttributedString.Key: Any]) {
        itemAppearance.normal.iconColor = .secondaryLabel
        itemAppearance.normal.titleTextAttributes = titleAttributes.merging([.foregroundColor: UIColor.secondaryLabel]) { _, new in new }
        itemAppearance.selected.iconColor = .label
        itemAppearance.selected.titleTextAttributes = titleAttributes.merging([.foregroundColor: UIColor.label]) { _, new in new }
    }
}
