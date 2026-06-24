//
//  HomepageSection.swift
//  Reynard
//
//  Created by Minh Ton on 21/6/26.
//

enum HomepageRecommendation: CaseIterable, Hashable {
    case performance
    case donation
}

enum HomepageSection: CaseIterable, Hashable {
    case recommendation(HomepageRecommendation)
    case privateBrowsing
    case favorites
    case frequentlyVisited
    
    static var allCases: [HomepageSection] {
        return HomepageRecommendation.allCases.map { .recommendation($0) } + [
            .privateBrowsing,
            .favorites,
            .frequentlyVisited,
        ]
    }
}
