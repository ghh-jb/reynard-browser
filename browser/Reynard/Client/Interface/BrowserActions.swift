//
//  BrowserActions.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import GeckoView
import UIKit

final class BrowserActions {
    private unowned let controller: BrowserViewController
    
    init(controller: BrowserViewController) {
        self.controller = controller
    }
    
    func presentMenuSheet() {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        vc.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            if let sheet = vc.sheetPresentationController {
                sheet   .prefersGrabberVisible = true
                sheet.detents = [.medium(), .large()]
            }
        }
        controller.present(vc, animated: true)
    }
    
    func presentShareSheet() {
        guard let tab = controller.tabManager.selectedTab,
              let url = controller.tabManager.shareableURL(for: tab) else {
            return
        }
        
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = sheet.popoverPresentationController {
            let sourceView = controller.usesCompactPadChromeMode ? controller.browserUI.toolbarView : (controller.usesPadChromeLayout ? controller.browserUI.topBar.barView : controller.browserUI.toolbarView)
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        controller.present(sheet, animated: true)
    }
    
    func showTabOverview() {
        controller.setTabOverviewVisible(true, animated: true)
    }
    
    func hideTabOverview() {
        controller.setTabOverviewVisible(false, animated: true)
    }
    
    func createNewTab() {
        _ = controller.createTab(selecting: true)
        controller.setTabOverviewVisible(false, animated: true)
    }
    
    func clearAllTabs() {
        controller.clearAllTabs()
    }
    
    func dismissKeyboard() {
        controller.view.endEditing(true)
    }
    
    func goBack() {
        controller.tabManager.selectedTab?.session.goBack()
    }
    
    func goForward() {
        controller.tabManager.selectedTab?.session.goForward()
    }
}
