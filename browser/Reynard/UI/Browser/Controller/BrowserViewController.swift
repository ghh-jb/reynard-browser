//
//  BrowserViewController.swift
//  Reynard
//
//  Created by Minh Ton on 4/3/26.
//

import GeckoView
import UIKit

final class BrowserViewController: UIViewController {
    enum SearchPanMode {
        case undecided
        case horizontalTabs
        case blocked
    }
    
    let overviewInset: CGFloat = 16
    let overviewSpacing: CGFloat = 16
    
    lazy var browserUI = BrowserViewHierarchy(
        controller: self,
        overviewInset: overviewInset,
        overviewSpacing: overviewSpacing
    )
    
    var tabs: [BrowserTab] = []
    var selectedTabIndex = 0
    
    var isTabOverviewVisible = false
    var isSearchFocused = false
    var keyboardHeight: CGFloat = 0
    var currentOverviewProgress: CGFloat = 0
    var tabOverviewDismissTargetIndex: Int?
    var pendingTabSelectionFromOverview: Int?
    var pendingOverviewPreviewImage: UIImage?
    
    var searchPanMode: SearchPanMode = .blocked
    
    var horizontalDirection = 0
    var horizontalTargetIndex: Int?
    var horizontalTargetContentView: UIView?
    var horizontalTargetBarView: UIView?
    var isOverviewMorphTransitionRunning = false
    
    lazy var isURLLenient: NSRegularExpression = {
        let pattern = "^\\s*(\\w+-+)*[\\w\\[]+(://[/]*|:|\\.)(\\w+-+)*[\\w\\[:]+([\\S&&[^\\w-]]\\S*)?\\s*$"
        return try! NSRegularExpression(pattern: pattern)
    }()
    
    var isPadLayout: Bool {
        traitCollection.userInterfaceIdiom == .pad
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
    
    var activeAddressBar: AddressBarView {
        usesPadChromeLayout ? browserUI.padAddressBar : browserUI.phoneAddressBar
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        configureLayout()
        configureGestures()
        observeKeyboard()
        
        createInitialTab()
        applyChromeLayout(animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyChromeLayout(animated: false)
        browserUI.tabOverviewCollectionView.collectionViewLayout.invalidateLayout()
        browserUI.padTabStripCollectionView.collectionViewLayout.invalidateLayout()
        refreshTabOverviewForCurrentOrientation()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { _ in
            self.applyChromeLayout(animated: false)
            self.browserUI.tabOverviewCollectionView.collectionViewLayout.invalidateLayout()
            self.browserUI.padTabStripCollectionView.collectionViewLayout.invalidateLayout()
        } completion: { _ in
            self.browserUI.geckoView.transform = .identity
            self.cleanupHorizontalTransition()
            self.applyChromeLayout(animated: false)
            self.refreshTabOverviewForCurrentOrientation()
            self.view.layoutIfNeeded()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
