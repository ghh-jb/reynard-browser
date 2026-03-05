//
//  BrowserViewController+Actions.swift
//  Reynard
//
//  Created by Minh Ton on 4/3/26.
//

import UIKit

extension BrowserViewController {
    // Dummy modal, something will be put here eventually.
    func presentMenuSheet() {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.prefersGrabberVisible = true
            sheet.detents = [.medium(), .large()]
        }
        present(vc, animated: true)
    }
    
    func presentShareSheet() {
        guard tabs.indices.contains(selectedTabIndex),
              let url = shareableURL(for: tabs[selectedTabIndex]) else {
            return
        }
        
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = usesPadChromeLayout ? browserUI.padTopBar : browserUI.toolbarView
            popover.sourceRect = usesPadChromeLayout ? browserUI.padTopBar.bounds : browserUI.toolbarView.bounds
        }
        present(sheet, animated: true)
    }
    
    @objc func tabsTapped() {
        setTabOverviewVisible(true, animated: true)
    }
    
    @objc func doneTapped() {
        setTabOverviewVisible(false, animated: true)
    }
    
    @objc func newTabTapped() {
        createTab(selecting: true)
        setTabOverviewVisible(false, animated: true)
    }
    
    @objc func clearAllTabsTapped() {
        clearAllTabs()
    }
    
    @objc func shareTapped() {
        presentShareSheet()
    }
    
    @objc func padBackTapped() {
        backButtonClicked()
    }
    
    @objc func padForwardTapped() {
        forwardButtonClicked()
    }
    
    @objc func dismissKeyboardTapped() {
        view.endEditing(true)
    }
}
