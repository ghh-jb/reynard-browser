//
//  HomepageSnapshotCache.swift
//  Reynard
//
//  Created by Minh Ton on 21/6/26.
//

import UIKit

struct HomepageSnapshotCache {
    let pixelSize: CGSize
    let contentMode: HomepageContentMode
    let isPrivateBrowsing: Bool
    let userInterfaceStyle: UIUserInterfaceStyle
    let image: UIImage
    
    func matches(
        pixelSize: CGSize,
        contentMode: HomepageContentMode,
        isPrivateBrowsing: Bool,
        userInterfaceStyle: UIUserInterfaceStyle
    ) -> Bool {
        return self.contentMode == contentMode
        && self.isPrivateBrowsing == isPrivateBrowsing
        && self.userInterfaceStyle == userInterfaceStyle
        && abs(self.pixelSize.width - pixelSize.width) < 1
        && abs(self.pixelSize.height - pixelSize.height) < 1
    }
}
