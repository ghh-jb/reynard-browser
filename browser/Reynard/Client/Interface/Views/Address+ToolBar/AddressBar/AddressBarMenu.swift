//
//  AddressBarMenu.swift
//  Reynard
//
//  Created by Minh Ton on 28/4/26.
//

import UIKit

enum AddressBarMenu {
    static func makeMenu(addonsController: AddonsController) -> UIMenu? {
        let addBookmarkAction = UIAction(
            title: "Add Bookmark",
            image: UIImage(systemName: "book")
        ) { _ in }
        
        let addonItems = addonsController.visibleMenuItemsForCurrentSite()
        let manageAddonsChildren: [UIMenuElement]
        if addonItems.isEmpty {
            manageAddonsChildren = [
                UIAction(
                    title: "No Add-ons",
                    image: UIImage(systemName: "puzzlepiece.extension"),
                    attributes: .disabled
                ) { _ in }
            ]
        } else {
            manageAddonsChildren = addonItems.map { item in
                UIAction(
                    title: item.title,
                    image: addonsController.iconImage(for: item.addon)
                ) { _ in
                    addonsController.presentCurrentSiteSettings(for: item)
                }
            }
        }
        
        let manageAddonsMenu = UIMenu(
            title: "Manage Add-ons",
            image: UIImage(systemName: "puzzlepiece.extension"),
            children: manageAddonsChildren
        )
        
        return UIMenu(children: [addBookmarkAction, manageAddonsMenu])
    }
}
