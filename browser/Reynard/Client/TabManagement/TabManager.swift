//
//  TabManager.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import Foundation
import GeckoView

protocol TabManager: AnyObject {
    var tabs: [Tab] { get }
    var selectedTabIndex: Int { get }
    var selectedTab: Tab? { get }
    
    func createInitialTab()
    @discardableResult
    func addTab(selecting: Bool, windowId: String?) -> Int
    func selectTab(at index: Int)
    func removeTab(at index: Int)
    func removeAllTabs()
    func browse(to term: String)
    func browse(to term: String, in tab: Tab)
    func tabIndex(for session: GeckoSession) -> Int?
    func shareableURL(for tab: Tab) -> URL?
}

enum TabManagerUpdateReason {
    case title
    case location
    case navigationState
    case loading
    case thumbnail
}

protocol TabManagerDelegate: AnyObject {
    func tabManagerDidChangeTabs(_ tabManager: TabManager)
    func tabManager(_ tabManager: TabManager, didSelectTabAt index: Int, previousIndex: Int?)
    func tabManager(_ tabManager: TabManager, didUpdateTabAt index: Int, reason: TabManagerUpdateReason)
}
