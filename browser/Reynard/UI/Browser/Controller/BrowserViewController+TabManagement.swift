//
//  BrowserViewController+TabManagement.swift
//  Reynard
//
//  Created by Minh Ton on 4/3/26.
//

import GeckoView
import UIKit

extension BrowserViewController {
    func shareableURL(for tab: BrowserTab) -> URL? {
        guard let value = tab.url?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              value.lowercased() != "about:blank",
              let url = URL(string: value),
              let scheme = url.scheme,
              !scheme.isEmpty else {
            return nil
        }
        return url
    }
    
    func createInitialTab() {
        createTab(selecting: true)
    }
    
    func createSession(windowId: String? = nil) -> GeckoSession {
        let session = GeckoSession()
        session.contentDelegate = self
        session.progressDelegate = self
        session.navigationDelegate = self
        session.open(windowId: windowId)
        return session
    }
    
    @discardableResult
    func createTab(selecting: Bool, windowId: String? = nil) -> Int {
        let tab = BrowserTab(session: createSession(windowId: windowId))
        tabs.append(tab)
        
        let index = tabs.count - 1
        if selecting {
            selectTab(at: index, animated: false)
        } else {
            browserUI.padTabStripCollectionView.reloadData()
            browserUI.tabOverviewCollectionView.reloadData()
        }
        
        applyChromeLayout(animated: false)
        
        return index
    }
    
    func selectTab(at index: Int, animated: Bool) {
        guard tabs.indices.contains(index) else {
            return
        }
        
        captureThumbnail(for: selectedTabIndex)
        
        if tabs.indices.contains(selectedTabIndex) {
            tabs[selectedTabIndex].session.setActive(false)
        }
        
        selectedTabIndex = index
        let selectedTab = tabs[index]
        
        browserUI.geckoView.session = selectedTab.session
        selectedTab.session.setActive(true)
        
        syncAddressBarLoadingState(progress: selectedTab.progress, isLoading: selectedTab.isLoading)
        
        if !browserUI.phoneAddressBar.isEditingText && !browserUI.padAddressBar.isEditingText {
            let value = selectedTab.url ?? ""
            browserUI.phoneAddressBar.setText(value)
            browserUI.padAddressBar.setText(value)
        }
        
        updateNavigationButtons()
        
        browserUI.tabOverviewCollectionView.reloadData()
        browserUI.padTabStripCollectionView.reloadData()
        
        if usesPadChromeLayout {
            centerSelectedPadTab(animated: animated)
        }
    }
    
    func closeTab(at index: Int) {
        guard tabs.indices.contains(index) else {
            return
        }
        
        let wasSelected = index == selectedTabIndex
        let removedTab = tabs.remove(at: index)
        removedTab.session.close()
        
        if tabs.isEmpty {
            selectedTabIndex = 0
            createTab(selecting: true)
            return
        }
        
        if index < selectedTabIndex {
            selectedTabIndex -= 1
        }
        
        if wasSelected {
            let fallback = min(index, tabs.count - 1)
            selectTab(at: fallback, animated: false)
        } else {
            updateNavigationButtons()
            browserUI.tabOverviewCollectionView.reloadData()
            browserUI.padTabStripCollectionView.reloadData()
        }
        
        applyChromeLayout(animated: false)
    }
    
    func clearAllTabs() {
        guard !tabs.isEmpty else {
            return
        }
        
        tabs.forEach { $0.session.close() }
        tabs.removeAll(keepingCapacity: true)
        selectedTabIndex = 0
        
        createTab(selecting: true)
        browserUI.tabOverviewCollectionView.reloadData()
        browserUI.padTabStripCollectionView.reloadData()
        applyChromeLayout(animated: false)
    }
    
    func centerSelectedPadTab(animated: Bool) {
        guard usesPadChromeLayout, tabs.indices.contains(selectedTabIndex) else {
            return
        }
        
        let indexPath = IndexPath(item: selectedTabIndex, section: 0)
        browserUI.padTabStripCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
    }
    
    func browse(to term: String) {
        guard tabs.indices.contains(selectedTabIndex) else {
            return
        }
        browse(to: term, in: tabs[selectedTabIndex])
    }
    
    func browse(to term: String, in tab: BrowserTab) {
        let trimmedValue = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return
        }
        
        tab.suppressInitialNavigation = false
        
        let fullRange = NSRange(location: 0, length: (trimmedValue as NSString).length)
        let isURL = isURLLenient.firstMatch(in: trimmedValue, range: fullRange) != nil
        
        if isURL {
            tab.session.load(trimmedValue)
            return
        }
        
        let encodedValue = trimmedValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        tab.session.load("https://www.google.com/search?q=\(encodedValue)")
    }
    
    func tabIndex(for session: GeckoSession) -> Int? {
        tabs.firstIndex(where: { $0.session === session })
    }
    
    func updateNavigationButtons() {
        guard tabs.indices.contains(selectedTabIndex) else {
            return
        }
        
        let tab = tabs[selectedTabIndex]
        browserUI.toolbarView.updateBackButton(canGoBack: tab.canGoBack)
        browserUI.toolbarView.updateForwardButton(canGoForward: tab.canGoForward)
        let shareEnabled = shareableURL(for: tab) != nil
        browserUI.toolbarView.updateShareButton(isEnabled: shareEnabled)
        browserUI.padShareButton.isEnabled = shareEnabled
        browserUI.padBackButton.isEnabled = tab.canGoBack
        browserUI.padForwardButton.isEnabled = tab.canGoForward
    }
    
    func captureThumbnail(for index: Int) {
        guard tabs.indices.contains(index),
              index == selectedTabIndex,
              !browserUI.geckoView.isHidden else {
            return
        }
        
        let bounds = browserUI.geckoView.bounds
        guard bounds.width > 1, bounds.height > 1 else {
            return
        }
        
        browserUI.geckoView.layoutIfNeeded()
        
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { context in
            browserUI.geckoView.layer.render(in: context.cgContext)
        }
        tabs[index].thumbnail = image
    }
    
    func syncAddressBarLoadingState(progress: Float, isLoading: Bool) {
        browserUI.phoneAddressBar.setLoadingProgress(progress, isLoading: isLoading)
        browserUI.padAddressBar.setLoadingProgress(progress, isLoading: isLoading)
    }
}
