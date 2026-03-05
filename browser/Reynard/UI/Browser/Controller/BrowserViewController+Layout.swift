//
//  BrowserViewController+Layout.swift
//  Reynard
//
//  Created by Minh Ton on 4/3/26.
//

import UIKit

extension BrowserViewController {
    func configureLayout() {
        let ui = browserUI
        
        view.addSubview(ui.phoneBottomSafeAreaFillView)
        view.addSubview(ui.geckoView)
        view.addSubview(ui.phoneChromeContainer)
        view.addSubview(ui.padTopSafeAreaFillView)
        
        ui.phoneChromeContainer.addSubview(ui.phoneAddressBar)
        ui.phoneChromeContainer.addSubview(ui.phoneDismissKeyboardButton)
        ui.phoneChromeContainer.addSubview(ui.toolbarView)
        
        view.addSubview(ui.padTopBar)
        ui.padTopBar.addSubview(ui.padAddressBar)
        
        let padLeftStack = UIStackView(arrangedSubviews: [ui.padBackButton, ui.padForwardButton])
        padLeftStack.translatesAutoresizingMaskIntoConstraints = false
        padLeftStack.axis = .horizontal
        padLeftStack.spacing = 10
        padLeftStack.distribution = .fillEqually
        
        let padRightStack = UIStackView(arrangedSubviews: [ui.padShareButton, ui.padNewTabButton, ui.padTabOverviewButton])
        padRightStack.translatesAutoresizingMaskIntoConstraints = false
        padRightStack.axis = .horizontal
        padRightStack.spacing = 10
        padRightStack.distribution = .fillEqually
        
        let overviewPhoneActionStack = UIStackView(arrangedSubviews: [ui.overviewClearButton, ui.overviewAddButton, ui.overviewDoneButton])
        overviewPhoneActionStack.translatesAutoresizingMaskIntoConstraints = false
        overviewPhoneActionStack.axis = .horizontal
        overviewPhoneActionStack.alignment = .center
        overviewPhoneActionStack.distribution = .equalSpacing
        
        let overviewPadActionStack = UIStackView(arrangedSubviews: [ui.overviewPadClearButton, ui.overviewPadAddButton, ui.overviewPadDoneButton])
        overviewPadActionStack.translatesAutoresizingMaskIntoConstraints = false
        overviewPadActionStack.axis = .horizontal
        overviewPadActionStack.alignment = .center
        overviewPadActionStack.distribution = .equalSpacing
        
        ui.padTopBar.addSubview(padLeftStack)
        ui.padTopBar.addSubview(padRightStack)
        
        view.addSubview(ui.padTabStripCollectionView)
        
        view.addSubview(ui.tabOverviewContainer)
        ui.tabOverviewContainer.addSubview(ui.tabOverviewBlurView)
        ui.tabOverviewContainer.addSubview(ui.tabOverviewCollectionView)
        ui.tabOverviewContainer.addSubview(ui.overviewPhoneBottomSafeAreaFillView)
        ui.tabOverviewContainer.addSubview(ui.overviewPhoneBottomBar)
        ui.tabOverviewContainer.addSubview(ui.overviewPadTopBar)
        
        ui.overviewPhoneBottomBar.addSubview(overviewPhoneActionStack)
        
        ui.overviewPadTopBar.addSubview(overviewPadActionStack)
        
        ui.phoneDismissKeyboardButton.backgroundColor = .systemBackground
        ui.phoneDismissKeyboardButton.tintColor = .label
        ui.phoneDismissKeyboardButton.layer.cornerCurve = .continuous
        ui.phoneDismissKeyboardButton.layer.cornerRadius = 21
        ui.phoneDismissKeyboardButton.layer.shadowColor = UIColor.black.cgColor
        ui.phoneDismissKeyboardButton.layer.shadowOpacity = 0.2
        ui.phoneDismissKeyboardButton.layer.shadowRadius = 12
        ui.phoneDismissKeyboardButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        ui.phoneDismissKeyboardButton.layer.masksToBounds = false
        ui.phoneDismissKeyboardButton.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
        ui.phoneDismissKeyboardButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 17, weight: .regular),
            forImageIn: .normal
        )
        
        ui.phoneDismissKeyboardButton.addTarget(self, action: #selector(dismissKeyboardTapped), for: .touchUpInside)
        
        ui.geckoTopPhoneConstraint = ui.geckoView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ui.geckoTopPadConstraint = ui.geckoView.topAnchor.constraint(equalTo: ui.padTabStripCollectionView.bottomAnchor)
        ui.geckoBottomPhoneConstraint = ui.geckoView.bottomAnchor.constraint(equalTo: ui.phoneChromeContainer.topAnchor)
        ui.geckoBottomPhoneKeyboardOverlayConstraint = ui.geckoView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ui.geckoBottomPadConstraint = ui.geckoView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ui.geckoLeadingPhoneConstraint = ui.geckoView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ui.geckoTrailingPhoneConstraint = ui.geckoView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ui.geckoLeadingPadConstraint = ui.geckoView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ui.geckoTrailingPadConstraint = ui.geckoView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        
        ui.phoneChromeBottomConstraint = ui.phoneChromeContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ui.phoneChromeHeightConstraint = ui.phoneChromeContainer.heightAnchor.constraint(equalToConstant: 94)
        ui.phoneToolbarHeightConstraint = ui.toolbarView.heightAnchor.constraint(equalToConstant: 30)
        
        ui.overviewCollectionTopPhoneConstraint = ui.tabOverviewCollectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ui.overviewCollectionBottomPhoneConstraint = ui.tabOverviewCollectionView.bottomAnchor.constraint(equalTo: ui.overviewPhoneBottomBar.topAnchor)
        ui.overviewCollectionTopPadConstraint = ui.tabOverviewCollectionView.topAnchor.constraint(equalTo: ui.overviewPadTopBar.bottomAnchor)
        ui.overviewCollectionBottomPadConstraint = ui.tabOverviewCollectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ui.phoneAddressBarTrailingFullConstraint = ui.phoneAddressBar.trailingAnchor.constraint(equalTo: ui.phoneChromeContainer.trailingAnchor, constant: -12)
        ui.phoneAddressBarTrailingFocusedConstraint = ui.phoneAddressBar.trailingAnchor.constraint(equalTo: ui.phoneDismissKeyboardButton.leadingAnchor, constant: -8)
        ui.overviewPhoneBottomBarBottomConstraint = ui.overviewPhoneBottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ui.padTabStripHeightConstraint = ui.padTabStripCollectionView.heightAnchor.constraint(equalToConstant: 36)
        
        NSLayoutConstraint.activate([
            ui.geckoLeadingPhoneConstraint,
            ui.geckoTrailingPhoneConstraint,
            ui.geckoTopPhoneConstraint,
            ui.geckoBottomPhoneConstraint,
            
            ui.phoneChromeContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ui.phoneChromeContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ui.phoneChromeBottomConstraint,
            ui.phoneChromeHeightConstraint,
            
            ui.phoneBottomSafeAreaFillView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ui.phoneBottomSafeAreaFillView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ui.phoneBottomSafeAreaFillView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            ui.phoneBottomSafeAreaFillView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            ui.phoneAddressBar.leadingAnchor.constraint(equalTo: ui.phoneChromeContainer.leadingAnchor, constant: 12),
            ui.phoneAddressBarTrailingFullConstraint,
            ui.phoneAddressBar.topAnchor.constraint(equalTo: ui.phoneChromeContainer.topAnchor, constant: 8),
            ui.phoneAddressBar.heightAnchor.constraint(equalToConstant: 42),
            
            ui.phoneDismissKeyboardButton.trailingAnchor.constraint(equalTo: ui.phoneChromeContainer.trailingAnchor, constant: -12),
            ui.phoneDismissKeyboardButton.centerYAnchor.constraint(equalTo: ui.phoneAddressBar.centerYAnchor),
            ui.phoneDismissKeyboardButton.widthAnchor.constraint(equalToConstant: 42),
            ui.phoneDismissKeyboardButton.heightAnchor.constraint(equalToConstant: 42),
            
            ui.toolbarView.leadingAnchor.constraint(equalTo: ui.phoneChromeContainer.leadingAnchor, constant: 24),
            ui.toolbarView.trailingAnchor.constraint(equalTo: ui.phoneChromeContainer.trailingAnchor, constant: -24),
            ui.toolbarView.topAnchor.constraint(equalTo: ui.phoneAddressBar.bottomAnchor, constant: 7),
            ui.phoneToolbarHeightConstraint,
            
            ui.padTopBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ui.padTopBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ui.padTopBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            ui.padTopBar.heightAnchor.constraint(equalToConstant: 52),
            
            ui.padTopSafeAreaFillView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ui.padTopSafeAreaFillView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ui.padTopSafeAreaFillView.topAnchor.constraint(equalTo: view.topAnchor),
            ui.padTopSafeAreaFillView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            
            padLeftStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            padLeftStack.centerYAnchor.constraint(equalTo: ui.padTopBar.centerYAnchor),
            padLeftStack.widthAnchor.constraint(equalToConstant: 80),
            padLeftStack.heightAnchor.constraint(equalToConstant: 30),
            
            padRightStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            padRightStack.centerYAnchor.constraint(equalTo: ui.padTopBar.centerYAnchor),
            padRightStack.widthAnchor.constraint(equalToConstant: 126),
            padRightStack.heightAnchor.constraint(equalToConstant: 30),
            
            ui.padAddressBar.leadingAnchor.constraint(equalTo: padLeftStack.trailingAnchor, constant: 12),
            ui.padAddressBar.trailingAnchor.constraint(equalTo: padRightStack.leadingAnchor, constant: -12),
            ui.padAddressBar.centerYAnchor.constraint(equalTo: ui.padTopBar.centerYAnchor),
            ui.padAddressBar.heightAnchor.constraint(equalToConstant: 38),
            
            ui.padTabStripCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ui.padTabStripCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ui.padTabStripCollectionView.topAnchor.constraint(equalTo: ui.padTopBar.bottomAnchor),
            ui.padTabStripHeightConstraint,
            
            ui.tabOverviewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ui.tabOverviewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ui.tabOverviewContainer.topAnchor.constraint(equalTo: view.topAnchor),
            ui.tabOverviewContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            ui.tabOverviewBlurView.leadingAnchor.constraint(equalTo: ui.tabOverviewContainer.leadingAnchor),
            ui.tabOverviewBlurView.trailingAnchor.constraint(equalTo: ui.tabOverviewContainer.trailingAnchor),
            ui.tabOverviewBlurView.topAnchor.constraint(equalTo: ui.tabOverviewContainer.topAnchor),
            ui.tabOverviewBlurView.bottomAnchor.constraint(equalTo: ui.tabOverviewContainer.bottomAnchor),
            
            ui.tabOverviewCollectionView.leadingAnchor.constraint(equalTo: ui.tabOverviewContainer.safeAreaLayoutGuide.leadingAnchor),
            ui.tabOverviewCollectionView.trailingAnchor.constraint(equalTo: ui.tabOverviewContainer.safeAreaLayoutGuide.trailingAnchor),
            
            ui.overviewPhoneBottomBar.leadingAnchor.constraint(equalTo: ui.tabOverviewContainer.leadingAnchor),
            ui.overviewPhoneBottomBar.trailingAnchor.constraint(equalTo: ui.tabOverviewContainer.trailingAnchor),
            ui.overviewPhoneBottomBarBottomConstraint,
            ui.overviewPhoneBottomBar.heightAnchor.constraint(equalToConstant: 108),
            
            ui.overviewPhoneBottomSafeAreaFillView.leadingAnchor.constraint(equalTo: ui.tabOverviewContainer.leadingAnchor),
            ui.overviewPhoneBottomSafeAreaFillView.trailingAnchor.constraint(equalTo: ui.tabOverviewContainer.trailingAnchor),
            ui.overviewPhoneBottomSafeAreaFillView.topAnchor.constraint(equalTo: ui.overviewPhoneBottomBar.bottomAnchor),
            ui.overviewPhoneBottomSafeAreaFillView.bottomAnchor.constraint(equalTo: ui.tabOverviewContainer.bottomAnchor),
            
            overviewPhoneActionStack.leadingAnchor.constraint(equalTo: ui.overviewPhoneBottomBar.leadingAnchor, constant: 32),
            overviewPhoneActionStack.trailingAnchor.constraint(equalTo: ui.overviewPhoneBottomBar.trailingAnchor, constant: -32),
            overviewPhoneActionStack.centerYAnchor.constraint(equalTo: ui.overviewPhoneBottomBar.centerYAnchor),
            
            ui.overviewClearButton.widthAnchor.constraint(equalToConstant: 42),
            ui.overviewClearButton.heightAnchor.constraint(equalTo: ui.overviewClearButton.widthAnchor),
            ui.overviewAddButton.widthAnchor.constraint(equalToConstant: 42),
            ui.overviewAddButton.heightAnchor.constraint(equalTo: ui.overviewAddButton.widthAnchor),
            ui.overviewDoneButton.widthAnchor.constraint(equalToConstant: 42),
            ui.overviewDoneButton.heightAnchor.constraint(equalTo: ui.overviewDoneButton.widthAnchor),
            
            ui.overviewPadTopBar.leadingAnchor.constraint(equalTo: ui.tabOverviewContainer.leadingAnchor),
            ui.overviewPadTopBar.trailingAnchor.constraint(equalTo: ui.tabOverviewContainer.trailingAnchor),
            ui.overviewPadTopBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            ui.overviewPadTopBar.heightAnchor.constraint(equalToConstant: 108),
            
            overviewPadActionStack.leadingAnchor.constraint(equalTo: ui.overviewPadTopBar.leadingAnchor, constant: 32),
            overviewPadActionStack.trailingAnchor.constraint(equalTo: ui.overviewPadTopBar.trailingAnchor, constant: -32),
            overviewPadActionStack.centerYAnchor.constraint(equalTo: ui.overviewPadTopBar.centerYAnchor),
            
            ui.overviewPadClearButton.widthAnchor.constraint(equalToConstant: 42),
            ui.overviewPadClearButton.heightAnchor.constraint(equalTo: ui.overviewPadClearButton.widthAnchor),
            ui.overviewPadAddButton.widthAnchor.constraint(equalToConstant: 42),
            ui.overviewPadAddButton.heightAnchor.constraint(equalTo: ui.overviewPadAddButton.widthAnchor),
            ui.overviewPadDoneButton.widthAnchor.constraint(equalToConstant: 42),
            ui.overviewPadDoneButton.heightAnchor.constraint(equalTo: ui.overviewPadDoneButton.widthAnchor),
        ])
        
        view.sendSubviewToBack(ui.phoneBottomSafeAreaFillView)
    }
    
    func configureGestures() {
        let phonePan = UIPanGestureRecognizer(target: self, action: #selector(handleSearchPan(_:)))
        phonePan.maximumNumberOfTouches = 1
        phonePan.cancelsTouchesInView = false
        phonePan.delegate = self
        
        let phoneSwipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSearchSwipeUp(_:)))
        phoneSwipeUp.direction = .up
        phoneSwipeUp.numberOfTouchesRequired = 1
        phoneSwipeUp.cancelsTouchesInView = false
        phoneSwipeUp.delegate = self
        
        phonePan.require(toFail: phoneSwipeUp)
        
        browserUI.phoneAddressBar.addGestureRecognizer(phoneSwipeUp)
        browserUI.phoneAddressBar.addGestureRecognizer(phonePan)
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
        let ui = browserUI
        let pad = usesPadChromeLayout
        let shouldShowGeckoBehindKeyboard = !pad && isSearchFocused && keyboardHeight > 0 && !isTabOverviewVisible
        
        ui.geckoTopPhoneConstraint.isActive = !pad
        ui.geckoBottomPhoneConstraint.isActive = !pad && !shouldShowGeckoBehindKeyboard
        ui.geckoBottomPhoneKeyboardOverlayConstraint.isActive = shouldShowGeckoBehindKeyboard
        ui.geckoLeadingPhoneConstraint.isActive = !pad
        ui.geckoTrailingPhoneConstraint.isActive = !pad
        ui.geckoTopPadConstraint.isActive = pad
        ui.geckoBottomPadConstraint.isActive = pad
        ui.geckoLeadingPadConstraint.isActive = pad
        ui.geckoTrailingPadConstraint.isActive = pad
        
        ui.overviewCollectionTopPhoneConstraint.isActive = !pad
        ui.overviewCollectionBottomPhoneConstraint.isActive = !pad
        ui.overviewCollectionTopPadConstraint.isActive = pad
        ui.overviewCollectionBottomPadConstraint.isActive = pad
        
        let showsPadTabStrip = pad && !isTabOverviewVisible && tabs.count > 1
        ui.padTopBar.isHidden = !pad
        ui.padTopSafeAreaFillView.isHidden = !pad
        ui.padTabStripCollectionView.isHidden = !showsPadTabStrip
        ui.padTabStripHeightConstraint.constant = showsPadTabStrip ? 36 : 0
        
        ui.phoneChromeContainer.isHidden = pad || isTabOverviewVisible
        ui.phoneBottomSafeAreaFillView.isHidden = pad || isTabOverviewVisible
        
        ui.overviewPadTopBar.isHidden = !pad
        ui.overviewPhoneBottomBar.isHidden = pad
        ui.overviewPhoneBottomSafeAreaFillView.isHidden = true
        
        let showDismissButton = !pad && isSearchFocused
        ui.phoneAddressBarTrailingFullConstraint.isActive = !showDismissButton
        ui.phoneAddressBarTrailingFocusedConstraint.isActive = showDismissButton
        ui.phoneDismissKeyboardButton.isHidden = !showDismissButton
        ui.phoneAddressBar.setShadowEnabled(!pad)
        ui.padAddressBar.setShadowEnabled(false)
        
        updateNavigationButtons()
        
        let layoutBlock = {
            self.view.layoutIfNeeded()
            self.updatePhoneDismissKeyboardButtonShadowPath()
        }
        
        if animated {
            UIView.animate(withDuration: 0.22, animations: layoutBlock)
        } else {
            layoutBlock()
        }
    }
    
    func setSearchFocused(_ focused: Bool, animated: Bool) {
        guard !usesPadChromeLayout else {
            return
        }
        
        let ui = browserUI
        
        isSearchFocused = focused
        ui.phoneToolbarHeightConstraint.constant = focused ? 0 : 30
        ui.phoneChromeHeightConstraint.constant = focused ? 58 : 94
        ui.phoneChromeContainer.backgroundColor = focused ? .clear : .systemGray6
        ui.phoneBottomSafeAreaFillView.backgroundColor = focused ? .clear : .systemGray6
        
        ui.phoneAddressBarTrailingFullConstraint.isActive = !focused
        ui.phoneAddressBarTrailingFocusedConstraint.isActive = focused
        
        let dismissButtonTargetAlpha: CGFloat = focused ? 1 : 0
        if focused {
            ui.phoneDismissKeyboardButton.isHidden = false
        }
        
        let animations = {
            ui.toolbarView.alpha = focused ? 0 : 1
            ui.phoneDismissKeyboardButton.alpha = dismissButtonTargetAlpha
            self.view.layoutIfNeeded()
            self.updatePhoneDismissKeyboardButtonShadowPath()
        }
        
        let completion: (Bool) -> Void = { _ in
            if !focused {
                ui.phoneDismissKeyboardButton.isHidden = true
            }
        }
        
        if animated {
            UIView.animate(withDuration: 0.2, animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        guard !usesPadChromeLayout,
              let info = notification.userInfo,
              let frameValue = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }
        
        let ui = browserUI
        let keyboardFrame = view.convert(frameValue.cgRectValue, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
        let safeBottom = view.safeAreaInsets.bottom
        keyboardHeight = max(0, overlap - safeBottom)
        
        let shouldDockChromeToKeyboard = isSearchFocused && !isTabOverviewVisible && keyboardHeight > 0
        ui.phoneChromeBottomConstraint.constant = shouldDockChromeToKeyboard ? -keyboardHeight : 0
        applyChromeLayout(animated: false)
        
        let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        let curve = UIView.AnimationOptions(rawValue: curveRaw << 16)
        
        UIView.animate(withDuration: duration, delay: 0, options: [curve]) {
            self.view.layoutIfNeeded()
            self.updatePhoneDismissKeyboardButtonShadowPath()
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        guard !usesPadChromeLayout else {
            return
        }
        
        let ui = browserUI
        
        keyboardHeight = 0
        ui.phoneChromeBottomConstraint.constant = 0
        applyChromeLayout(animated: false)
        
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.25
        let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        let curve = UIView.AnimationOptions(rawValue: curveRaw << 16)
        UIView.animate(withDuration: duration, delay: 0, options: [curve]) {
            self.view.layoutIfNeeded()
            self.updatePhoneDismissKeyboardButtonShadowPath()
        }
    }
    
    func updatePhoneDismissKeyboardButtonShadowPath() {
        let button = browserUI.phoneDismissKeyboardButton
        guard button.bounds.width > 1, button.bounds.height > 1 else {
            button.layer.shadowPath = nil
            return
        }
        button.layer.shadowPath = UIBezierPath(roundedRect: button.bounds, cornerRadius: button.layer.cornerRadius).cgPath
    }
}
