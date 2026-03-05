//
//  Tab.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import GeckoView
import UIKit

final class Tab {
    let session: GeckoSession
    var title: String
    var url: String?
    var suppressInitialNavigation = true
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var progress: Float = 0
    var thumbnail: UIImage?
    
    init(session: GeckoSession, title: String = "Homepage") {
        self.session = session
        self.title = title
    }
}
