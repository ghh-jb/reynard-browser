//
//  BrowserViewController+Actions.swift
//  Reynard
//
//  Created by Minh Ton on 15/5/26.
//

import GeckoView
import ObjectiveC
import UIKit

private enum ActionsAssociatedKeys {
    static var addonsController = 0
}

extension BrowserViewController {
    var addonsController: AddonsController {
        get {
            if let controller = objc_getAssociatedObject(self, &ActionsAssociatedKeys.addonsController) as? AddonsController {
                return controller
            }
            
            let controller = AddonsController(controller: self)
            objc_setAssociatedObject(self, &ActionsAssociatedKeys.addonsController, controller, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return controller
        }
        set {
            objc_setAssociatedObject(self, &ActionsAssociatedKeys.addonsController, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func presentMenuSheet(initialSection: LibrarySection = .bookmarks) {
        let viewController = LibraryViewController(initialSection: initialSection) { [weak self] in
            self?.dismiss(animated: true)
        }
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true)
    }
    
    func presentShareSheet() {
        guard let tab = tabManager.selectedTab,
              let url = tabManager.shareableURL(for: tab) else {
            return
        }
        
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = sheet.popoverPresentationController {
            let sourceView = usesCompactPadChrome ? browserUI.toolbarView : (usesPadChrome ? browserUI.topBar.barView : browserUI.toolbarView)
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(sheet, animated: true)
    }
    
    func showTabOverview() {
        setTabOverviewVisible(true, animated: true)
    }
    
    func hideTabOverview() {
        setTabOverviewVisible(false, animated: true)
    }
    
    func createNewTab() {
        _ = createTab(selecting: true)
        setTabOverviewVisible(false, animated: true)
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func goBack() {
        tabManager.selectedTab?.session.goBack()
    }
    
    func goForward() {
        tabManager.selectedTab?.session.goForward()
    }
    
    func changeWebsiteMode() {
        guard let tab = tabManager.selectedTab,
              let url = tab.url else {
            return
        }
        
        UserAgentController.shared.changeWebsiteMode(for: url, tabID: tab.id)
        tab.session.updateUserAgent(UserAgentController.shared.userAgent(for: url, tabID: tab.id))
        tab.session.reload()
        refreshAddressBar()
    }
    
    @objc func changeWebsiteModeRequested() {
        changeWebsiteMode()
    }
    
    func backButtonClicked() {
        goBack()
    }
    
    func forwardButtonClicked() {
        goForward()
    }
    
    func shareButtonClicked() {
        presentShareSheet()
    }
    
    func menuButtonClicked() {
        presentMenuSheet()
    }
    
    func tabsButtonClicked() {
        showTabOverview()
    }
    
    @objc func tabsTapped() {
        showTabOverview()
    }
    
    @objc func doneTapped() {
        hideTabOverview()
    }
    
    @objc func newTabTapped() {
        createNewTab()
    }
    
    @objc func clearAllTabsTapped() {
        clearAllTabs()
    }
    
    @objc func shareTapped() {
        presentShareSheet()
    }
    
    @objc func padBackTapped() {
        goBack()
    }
    
    @objc func padForwardTapped() {
        goForward()
    }
    
    @objc func topBarMenuTapped() {
        presentMenuSheet()
    }
    
    @objc func dismissKeyboardTapped() {
        dismissKeyboard()
    }
}
