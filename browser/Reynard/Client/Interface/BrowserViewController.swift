//
//  BrowserViewController.swift
//  Reynard
//
//  Created by Minh Ton on 4/3/26.
//

import GeckoView
import UIKit

final class BrowserViewController: UIViewController, AddressBarDelegate, PhoneToolbarDelegate, TabManagerDelegate {
    let overviewInset: CGFloat = 16
    let overviewSpacing: CGFloat = 16
    
    lazy var tabCollectionCoordinator = TabCollectionCoordinator(controller: self)
    
    lazy var browserUI = BrowserUI(
        controller: self,
        overviewInset: overviewInset,
        overviewSpacing: overviewSpacing,
        tabCollectionHandler: tabCollectionCoordinator
    )
    
    lazy var tabManager: TabManager = TabManagerImplementation(delegate: self)
    lazy var browserActions = BrowserActions(controller: self)
    lazy var browserLayout = BrowserLayout(controller: self)
    lazy var addressBarGestures = AddressBarGestures(controller: self)
    lazy var tabOverviewPresentation = TabOverviewPresentation(controller: self)
    
    var isSearchFocused = false
    private var pendingSelectionAnimation = false
    
    var isPadLayout: Bool {
        traitCollection.userInterfaceIdiom == .pad
    }

    var usesCompactPadChromeMode: Bool {
        isPadLayout && traitCollection.horizontalSizeClass == .compact
    }
    
    var usesPadChromeLayout: Bool {
        if isPadLayout {
            return true
        }
        
        // Also use the pad layout in iPhone landscape mode
        if let orientation = view.window?.windowScene?.interfaceOrientation {
            return orientation.isLandscape
        }
        
        return view.bounds.width > view.bounds.height
    }
    
    var activeAddressBar: AddressBar {
        browserUI.addressBar
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        browserLayout.configureLayout()
        addressBarGestures.configureGestures()
        browserLayout.observeKeyboard()
        
        tabManager.createInitialTab()
        browserLayout.applyChromeLayout(animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        browserLayout.applyChromeLayout(animated: false)
        browserUI.tabOverviewCollection.collectionView.collectionViewLayout.invalidateLayout()
        browserUI.padTabBar.collectionView.collectionViewLayout.invalidateLayout()
        tabOverviewPresentation.refreshForCurrentOrientation()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { _ in
            self.browserLayout.applyChromeLayout(animated: false)
            self.browserUI.tabOverviewCollection.collectionView.collectionViewLayout.invalidateLayout()
            self.browserUI.padTabBar.collectionView.collectionViewLayout.invalidateLayout()
        } completion: { _ in
            self.browserUI.geckoView.transform = .identity
            self.addressBarGestures.resetHorizontalTransition()
            self.browserLayout.applyChromeLayout(animated: false)
            self.tabOverviewPresentation.refreshForCurrentOrientation()
            self.view.layoutIfNeeded()
        }
    }
    
    @discardableResult
    func createTab(selecting: Bool, windowId: String? = nil) -> Int {
        tabManager.addTab(selecting: selecting, windowId: windowId)
    }
    
    func selectTab(at index: Int, animated: Bool) {
        pendingSelectionAnimation = animated
        tabManager.selectTab(at: index)
    }
    
    func closeTab(at index: Int) {
        tabManager.removeTab(at: index)
    }
    
    func clearAllTabs() {
        tabManager.removeAllTabs()
    }
    
    func setTabOverviewVisible(_ visible: Bool, animated: Bool) {
        tabOverviewPresentation.setVisible(visible, animated: animated)
    }
    
    func setSearchFocused(_ focused: Bool, animated: Bool) {
        browserLayout.setSearchFocused(focused, animated: animated)
    }
    
    func applyChromeLayout(animated: Bool) {
        browserLayout.applyChromeLayout(animated: animated)
    }
    
    func centerSelectedPadTab(animated: Bool) {
        guard usesPadChromeLayout, tabManager.tabs.indices.contains(tabManager.selectedTabIndex) else {
            return
        }
        
        let indexPath = IndexPath(item: tabManager.selectedTabIndex, section: 0)
        browserUI.padTabBar.collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
    }
    
    func browse(to term: String) {
        tabManager.browse(to: term)
    }
    
    func updateNavigationButtons() {
        guard let tab = tabManager.selectedTab else {
            return
        }
        
        browserUI.toolbarView.updateBackButton(canGoBack: tab.canGoBack)
        browserUI.toolbarView.updateForwardButton(canGoForward: tab.canGoForward)
        let shareEnabled = tabManager.shareableURL(for: tab) != nil
        browserUI.toolbarView.updateShareButton(isEnabled: shareEnabled)
        browserUI.padTopBarButtons.shareButton.isEnabled = shareEnabled
        browserUI.padTopBarButtons.backButton.isEnabled = tab.canGoBack
        browserUI.padTopBarButtons.forwardButton.isEnabled = tab.canGoForward
    }
    
    func captureThumbnail(for index: Int) {
        guard tabManager.tabs.indices.contains(index),
              index == tabManager.selectedTabIndex,
              !browserUI.geckoView.isHidden else {
            return
        }
        
        guard let tab = tabManager.tabs[safe: index] else {
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
        tab.thumbnail = image
    }
    
    func syncAddressBarLoadingState(progress: Float, isLoading: Bool) {
        browserUI.addressBar.setLoadingProgress(progress, isLoading: isLoading)
    }
    
    func tabManagerDidChangeTabs(_ tabManager: TabManager) {
        if let selectedTab = tabManager.selectedTab {
            if browserUI.geckoView.session !== selectedTab.session {
                browserUI.geckoView.session = selectedTab.session
            }
        } else {
            browserUI.geckoView.session = nil
        }
        
        browserUI.tabOverviewCollection.collectionView.reloadData()
        browserUI.padTabBar.collectionView.reloadData()
        browserLayout.applyChromeLayout(animated: false)
    }
    
    func tabManager(_ tabManager: TabManager, didSelectTabAt index: Int, previousIndex: Int?) {
        if let previousIndex {
            captureThumbnail(for: previousIndex)
        }
        
        guard tabManager.tabs.indices.contains(index) else {
            return
        }
        
        let selectedTab = tabManager.tabs[index]
        browserUI.geckoView.session = selectedTab.session
        
        syncAddressBarLoadingState(progress: selectedTab.progress, isLoading: selectedTab.isLoading)
        
        if !browserUI.addressBar.isEditingText {
            let value = selectedTab.url ?? ""
            browserUI.addressBar.setText(value)
        }
        
        updateNavigationButtons()
        browserUI.tabOverviewCollection.collectionView.reloadData()
        browserUI.padTabBar.collectionView.reloadData()
        
        if usesPadChromeLayout {
            centerSelectedPadTab(animated: pendingSelectionAnimation)
        }
        pendingSelectionAnimation = false
    }
    
    func tabManager(_ tabManager: TabManager, didUpdateTabAt index: Int, reason: TabManagerUpdateReason) {
        guard tabManager.tabs.indices.contains(index) else {
            return
        }
        
        switch reason {
        case .title:
            browserUI.padTabBar.collectionView.reloadData()
            browserUI.tabOverviewCollection.collectionView.reloadData()
            
        case .location:
            if index == tabManager.selectedTabIndex,
               !browserUI.addressBar.isEditingText {
                browserUI.addressBar.setText(tabManager.tabs[index].url)
            }
            if index == tabManager.selectedTabIndex {
                updateNavigationButtons()
            }
            
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
    
    func backButtonClicked() {
        browserActions.goBack()
    }
    
    func forwardButtonClicked() {
        browserActions.goForward()
    }
    
    func shareButtonClicked() {
        browserActions.presentShareSheet()
    }
    
    func menuButtonClicked() {
        browserActions.presentMenuSheet()
    }
    
    func tabsButtonClicked() {
        browserActions.showTabOverview()
    }
    
    func addressBarDidSubmit(_ searchTerm: String) {
        browse(to: searchTerm)
        view.endEditing(true)
    }
    
    func addressBarDidBeginEditing(_ addressBar: AddressBar) {
        setSearchFocused(true, animated: true)
    }
    
    func addressBarDidEndEditing(_ addressBar: AddressBar) {
        if !browserUI.addressBar.isEditingText {
            setSearchFocused(false, animated: true)
        }
    }
    
    @objc func tabsTapped() {
        browserActions.showTabOverview()
    }
    
    @objc func doneTapped() {
        browserActions.hideTabOverview()
    }
    
    @objc func newTabTapped() {
        browserActions.createNewTab()
    }
    
    @objc func clearAllTabsTapped() {
        browserActions.clearAllTabs()
    }
    
    @objc func shareTapped() {
        browserActions.presentShareSheet()
    }
    
    @objc func padBackTapped() {
        browserActions.goBack()
    }
    
    @objc func padForwardTapped() {
        browserActions.goForward()
    }
    
    @objc func dismissKeyboardTapped() {
        browserActions.dismissKeyboard()
    }
}
