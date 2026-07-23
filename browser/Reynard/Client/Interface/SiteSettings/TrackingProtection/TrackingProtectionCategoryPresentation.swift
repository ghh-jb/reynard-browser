//
//  TrackingProtectionCategoryPresentation.swift
//  Reynard
//
//  Created by Minh Ton on 23/7/26.
//

import GeckoView

extension BlockedTrackerCategory {
    var title: String {
        switch self {
        case .crossSiteTrackingCookies:
            return NSLocalizedString("Cross-Site Tracking Cookies", comment: "")
        case .cryptominers:
            return NSLocalizedString("Cryptominers", comment: "")
        case .fingerprinters:
            return NSLocalizedString("Fingerprinters", comment: "")
        case .socialMediaTrackers:
            return NSLocalizedString("Social Media Trackers", comment: "")
        case .trackingContent:
            return NSLocalizedString("Tracking Content", comment: "")
        }
    }
    
    var description: String {
        switch self {
        case .crossSiteTrackingCookies:
            return NSLocalizedString("Total Cookie Protection isolates cookies to the website you’re on so trackers like ad networks can’t use them to follow you across websites.", comment: "")
        case .cryptominers:
            return NSLocalizedString("Prevents malicious scripts gaining access to your device to mine digital currency.", comment: "")
        case .fingerprinters:
            return NSLocalizedString("Stops uniquely identifiable data from being collected about your device that can be used for tracking purposes.", comment: "")
        case .socialMediaTrackers:
            return NSLocalizedString("Limits the ability of social networks to track your browsing activity around the web.", comment: "")
        case .trackingContent:
            return NSLocalizedString("Stops outside ads, videos, and other content from loading that contains tracking code. May affect some website functionality.", comment: "")
        }
    }
}
