//
//  BrowserViewController+BrowserActions.swift
//  Reynard
//
//  Created by Minh Ton on 16/6/26.
//

import UIKit

extension BrowserViewController {
    func presentLibrary(initialSection: LibrarySection = .bookmarks) {
        if initialSection == .downloads {
            DownloadStore.shared.markCompletedAsViewed()
            if browserLayout.interfaceIdiom == .pad,
               browserLayout.chromeMode == .pad {
                sidebarCoordinator.showSection(.downloads)
                return
            }
        }
        
        let libraryController = LibraryViewController(
            initialSection: initialSection,
            isPrivateMode: tabManager.selectedTab?.isPrivate == true
        ) { [weak self] in
            self?.dismiss(animated: true)
        }
        let navigationController = UINavigationController(rootViewController: libraryController)
        navigationController.modalPresentationStyle = .pageSheet
        present(navigationController, animated: true)
    }
    
    func presentShareSheet(url urlString: String? = nil) {
        let urlToShare: URL?
        if let urlString {
            urlToShare = URL(string: urlString)
        } else if let tab = tabManager.selectedTab {
            urlToShare = tabManager.shareableURL(for: tab)
        } else {
            urlToShare = nil
        }
        
        guard let url = urlToShare else {
            return
        }
        
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activityController.popoverPresentationController {
            let sourceView = browserChrome.sharePopoverSourceView()
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(activityController, animated: true)
    }
    
    func createNewTab() {
        dismissAddressBarEditingAndOverlays()
        
        if tabOverview.isPresented {
            let mode = tabOverview.mode
            tabOverview.prepareNextTabChangesWithoutAnimation()
            let newTabIndex = tabManager.createTab(
                selecting: true,
                target: .end,
                mode: mode.tabMode
            )
            applyNewTabDisplayOption(toTabAt: newTabIndex)
            tabOverview.prepareDismissSelection(to: newTabIndex, mode: mode.tabMode, previewImage: nil)
            scrollTabOverviewToTab(at: newTabIndex)
            tabBar.setPendingExpansion(at: newTabIndex)
            setTabOverviewVisible(false, animated: true)
        } else {
            let newTabIndex = tabManager.createTab(selecting: true)
            applyNewTabDisplayOption(toTabAt: newTabIndex)
            tabBar.setPendingExpansion(at: newTabIndex)
            setTabOverviewVisible(false, animated: true)
        }
    }
}
