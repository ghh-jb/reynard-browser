//
//  AddressBarMenu.swift
//  Reynard
//
//  Created by Minh Ton on 28/4/26.
//

import UIKit

enum AddressBarMenu {
    struct AddonItem {
        let menuItem: AddonMenuItem
        let image: UIImage?
    }
    
    private static let rootIdentifier = UIMenu.Identifier("me.minh-ton.reynard.address-bar-menu")
    private static let manageAddonsIdentifier = UIMenu.Identifier("me.minh-ton.reynard.address-bar-menu.manage-addons")
    static let presentAddonSettingsNotification = Notification.Name("me.minh-ton.reynard.address-bar-menu.present-addon-settings")
    static let changeWebsiteModeNotification = Notification.Name("me.minh-ton.reynard.address-bar-menu.toggle-website-mode")
    
    static func makeMenu(
        selectedTab: Tab?,
        selectedURL: String?,
        addonItems: [AddonItem]
    ) -> UIMenu? {
        var children: [UIMenuElement] = []
        
        if let selectedTab,
           let selectedURL,
           let isDesktop = UserAgentController.shared.isDesktopMode(for: selectedURL, tabID: selectedTab.id) {
            let title = isDesktop ? "Request Mobile Website" : "Request Desktop Website"
            let imageName = isDesktop ? "iphone" : "desktopcomputer"
            children.append(UIAction(title: title, image: UIImage(systemName: imageName)) { _ in
                NotificationCenter.default.post(name: changeWebsiteModeNotification, object: nil)
            })
        }
        
        let addonsChildren: [UIMenuElement]
        if addonItems.isEmpty {
            addonsChildren = [
                UIAction(
                    title: "No Add-ons",
                    image: UIImage(systemName: "puzzlepiece.extension"),
                    attributes: .disabled
                ) { _ in }
            ]
        } else {
            addonsChildren = addonItems.map { item in
                UIAction(title: item.menuItem.title, image: item.image) { _ in
                    NotificationCenter.default.post(
                        name: presentAddonSettingsNotification,
                        object: nil,
                        userInfo: ["addonItem": item.menuItem]
                    )
                }
            }
        }
        
        children.append(
            UIMenu(
                title: "Manage Add-ons",
                image: UIImage(systemName: "puzzlepiece.extension"),
                identifier: manageAddonsIdentifier,
                children: addonsChildren
            )
        )
        
        guard !children.isEmpty else {
            return nil
        }
        
        return UIMenu(title: "", image: nil, identifier: rootIdentifier, options: [], children: children)
    }
}
