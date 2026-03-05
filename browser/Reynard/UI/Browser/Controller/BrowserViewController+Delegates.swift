//
//  BrowserViewController+Delegates.swift
//  Reynard
//
//  Created by Minh Ton on 4/3/26.
//

import GeckoView
import UIKit

extension BrowserViewController: BrowserToolbarViewDelegate {
    func backButtonClicked() {
        tabs[safe: selectedTabIndex]?.session.goBack()
    }
    
    func forwardButtonClicked() {
        tabs[safe: selectedTabIndex]?.session.goForward()
    }
    
    func shareButtonClicked() {
        presentShareSheet()
    }
    
    func menuButtonClicked() {
        presentMenuSheet()
    }
    
    func tabsButtonClicked() {
        setTabOverviewVisible(true, animated: true)
    }
}

extension BrowserViewController: AddressBarViewDelegate {
    func addressBarDidSubmit(_ searchTerm: String) {
        browse(to: searchTerm)
        view.endEditing(true)
    }
    
    func addressBarDidBeginEditing(_ addressBar: AddressBarView) {
        setSearchFocused(true, animated: true)
    }
    
    func addressBarDidEndEditing(_ addressBar: AddressBarView) {
        if !browserUI.phoneAddressBar.isEditingText, !browserUI.padAddressBar.isEditingText {
            setSearchFocused(false, animated: true)
        }
    }
}

extension BrowserViewController: ContentDelegate {
    func onTitleChange(session: GeckoSession, title: String) {
        guard let index = tabIndex(for: session) else {
            return
        }
        tabs[index].title = title.isEmpty ? "Homepage" : title
        browserUI.padTabStripCollectionView.reloadData()
        browserUI.tabOverviewCollectionView.reloadData()
    }
    
    func onPreviewImage(session: GeckoSession, previewImageUrl: String) {}
    
    func onFocusRequest(session: GeckoSession) {}
    
    func onCloseRequest(session: GeckoSession) {
        guard let index = tabIndex(for: session) else {
            return
        }
        closeTab(at: index)
    }
    
    func onFullScreen(session: GeckoSession, fullScreen: Bool) {}
    
    func onMetaViewportFitChange(session: GeckoSession, viewportFit: String) {}
    
    func onProductUrl(session: GeckoSession) {}
    
    func onContextMenu(session: GeckoSession, screenX: Int, screenY: Int, element: ContextElement) {}
    
    func onCrash(session: GeckoSession) {
        if let index = tabIndex(for: session) {
            closeTab(at: index)
        }
    }
    
    func onKill(session: GeckoSession) {
        if let index = tabIndex(for: session) {
            closeTab(at: index)
        }
    }
    
    func onFirstComposite(session: GeckoSession) {}
    
    func onFirstContentfulPaint(session: GeckoSession) {}
    
    func onPaintStatusReset(session: GeckoSession) {}
    
    func onWebAppManifest(session: GeckoSession, manifest: Any) {}
    
    func onSlowScript(session: GeckoSession, scriptFileName: String) async -> SlowScriptResponse {
        .halt
    }
    
    func onShowDynamicToolbar(session: GeckoSession) {}
    
    func onCookieBannerDetected(session: GeckoSession) {}
    
    func onCookieBannerHandled(session: GeckoSession) {}
}

extension BrowserViewController: NavigationDelegate {
    func onLocationChange(session: GeckoSession, url: String?, permissions: [ContentPermission]) {
        guard let index = tabIndex(for: session) else {
            return
        }
        
        let normalizedURL = url?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if tabs[index].suppressInitialNavigation,
           let normalizedURL,
           normalizedURL.hasPrefix("about:blank") {
            return
        }
        
        if let normalizedURL, !normalizedURL.isEmpty {
            tabs[index].suppressInitialNavigation = false
        }
        
        tabs[index].url = url
        
        if index == selectedTabIndex, !browserUI.phoneAddressBar.isEditingText, !browserUI.padAddressBar.isEditingText {
            browserUI.phoneAddressBar.setText(url)
            browserUI.padAddressBar.setText(url)
        }
        
        if index == selectedTabIndex {
            updateNavigationButtons()
        }
    }
    
    func onCanGoBack(session: GeckoSession, canGoBack: Bool) {
        guard let index = tabIndex(for: session) else {
            return
        }
        tabs[index].canGoBack = canGoBack
        if index == selectedTabIndex {
            updateNavigationButtons()
        }
    }
    
    func onCanGoForward(session: GeckoSession, canGoForward: Bool) {
        guard let index = tabIndex(for: session) else {
            return
        }
        tabs[index].canGoForward = canGoForward
        if index == selectedTabIndex {
            updateNavigationButtons()
        }
    }
    
    func onLoadRequest(session: GeckoSession, request: LoadRequest) async -> AllowOrDeny {
        .allow
    }
    
    func onSubframeLoadRequest(session: GeckoSession, request: LoadRequest) async -> AllowOrDeny {
        .allow
    }
    
    func onNewSession(session: GeckoSession, uri: String) async -> GeckoSession? {
        let index = createTab(selecting: true)
        let newSession = tabs[index].session
        tabs[index].url = uri
        browse(to: uri, in: tabs[index])
        return newSession
    }
}

extension BrowserViewController: ProgressDelegate {
    func onPageStart(session: GeckoSession, url: String) {
        guard let index = tabIndex(for: session) else {
            return
        }
        
        tabs[index].isLoading = true
        tabs[index].progress = 0
        
        if index == selectedTabIndex {
            syncAddressBarLoadingState(progress: 0, isLoading: true)
        }
    }
    
    func onPageStop(session: GeckoSession, success: Bool) {
        guard let index = tabIndex(for: session) else {
            return
        }
        
        tabs[index].isLoading = false
        
        if index == selectedTabIndex {
            syncAddressBarLoadingState(progress: tabs[index].progress, isLoading: false)
            captureThumbnail(for: index)
            browserUI.tabOverviewCollectionView.reloadData()
        }
    }
    
    func onProgressChange(session: GeckoSession, progress: Int) {
        guard let index = tabIndex(for: session) else {
            return
        }
        
        let value = Float(progress) / 100
        tabs[index].progress = value
        
        if index == selectedTabIndex {
            syncAddressBarLoadingState(progress: value, isLoading: tabs[index].isLoading)
        }
    }
}

extension BrowserViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        tabs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView === browserUI.tabOverviewCollectionView {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: TabGridCell.reuseIdentifier,
                for: indexPath
            ) as? TabGridCell else {
                return UICollectionViewCell()
            }
            
            let tab = tabs[indexPath.item]
            cell.configure(tab: tab)
            cell.onClose = { [weak self] in
                self?.closeTab(at: indexPath.item)
            }
            return cell
        }
        
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TabStripCell.reuseIdentifier,
            for: indexPath
        ) as? TabStripCell else {
            return UICollectionViewCell()
        }
        
        let tab = tabs[indexPath.item]
        cell.configure(title: tab.title, selected: indexPath.item == selectedTabIndex)
        cell.onClose = { [weak self] in
            self?.closeTab(at: indexPath.item)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView === browserUI.tabOverviewCollectionView {
            // Defer actual session switch until overview dismissal completes
            tabOverviewDismissTargetIndex = indexPath.item
            pendingTabSelectionFromOverview = indexPath.item == selectedTabIndex ? nil : indexPath.item
            if let cell = collectionView.cellForItem(at: indexPath) as? TabGridCell {
                pendingOverviewPreviewImage = cell.currentPreviewImage
            } else {
                pendingOverviewPreviewImage = tabs[safe: indexPath.item]?.thumbnail
            }
            browserUI.tabOverviewCollectionView.reloadData()
            setTabOverviewVisible(false, animated: true)
            return
        }
        
        selectTab(at: indexPath.item, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard collectionView === browserUI.tabOverviewCollectionView,
              let tabCell = cell as? TabGridCell else {
            return
        }
        tabCell.setNeedsLayout()
        tabCell.layoutIfNeeded()
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        if collectionView === browserUI.tabOverviewCollectionView {
            return tabOverviewItemSize(for: collectionView)
        }
        
        if collectionView === browserUI.padTabStripCollectionView {
            let minTabWidth: CGFloat = 220
            let horizontalInsets = collectionView.adjustedContentInset.left + collectionView.adjustedContentInset.right
            let baseWidth = collectionView.bounds.width > 1 ? collectionView.bounds.width : view.bounds.width
            let availableWidth = max(0, baseWidth - horizontalInsets)
            let tabCount = max(1, tabs.count)
            let equalWidth = floor(availableWidth / CGFloat(tabCount))
            let itemWidth = max(minTabWidth, equalWidth)
            return CGSize(width: itemWidth, height: collectionView.bounds.height)
        }
        
        let title = tabs[indexPath.item].title
        let width = max(120, min(240, (title as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 14, weight: .medium)]).width + 52))
        return CGSize(width: width, height: 30)
    }
}
