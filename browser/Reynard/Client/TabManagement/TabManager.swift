//
//  TabManager.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import Foundation
import GeckoView
import UIKit

protocol TabManager: AnyObject {
    var tabs: [Tab] { get }
    var selectedTabIndex: Int { get }
    var selectedTab: Tab? { get }
    
    func createInitialTab()
    @discardableResult
    func addTab(selecting: Bool, windowId: String?, at index: Int?) -> Int
    @discardableResult
    func addTab(using session: GeckoSession, url: String, title: String?, selecting: Bool, at index: Int?) -> Int
    func selectTab(at index: Int)
    func moveTab(from sourceIndex: Int, to destinationIndex: Int)
    func removeTab(at index: Int)
    func removeAllTabs()
    func browse(to term: String)
    func browse(to term: String, in tab: Tab)
    func replaceSession(with session: GeckoSession, url: String, title: String?)
    func tabIndex(for session: GeckoSession) -> Int?
    func shareableURL(for tab: Tab) -> URL?
    func updateThumbnail(_ image: UIImage?, forTabAt index: Int)
}

enum TabManagerUpdateReason {
    case title
    case location
    case favicon
    case navigationState
    case loading
    case thumbnail
}

protocol TabManagerDelegate: AnyObject {
    func tabManagerDidChangeTabs(_ tabManager: TabManager)
    func tabManager(_ tabManager: TabManager, didSelectTabAt index: Int, previousIndex: Int?)
    func tabManager(_ tabManager: TabManager, didUpdateTabAt index: Int, reason: TabManagerUpdateReason)
    func tabManager(_ tabManager: TabManager, didChangeFullscreen fullScreen: Bool, for session: GeckoSession)
    func tabManager(_ tabManager: TabManager, animateNewTabSelectionAt index: Int, completion: @escaping () -> Void)
    func tabManager(_ tabManager: TabManager, didRequestDownload download: DownloadStore.PendingDownload)
    func tabManager(_ tabManager: TabManager, shouldHandleExternalResponse response: ExternalResponseInfo, for session: GeckoSession) -> Bool
    func tabManager(_ tabManager: TabManager, didRequestContextMenuAt point: CGPoint, for element: ContextElement, in session: GeckoSession)
}

extension TabManagerDelegate {
    func tabManager(_ tabManager: TabManager, didChangeFullscreen fullScreen: Bool, for session: GeckoSession) {}
    func tabManager(_ tabManager: TabManager, animateNewTabSelectionAt index: Int, completion: @escaping () -> Void) {
        completion()
    }
    func tabManager(_ tabManager: TabManager, shouldHandleExternalResponse response: ExternalResponseInfo, for session: GeckoSession) -> Bool {
        false
    }
    func tabManager(_ tabManager: TabManager, didRequestContextMenuAt point: CGPoint, for element: ContextElement, in session: GeckoSession) {}
}
