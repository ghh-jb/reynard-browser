//
//  BrowserLayout.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import UIKit

final class BrowserLayout {
    private unowned let controller: BrowserViewController
    private var keyboardHeight: CGFloat = 0
    
    init(controller: BrowserViewController) {
        self.controller = controller
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func configureLayout() {
        let ui = controller.browserUI
        let view = controller.view!
        
        view.addSubview(ui.chromeContainer.bottomSafeAreaFillView)
        view.addSubview(ui.geckoView)
        view.addSubview(ui.chromeContainer.containerView)
        view.addSubview(ui.topBar.safeAreaFillView)
        view.addSubview(ui.addressBar)
        
        ui.chromeContainer.containerView.addSubview(ui.keyboardDismissButton.button)
        ui.chromeContainer.containerView.addSubview(ui.toolbarView)
        
        view.addSubview(ui.topBar.barView)
        ui.topBar.barView.addSubview(ui.padTopBarButtons.leftStack)
        ui.topBar.barView.addSubview(ui.padTopBarButtons.rightStack)
        
        view.addSubview(ui.padTabBar.collectionView)
        
        view.addSubview(ui.tabOverview.containerView)
        ui.tabOverview.containerView.addSubview(ui.tabOverview.blurView)
        ui.tabOverview.containerView.addSubview(ui.tabOverviewCollection.collectionView)
        ui.tabOverview.containerView.addSubview(ui.tabOverviewBottomBar.safeAreaFillView)
        ui.tabOverview.containerView.addSubview(ui.tabOverviewBottomBar.barView)
        ui.tabOverview.containerView.addSubview(ui.tabOverviewTopBar.barView)
        ui.tabOverviewBarButtons.attach(to: ui.tabOverviewBottomBar.barView)
        
        ui.geckoTopPhoneConstraint = ui.geckoView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ui.geckoTopPadConstraint = ui.geckoView.topAnchor.constraint(equalTo: ui.padTabBar.collectionView.bottomAnchor)
        ui.geckoBottomPhoneConstraint = ui.geckoView.bottomAnchor.constraint(equalTo: ui.chromeContainer.containerView.topAnchor)
        ui.geckoBottomPhoneKeyboardOverlayConstraint = ui.geckoView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ui.geckoBottomPadConstraint = ui.geckoView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ui.geckoLeadingPhoneConstraint = ui.geckoView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ui.geckoTrailingPhoneConstraint = ui.geckoView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ui.geckoLeadingPadConstraint = ui.geckoView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ui.geckoTrailingPadConstraint = ui.geckoView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        
        ui.phoneChromeBottomConstraint = ui.chromeContainer.containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ui.phoneChromeHeightConstraint = ui.chromeContainer.containerView.heightAnchor.constraint(equalToConstant: 94)
        ui.phoneToolbarHeightConstraint = ui.toolbarView.heightAnchor.constraint(equalToConstant: 30)
        
        ui.addressBarPhoneLeadingConstraint = ui.addressBar.leadingAnchor.constraint(equalTo: ui.chromeContainer.containerView.leadingAnchor, constant: 12)
        ui.addressBarPhoneTrailingFullConstraint = ui.addressBar.trailingAnchor.constraint(equalTo: ui.chromeContainer.containerView.trailingAnchor, constant: -12)
        ui.addressBarPhoneTrailingFocusedConstraint = ui.addressBar.trailingAnchor.constraint(equalTo: ui.keyboardDismissButton.button.leadingAnchor, constant: -8)
        ui.addressBarPhoneTopConstraint = ui.addressBar.topAnchor.constraint(equalTo: ui.chromeContainer.containerView.topAnchor, constant: 8)
        ui.addressBarPhoneHeightConstraint = ui.addressBar.heightAnchor.constraint(equalToConstant: 42)
        
        ui.addressBarPadLeadingConstraint = ui.addressBar.leadingAnchor.constraint(equalTo: ui.padTopBarButtons.leftStack.trailingAnchor, constant: 12)
        ui.addressBarPadTrailingConstraint = ui.addressBar.trailingAnchor.constraint(equalTo: ui.padTopBarButtons.rightStack.leadingAnchor, constant: -12)
        ui.addressBarPadCenterYConstraint = ui.addressBar.centerYAnchor.constraint(equalTo: ui.topBar.barView.centerYAnchor)
        ui.addressBarPadHeightConstraint = ui.addressBar.heightAnchor.constraint(equalToConstant: 38)
        
        ui.keyboardDismissButton.trailingConstraint = ui.keyboardDismissButton.button.trailingAnchor.constraint(equalTo: ui.chromeContainer.containerView.trailingAnchor, constant: -12)
        ui.keyboardDismissButton.centerYConstraint = ui.keyboardDismissButton.button.centerYAnchor.constraint(equalTo: ui.addressBar.centerYAnchor)
        ui.keyboardDismissButton.widthConstraint = ui.keyboardDismissButton.button.widthAnchor.constraint(equalToConstant: 42)
        ui.keyboardDismissButton.heightConstraint = ui.keyboardDismissButton.button.heightAnchor.constraint(equalToConstant: 42)
        
        ui.topBar.heightConstraint = ui.topBar.barView.heightAnchor.constraint(equalToConstant: 52)
        
        ui.padTopBarButtons.leftLeadingConstraint = ui.padTopBarButtons.leftStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12)
        ui.padTopBarButtons.rightTrailingConstraint = ui.padTopBarButtons.rightStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12)
        ui.padTopBarButtons.leftWidthConstraint = ui.padTopBarButtons.leftStack.widthAnchor.constraint(equalToConstant: 80)
        ui.padTopBarButtons.rightWidthConstraint = ui.padTopBarButtons.rightStack.widthAnchor.constraint(equalToConstant: 126)
        ui.padTopBarButtons.leftHeightConstraint = ui.padTopBarButtons.leftStack.heightAnchor.constraint(equalToConstant: 30)
        ui.padTopBarButtons.rightHeightConstraint = ui.padTopBarButtons.rightStack.heightAnchor.constraint(equalToConstant: 30)
        
        ui.padTabBar.heightConstraint = ui.padTabBar.collectionView.heightAnchor.constraint(equalToConstant: 36)
        
        ui.tabOverviewCollection.topPhoneConstraint = ui.tabOverviewCollection.collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ui.tabOverviewCollection.bottomPhoneConstraint = ui.tabOverviewCollection.collectionView.bottomAnchor.constraint(equalTo: ui.tabOverviewBottomBar.barView.topAnchor)
        ui.tabOverviewCollection.topPadConstraint = ui.tabOverviewCollection.collectionView.topAnchor.constraint(equalTo: ui.tabOverviewTopBar.barView.bottomAnchor)
        ui.tabOverviewCollection.bottomPadConstraint = ui.tabOverviewCollection.collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        
        ui.tabOverviewBottomBar.bottomConstraint = ui.tabOverviewBottomBar.barView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ui.tabOverviewBottomBar.heightConstraint = ui.tabOverviewBottomBar.barView.heightAnchor.constraint(equalToConstant: 108)
        ui.tabOverviewTopBar.heightConstraint = ui.tabOverviewTopBar.barView.heightAnchor.constraint(equalToConstant: 108)
        
        NSLayoutConstraint.activate([
            ui.geckoLeadingPhoneConstraint,
            ui.geckoTrailingPhoneConstraint,
            ui.geckoTopPhoneConstraint,
            ui.geckoBottomPhoneConstraint,
            
            ui.chromeContainer.containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ui.chromeContainer.containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ui.phoneChromeBottomConstraint,
            ui.phoneChromeHeightConstraint,
            
            ui.chromeContainer.bottomSafeAreaFillView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ui.chromeContainer.bottomSafeAreaFillView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ui.chromeContainer.bottomSafeAreaFillView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            ui.chromeContainer.bottomSafeAreaFillView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            ui.addressBarPhoneLeadingConstraint,
            ui.addressBarPhoneTrailingFullConstraint,
            ui.addressBarPhoneTopConstraint,
            ui.addressBarPhoneHeightConstraint,
            
            ui.keyboardDismissButton.trailingConstraint,
            ui.keyboardDismissButton.centerYConstraint,
            ui.keyboardDismissButton.widthConstraint,
            ui.keyboardDismissButton.heightConstraint,
            
            ui.toolbarView.leadingAnchor.constraint(equalTo: ui.chromeContainer.containerView.leadingAnchor, constant: 24),
            ui.toolbarView.trailingAnchor.constraint(equalTo: ui.chromeContainer.containerView.trailingAnchor, constant: -24),
            ui.toolbarView.topAnchor.constraint(equalTo: ui.addressBar.bottomAnchor, constant: 7),
            ui.phoneToolbarHeightConstraint,
            
            ui.topBar.barView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ui.topBar.barView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ui.topBar.barView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            ui.topBar.heightConstraint,
            
            ui.topBar.safeAreaFillView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ui.topBar.safeAreaFillView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ui.topBar.safeAreaFillView.topAnchor.constraint(equalTo: view.topAnchor),
            ui.topBar.safeAreaFillView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            
            ui.padTopBarButtons.leftLeadingConstraint,
            ui.padTopBarButtons.leftStack.centerYAnchor.constraint(equalTo: ui.topBar.barView.centerYAnchor),
            ui.padTopBarButtons.leftWidthConstraint,
            ui.padTopBarButtons.leftHeightConstraint,
            
            ui.padTopBarButtons.rightTrailingConstraint,
            ui.padTopBarButtons.rightStack.centerYAnchor.constraint(equalTo: ui.topBar.barView.centerYAnchor),
            ui.padTopBarButtons.rightWidthConstraint,
            ui.padTopBarButtons.rightHeightConstraint,
            
            ui.padTabBar.collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ui.padTabBar.collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ui.padTabBar.collectionView.topAnchor.constraint(equalTo: ui.topBar.barView.bottomAnchor),
            ui.padTabBar.heightConstraint,
            
            ui.tabOverview.containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ui.tabOverview.containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ui.tabOverview.containerView.topAnchor.constraint(equalTo: view.topAnchor),
            ui.tabOverview.containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            ui.tabOverview.blurView.leadingAnchor.constraint(equalTo: ui.tabOverview.containerView.leadingAnchor),
            ui.tabOverview.blurView.trailingAnchor.constraint(equalTo: ui.tabOverview.containerView.trailingAnchor),
            ui.tabOverview.blurView.topAnchor.constraint(equalTo: ui.tabOverview.containerView.topAnchor),
            ui.tabOverview.blurView.bottomAnchor.constraint(equalTo: ui.tabOverview.containerView.bottomAnchor),
            
            ui.tabOverviewCollection.collectionView.leadingAnchor.constraint(equalTo: ui.tabOverview.containerView.safeAreaLayoutGuide.leadingAnchor),
            ui.tabOverviewCollection.collectionView.trailingAnchor.constraint(equalTo: ui.tabOverview.containerView.safeAreaLayoutGuide.trailingAnchor),
            ui.tabOverviewCollection.topPhoneConstraint,
            ui.tabOverviewCollection.bottomPhoneConstraint,
            
            ui.tabOverviewBottomBar.barView.leadingAnchor.constraint(equalTo: ui.tabOverview.containerView.leadingAnchor),
            ui.tabOverviewBottomBar.barView.trailingAnchor.constraint(equalTo: ui.tabOverview.containerView.trailingAnchor),
            ui.tabOverviewBottomBar.bottomConstraint,
            ui.tabOverviewBottomBar.heightConstraint,
            
            ui.tabOverviewBottomBar.safeAreaFillView.leadingAnchor.constraint(equalTo: ui.tabOverview.containerView.leadingAnchor),
            ui.tabOverviewBottomBar.safeAreaFillView.trailingAnchor.constraint(equalTo: ui.tabOverview.containerView.trailingAnchor),
            ui.tabOverviewBottomBar.safeAreaFillView.topAnchor.constraint(equalTo: ui.tabOverviewBottomBar.barView.bottomAnchor),
            ui.tabOverviewBottomBar.safeAreaFillView.bottomAnchor.constraint(equalTo: ui.tabOverview.containerView.bottomAnchor),
            
            ui.tabOverviewTopBar.barView.leadingAnchor.constraint(equalTo: ui.tabOverview.containerView.leadingAnchor),
            ui.tabOverviewTopBar.barView.trailingAnchor.constraint(equalTo: ui.tabOverview.containerView.trailingAnchor),
            ui.tabOverviewTopBar.barView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            ui.tabOverviewTopBar.heightConstraint,
        ].compactMap { $0 })
        
        ui.addressBarPadLeadingConstraint.isActive = false
        ui.addressBarPadTrailingConstraint.isActive = false
        ui.addressBarPadCenterYConstraint.isActive = false
        ui.addressBarPadHeightConstraint.isActive = false
        ui.tabOverviewCollection.topPadConstraint.isActive = false
        ui.tabOverviewCollection.bottomPadConstraint.isActive = false
        
        view.sendSubviewToBack(ui.chromeContainer.bottomSafeAreaFillView)
    }
    
    func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    func applyChromeLayout(animated: Bool) {
        let ui = controller.browserUI
        let pad = controller.usesPadChromeLayout
        let shouldShowGeckoBehindKeyboard = !pad
        && controller.isSearchFocused
        && keyboardHeight > 0
        && !controller.tabOverviewPresentation.isVisible
        
        ui.geckoTopPhoneConstraint.isActive = !pad
        ui.geckoBottomPhoneConstraint.isActive = !pad && !shouldShowGeckoBehindKeyboard
        ui.geckoBottomPhoneKeyboardOverlayConstraint.isActive = shouldShowGeckoBehindKeyboard
        ui.geckoLeadingPhoneConstraint.isActive = !pad
        ui.geckoTrailingPhoneConstraint.isActive = !pad
        ui.geckoTopPadConstraint.isActive = pad
        ui.geckoBottomPadConstraint.isActive = pad
        ui.geckoLeadingPadConstraint.isActive = pad
        ui.geckoTrailingPadConstraint.isActive = pad
        
        ui.tabOverviewCollection.topPhoneConstraint.isActive = !pad
        ui.tabOverviewCollection.bottomPhoneConstraint.isActive = !pad
        ui.tabOverviewCollection.topPadConstraint.isActive = pad
        ui.tabOverviewCollection.bottomPadConstraint.isActive = pad
        
        let showsPadTabStrip = pad && !controller.tabOverviewPresentation.isVisible && controller.tabManager.tabs.count > 1
        ui.topBar.barView.isHidden = !pad
        ui.topBar.safeAreaFillView.isHidden = !pad
        ui.padTabBar.collectionView.isHidden = !showsPadTabStrip
        ui.padTabBar.heightConstraint.constant = showsPadTabStrip ? 36 : 0
        
        ui.chromeContainer.containerView.isHidden = pad || controller.tabOverviewPresentation.isVisible
        ui.chromeContainer.bottomSafeAreaFillView.isHidden = pad || controller.tabOverviewPresentation.isVisible
        
        ui.tabOverviewTopBar.barView.isHidden = !pad
        ui.tabOverviewBottomBar.barView.isHidden = pad
        ui.tabOverviewBottomBar.safeAreaFillView.isHidden = true
        ui.tabOverviewBarButtons.attach(to: pad ? ui.tabOverviewTopBar.barView : ui.tabOverviewBottomBar.barView)
        
        let showDismissButton = !pad && controller.isSearchFocused
        ui.addressBarPhoneLeadingConstraint.isActive = !pad
        ui.addressBarPhoneTopConstraint.isActive = !pad
        ui.addressBarPhoneHeightConstraint.isActive = !pad
        ui.addressBarPhoneTrailingFullConstraint.isActive = !pad && !showDismissButton
        ui.addressBarPhoneTrailingFocusedConstraint.isActive = !pad && showDismissButton
        
        ui.addressBarPadLeadingConstraint.isActive = pad
        ui.addressBarPadTrailingConstraint.isActive = pad
        ui.addressBarPadCenterYConstraint.isActive = pad
        ui.addressBarPadHeightConstraint.isActive = pad
        
        ui.keyboardDismissButton.button.isHidden = !showDismissButton
        ui.addressBar.setShadowEnabled(!pad)
        
        controller.updateNavigationButtons()
        
        let layoutBlock = {
            self.controller.view.layoutIfNeeded()
            self.updatePhoneDismissKeyboardButtonShadowPath()
        }
        
        if animated {
            UIView.animate(withDuration: 0.22, animations: layoutBlock)
        } else {
            layoutBlock()
        }
    }
    
    func setSearchFocused(_ focused: Bool, animated: Bool) {
        guard !controller.usesPadChromeLayout else {
            return
        }
        
        let ui = controller.browserUI
        
        controller.isSearchFocused = focused
        ui.phoneToolbarHeightConstraint.constant = focused ? 0 : 30
        ui.phoneChromeHeightConstraint.constant = focused ? 58 : 94
        ui.chromeContainer.containerView.backgroundColor = focused ? .clear : .systemGray6
        ui.chromeContainer.bottomSafeAreaFillView.backgroundColor = focused ? .clear : .systemGray6
        
        ui.addressBarPhoneTrailingFullConstraint.isActive = !focused
        ui.addressBarPhoneTrailingFocusedConstraint.isActive = focused
        
        let dismissButtonTargetAlpha: CGFloat = focused ? 1 : 0
        if focused {
            ui.keyboardDismissButton.button.isHidden = false
        }
        
        let animations = {
            ui.toolbarView.alpha = focused ? 0 : 1
            ui.keyboardDismissButton.button.alpha = dismissButtonTargetAlpha
            self.controller.view.layoutIfNeeded()
            self.updatePhoneDismissKeyboardButtonShadowPath()
        }
        
        let completion: (Bool) -> Void = { _ in
            if !focused {
                ui.keyboardDismissButton.button.isHidden = true
            }
        }
        
        if animated {
            UIView.animate(withDuration: 0.2, animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
    }
    
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard !controller.usesPadChromeLayout,
              let info = notification.userInfo,
              let frameValue = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }
        
        let ui = controller.browserUI
        let keyboardFrame = controller.view.convert(frameValue.cgRectValue, from: nil)
        let overlap = max(0, controller.view.bounds.maxY - keyboardFrame.minY)
        let safeBottom = controller.view.safeAreaInsets.bottom
        keyboardHeight = max(0, overlap - safeBottom)
        
        let shouldDockChromeToKeyboard = controller.isSearchFocused
        && !controller.tabOverviewPresentation.isVisible
        && keyboardHeight > 0
        ui.phoneChromeBottomConstraint.constant = shouldDockChromeToKeyboard ? -keyboardHeight : 0
        applyChromeLayout(animated: false)
        
        let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        let curve = UIView.AnimationOptions(rawValue: curveRaw << 16)
        
        UIView.animate(withDuration: duration, delay: 0, options: [curve]) {
            self.controller.view.layoutIfNeeded()
            self.updatePhoneDismissKeyboardButtonShadowPath()
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard !controller.usesPadChromeLayout else {
            return
        }
        
        let ui = controller.browserUI
        
        keyboardHeight = 0
        ui.phoneChromeBottomConstraint.constant = 0
        applyChromeLayout(animated: false)
        
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.25
        let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        let curve = UIView.AnimationOptions(rawValue: curveRaw << 16)
        UIView.animate(withDuration: duration, delay: 0, options: [curve]) {
            self.controller.view.layoutIfNeeded()
            self.updatePhoneDismissKeyboardButtonShadowPath()
        }
    }
    
    private func updatePhoneDismissKeyboardButtonShadowPath() {
        let button = controller.browserUI.keyboardDismissButton.button
        guard button.bounds.width > 1, button.bounds.height > 1 else {
            button.layer.shadowPath = nil
            return
        }
        button.layer.shadowPath = UIBezierPath(roundedRect: button.bounds, cornerRadius: button.layer.cornerRadius).cgPath
    }
}
