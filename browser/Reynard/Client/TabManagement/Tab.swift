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
    var session: GeckoSession
    var title: String
    var url: String?
    var isPrivate: Bool
    var favicon: UIImage?
    var pendingRestoreURL: String?
    var pendingDisplayText: String?
    var selectionOrder = 0
    var suppressInitialNavigation = true
    var sessionCanGoBack = false
    var sessionCanGoForward = false
    var canNavigateBack = false
    var canNavigateForward = false
    var isLoading = false
    var progress: Float = 0
    var thumbnail: UIImage?
    var nowPlayingController: NowPlayingController?
    
    init(
        id: UUID = UUID(),
        session: GeckoSession,
        title: String = "",
        url: String? = nil,
        favicon: UIImage? = nil,
        thumbnail: UIImage? = nil,
        isPrivate: Bool = false
    ) {
        self.id = id
        self.session = session
        self.title = title
        self.url = url
        self.favicon = favicon
        self.thumbnail = thumbnail
        self.isPrivate = isPrivate
    }
}
