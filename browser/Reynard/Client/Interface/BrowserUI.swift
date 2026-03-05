//
//  BrowserUI.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import GeckoView
import UIKit

final class BrowserUI {
    typealias TabCollectionHandler = UICollectionViewDataSource & UICollectionViewDelegate & UICollectionViewDelegateFlowLayout
    
    let geckoView: GeckoView = {
        let view = GeckoView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let chromeContainer = ChromeContainer()
    
    let addressBar: AddressBar = {
        let bar = AddressBar()
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()
    
    let keyboardDismissButton = KeyboardDismissButton()
    
    let toolbarView: PhoneToolbar = {
        let bar = PhoneToolbar()
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()
    
    let topBar = PadTopBar()
    let padTopBarButtons: PadTopBarButtons
    let padTabBar: PadTabBar
    
    let tabOverview = TabOverview()
    let tabOverviewCollection: TabOverviewCollection
    let tabOverviewBottomBar = TabOverviewBottomBar()
    let tabOverviewTopBar = TabOverviewTopBar()
    let tabOverviewBarButtons: TabOverviewBarButtons
    
    var geckoTopPhoneConstraint: NSLayoutConstraint!
    var geckoTopPadConstraint: NSLayoutConstraint!
    var geckoBottomPhoneConstraint: NSLayoutConstraint!
    var geckoBottomPhoneKeyboardOverlayConstraint: NSLayoutConstraint!
    var geckoBottomPadConstraint: NSLayoutConstraint!
    var geckoLeadingPhoneConstraint: NSLayoutConstraint!
    var geckoTrailingPhoneConstraint: NSLayoutConstraint!
    var geckoLeadingPadConstraint: NSLayoutConstraint!
    var geckoTrailingPadConstraint: NSLayoutConstraint!
    
    var phoneChromeBottomConstraint: NSLayoutConstraint!
    var phoneChromeHeightConstraint: NSLayoutConstraint!
    var phoneToolbarHeightConstraint: NSLayoutConstraint!
    var addressBarPhoneLeadingConstraint: NSLayoutConstraint!
    var addressBarPhoneTrailingFullConstraint: NSLayoutConstraint!
    var addressBarPhoneTrailingFocusedConstraint: NSLayoutConstraint!
    var addressBarPhoneTopConstraint: NSLayoutConstraint!
    var addressBarPhoneHeightConstraint: NSLayoutConstraint!
    var addressBarPadLeadingConstraint: NSLayoutConstraint!
    var addressBarPadTrailingConstraint: NSLayoutConstraint!
    var addressBarPadCenterYConstraint: NSLayoutConstraint!
    var addressBarPadHeightConstraint: NSLayoutConstraint!
    
    private unowned let controller: BrowserViewController
    private let tabCollectionHandler: TabCollectionHandler
    private let overviewInset: CGFloat
    private let overviewSpacing: CGFloat
    
    init(
        controller: BrowserViewController,
        overviewInset: CGFloat,
        overviewSpacing: CGFloat,
        tabCollectionHandler: TabCollectionHandler
    ) {
        self.controller = controller
        self.overviewInset = overviewInset
        self.overviewSpacing = overviewSpacing
        self.tabCollectionHandler = tabCollectionHandler
        
        padTopBarButtons = PadTopBarButtons(controller: controller)
        padTabBar = PadTabBar(tabCollectionHandler: tabCollectionHandler)
        tabOverviewCollection = TabOverviewCollection(
            overviewInset: overviewInset,
            overviewSpacing: overviewSpacing,
            tabCollectionHandler: tabCollectionHandler
        )
        tabOverviewBarButtons = TabOverviewBarButtons(controller: controller)
        
        addressBar.configure(delegate: controller)
        keyboardDismissButton.button.addTarget(controller, action: #selector(BrowserViewController.dismissKeyboardTapped), for: .touchUpInside)
        toolbarView.delegate = controller
    }
}
