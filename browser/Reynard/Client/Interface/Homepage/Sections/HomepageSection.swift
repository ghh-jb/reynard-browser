//
//  HomepageSection.swift
//  Reynard
//
//  Created by Minh Ton on 21/6/26.
//

import UIKit

enum HomepageRecommendation: CaseIterable, Hashable {
    case performance
    case donation
}

enum HomepageSection: CaseIterable, Hashable {
    case recommendation(HomepageRecommendation)
    case privateBrowsing
    case favorites
    case frequentlyVisited
    case recentlyClosedTabs
    
    static var allCases: [HomepageSection] {
        return HomepageRecommendation.allCases.map { .recommendation($0) } + [
            .privateBrowsing,
            .favorites,
            .frequentlyVisited,
            .recentlyClosedTabs,
        ]
    }
}

protocol HomepageSectionDelegate: AnyObject {
    func homepageSection(_ viewController: UIViewController, didSelectURL url: URL)
    func homepageSection(_ viewController: UIViewController, didSelectRecentlyClosedTab id: UUID)
    func homepageSectionDidChangeLayout(_ viewController: UIViewController)
    func homepageSectionDidSelectSettings(_ viewController: UIViewController)
}
