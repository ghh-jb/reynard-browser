//
//  Tab.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import GeckoView
import UIKit

final class Tab {
    let id: UUID
    let session: GeckoSession
    var title: String
    var url: String?
    var pendingRestoreURL: String?
    var suppressInitialNavigation = true
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var progress: Float = 0
    var thumbnail: UIImage?
    var nowPlayingController: NowPlayingController?
    
    init(
        id: UUID = UUID(),
        session: GeckoSession,
        title: String = "Homepage",
        url: String? = nil,
        thumbnail: UIImage? = nil
    ) {
        self.id = id
        self.session = session
        self.title = title
        self.url = url
        self.thumbnail = thumbnail
    }
}
