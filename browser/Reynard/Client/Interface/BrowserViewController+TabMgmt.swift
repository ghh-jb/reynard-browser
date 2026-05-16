//
//  BrowserViewController+TabMgmt.swift
//  Reynard
//
//  Created by Minh Ton on 15/5/26.
//

import GeckoView
import ObjectiveC
import UIKit

private enum TabMgmtAssociatedKeys {
    static var pendingSelectionAnimation = 0
    static var pendingExpandedTabBarIndex = 0
    static var activeFullscreenSession = 0
    static var tabOverviewPresentation = 0
}

private final class WeakSessionBox {
    weak var value: GeckoSession?
    
    init(_ value: GeckoSession?) {
        self.value = value
    }
}

extension BrowserViewController {
    var tabOverviewPresentation: TabOverviewPresentation {
        get {
            if let presentation = objc_getAssociatedObject(self, &TabMgmtAssociatedKeys.tabOverviewPresentation) as? TabOverviewPresentation {
                return presentation
            }
            
            let presentation = TabOverviewPresentation(controller: self)
            objc_setAssociatedObject(self, &TabMgmtAssociatedKeys.tabOverviewPresentation, presentation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return presentation
        }
        set {
            objc_setAssociatedObject(self, &TabMgmtAssociatedKeys.tabOverviewPresentation, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var pendingSelectionAnimation: Bool {
        get {
            (objc_getAssociatedObject(self, &TabMgmtAssociatedKeys.pendingSelectionAnimation) as? NSNumber)?.boolValue ?? false
        }
        set {
            objc_setAssociatedObject(
                self,
                &TabMgmtAssociatedKeys.pendingSelectionAnimation,
                NSNumber(value: newValue),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    var pendingExpandedTabBarIndex: Int? {
        get {
            (objc_getAssociatedObject(self, &TabMgmtAssociatedKeys.pendingExpandedTabBarIndex) as? NSNumber)?.intValue
        }
        set {
            let boxedValue = newValue.map { NSNumber(value: $0) }
            objc_setAssociatedObject(
                self,
                &TabMgmtAssociatedKeys.pendingExpandedTabBarIndex,
                boxedValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    var activeFullscreenSession: GeckoSession? {
        get {
            (objc_getAssociatedObject(self, &TabMgmtAssociatedKeys.activeFullscreenSession) as? WeakSessionBox)?.value
        }
        set {
            objc_setAssociatedObject(
                self,
                &TabMgmtAssociatedKeys.activeFullscreenSession,
                WeakSessionBox(newValue),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
}

extension BrowserViewController: TabManagerDelegate {
    func tabManagerDidChangeTabs(_ tabManager: TabManager) {
        if let pendingExpandedTabBarIndex,
           !tabManager.tabs.indices.contains(pendingExpandedTabBarIndex) {
            self.pendingExpandedTabBarIndex = nil
        }
        
        if let selectedTab = tabManager.selectedTab {
            if browserUI.geckoView.session !== selectedTab.session {
                browserUI.geckoView.session = selectedTab.session
            }
        } else {
            browserUI.geckoView.session = nil
        }
        refreshAddressBar()
        
        browserUI.tabOverviewCollection.collectionView.reloadData()
        browserUI.tabBar.collectionView.reloadData()
        browserUI.applyChromeLayout(animated: false)
        browserUI.tabBar.refreshLayout(
            fallbackWidth: view.bounds.width,
            tabCount: tabManager.tabs.count,
            selectedIndex: tabManager.selectedTabIndex,
            pendingExpandedIndex: pendingExpandedTabBarIndex
        )
    }
    
    func tabManager(_ tabManager: TabManager, didSelectTabAt index: Int, previousIndex: Int?) {
        pendingExpandedTabBarIndex = nil
        if let previousIndex {
            captureThumbnail(for: previousIndex)
        }
        
        guard tabManager.tabs.indices.contains(index) else {
            return
        }
        
        let selectedTab = tabManager.tabs[index]
        browserUI.geckoView.session = selectedTab.session
        addonsController.handleTabSelectionChange(selectedIndex: index, previousIndex: previousIndex)
        
        syncAddressBarLoadingState(progress: selectedTab.progress, isLoading: selectedTab.isLoading)
        refreshAddressBar()
        
        updateNavigationButtons()
        browserUI.tabOverviewCollection.collectionView.reloadData()
        browserUI.tabBar.collectionView.reloadData()
        browserUI.tabBar.refreshLayout(
            fallbackWidth: view.bounds.width,
            tabCount: tabManager.tabs.count,
            selectedIndex: tabManager.selectedTabIndex,
            pendingExpandedIndex: pendingExpandedTabBarIndex
        )
        
        if usesPadChrome {
            browserUI.tabBar.centerSelectedTab(
                selectedIndex: tabManager.selectedTabIndex,
                isVisible: usesPadChrome && tabManager.tabs.indices.contains(tabManager.selectedTabIndex),
                animated: pendingSelectionAnimation
            )
        }
        
        if isInFullscreenMedia,
           activeFullscreenSession !== selectedTab.session {
            applyFullscreenState(false, for: activeFullscreenSession)
        }
        pendingSelectionAnimation = false
    }
    
    func tabManager(_ tabManager: TabManager, didRequestContextMenuAt point: CGPoint, for element: ContextElement, in session: GeckoSession) {
        guard browserUI.geckoView.session === session else {
            return
        }
        
        if element.type == .image,
           let source = element.srcUri?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: source) {
            presentContextMenu(at: point, target: .image(url))
            return
        }
        
        guard let link = element.linkUri?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: link) else {
            return
        }
        
        presentContextMenu(at: point, target: .link(url))
    }
    
    func tabManager(_ tabManager: TabManager, didChangeFullscreen fullScreen: Bool, for session: GeckoSession) {
        guard tabManager.selectedTab?.session === session else {
            return
        }
        applyFullscreenState(fullScreen, for: session)
    }
    
    func tabManager(_ tabManager: TabManager, didUpdateTabAt index: Int, reason: TabManagerUpdateReason) {
        guard tabManager.tabs.indices.contains(index) else {
            return
        }
        
        switch reason {
        case .title:
            browserUI.tabBar.collectionView.reloadData()
            browserUI.tabOverviewCollection.collectionView.reloadData()
            
        case .location:
            if index == tabManager.selectedTabIndex {
                refreshAddressBar()
                updateNavigationButtons()
            }
            
        case .favicon:
            browserUI.tabBar.collectionView.reloadData()
            browserUI.tabOverviewCollection.collectionView.reloadData()
            
        case .navigationState:
            if index == tabManager.selectedTabIndex {
                updateNavigationButtons()
            }
            
        case .loading:
            if index == tabManager.selectedTabIndex {
                let tab = tabManager.tabs[index]
                syncAddressBarLoadingState(progress: tab.progress, isLoading: tab.isLoading)
            }
            
        case .thumbnail:
            if index == tabManager.selectedTabIndex {
                captureThumbnail(for: index)
            }
            browserUI.tabOverviewCollection.collectionView.reloadData()
        }
    }
    
    func tabManager(_ tabManager: TabManager, animateNewTabSelectionAt index: Int, completion: @escaping () -> Void) {
        guard tabManager.tabs.indices.contains(index) else {
            completion()
            return
        }
        
        addressBarGestures.animateAutomaticNewTabTransition(to: tabManager.tabs[index], completion: completion)
    }
    
    func tabManager(_ tabManager: TabManager, didRequestDownload download: DownloadStore.PendingDownload) {
        DispatchQueue.main.async { [weak self] in
            self?.enqueueDownloadConfirmation(download)
        }
    }
    
    func tabManager(_ tabManager: TabManager, shouldHandleExternalResponse response: ExternalResponseInfo, for session: GeckoSession) -> Bool {
        addonsController.handleExternalResponse(response)
    }
}
