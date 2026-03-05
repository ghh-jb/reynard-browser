//
//  TabManagerImpl.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import Foundation
import GeckoView
import UIKit

final class TabManagerImplementation: NSObject, TabManager {
    private(set) var tabs: [Tab] = []
    private(set) var selectedTabIndex = 0
    
    var selectedTab: Tab? {
        tabs[safe: selectedTabIndex]
    }
    
    private weak var delegate: TabManagerDelegate?
    
    private lazy var isURLLenient: NSRegularExpression = {
        let pattern = "^\\s*(\\w+-+)*[\\w\\[]+(://[/]*|:|\\.)(\\w+-+)*[\\w\\[:]+([\\S&&[^\\w-]]\\S*)?\\s*$"
        return try! NSRegularExpression(pattern: pattern)
    }()
    
    init(delegate: TabManagerDelegate?) {
        self.delegate = delegate
    }
    
    func createInitialTab() {
        addTab(selecting: true, windowId: nil)
    }
    
    @discardableResult
    func addTab(selecting: Bool, windowId: String? = nil) -> Int {
        let tab = Tab(session: createSession(windowId: windowId))
        tabs.append(tab)
        
        let index = tabs.count - 1
        delegate?.tabManagerDidChangeTabs(self)
        
        if selecting {
            selectTab(at: index)
        }
        
        return index
    }
    
    func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else {
            return
        }
        
        let previousIndex = tabs.indices.contains(selectedTabIndex) ? selectedTabIndex : nil
        
        if let previousIndex, previousIndex != index {
            tabs[previousIndex].session.setActive(false)
        }
        
        selectedTabIndex = index
        tabs[index].session.setActive(true)
        
        delegate?.tabManager(self, didSelectTabAt: index, previousIndex: previousIndex)
    }
    
    func removeTab(at index: Int) {
        guard tabs.indices.contains(index) else {
            return
        }
        
        let wasSelected = index == selectedTabIndex
        let removedTab = tabs.remove(at: index)
        removedTab.session.close()
        
        if tabs.isEmpty {
            selectedTabIndex = 0
            delegate?.tabManagerDidChangeTabs(self)
            addTab(selecting: true, windowId: nil)
            return
        }
        
        if index < selectedTabIndex {
            selectedTabIndex -= 1
        }
        
        delegate?.tabManagerDidChangeTabs(self)
        
        if wasSelected {
            let fallback = min(index, tabs.count - 1)
            selectTab(at: fallback)
        }
    }
    
    func removeAllTabs() {
        guard !tabs.isEmpty else {
            return
        }
        
        tabs.forEach { $0.session.close() }
        tabs.removeAll(keepingCapacity: true)
        selectedTabIndex = 0
        delegate?.tabManagerDidChangeTabs(self)
        addTab(selecting: true, windowId: nil)
    }
    
    func browse(to term: String) {
        guard let tab = selectedTab else {
            return
        }
        browse(to: term, in: tab)
    }
    
    func browse(to term: String, in tab: Tab) {
        let trimmedValue = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return
        }
        
        tab.suppressInitialNavigation = false
        
        let fullRange = NSRange(location: 0, length: (trimmedValue as NSString).length)
        let isURL = isURLLenient.firstMatch(in: trimmedValue, range: fullRange) != nil
        
        if isURL {
            tab.session.load(trimmedValue)
            return
        }
        
        let encodedValue = trimmedValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        tab.session.load("https://www.google.com/search?q=\(encodedValue)")
    }
    
    func tabIndex(for session: GeckoSession) -> Int? {
        tabs.firstIndex(where: { $0.session === session })
    }
    
    func shareableURL(for tab: Tab) -> URL? {
        guard let value = tab.url?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              value.lowercased() != "about:blank",
              let url = URL(string: value),
              let scheme = url.scheme,
              !scheme.isEmpty else {
            return nil
        }
        return url
    }
    
    private func createSession(windowId: String?) -> GeckoSession {
        let session = GeckoSession()
        session.contentDelegate = self
        session.progressDelegate = self
        session.navigationDelegate = self
        session.open(windowId: windowId)
        return session
    }
}

extension TabManagerImplementation: ContentDelegate {
    func onTitleChange(session: GeckoSession, title: String) {
        guard let index = tabIndex(for: session) else {
            return
        }
        
        tabs[index].title = title.isEmpty ? "Homepage" : title
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .title)
    }
    
    func onPreviewImage(session: GeckoSession, previewImageUrl: String) {}
    
    func onFocusRequest(session: GeckoSession) {}
    
    func onCloseRequest(session: GeckoSession) {
        guard let index = tabIndex(for: session) else {
            return
        }
        removeTab(at: index)
    }
    
    func onFullScreen(session: GeckoSession, fullScreen: Bool) {}
    
    func onMetaViewportFitChange(session: GeckoSession, viewportFit: String) {}
    
    func onProductUrl(session: GeckoSession) {}
    
    func onContextMenu(session: GeckoSession, screenX: Int, screenY: Int, element: ContextElement) {}
    
    func onCrash(session: GeckoSession) {
        guard let index = tabIndex(for: session) else {
            return
        }
        removeTab(at: index)
    }
    
    func onKill(session: GeckoSession) {
        guard let index = tabIndex(for: session) else {
            return
        }
        removeTab(at: index)
    }
    
    func onFirstComposite(session: GeckoSession) {}
    
    func onFirstContentfulPaint(session: GeckoSession) {}
    
    func onPaintStatusReset(session: GeckoSession) {}
    
    func onWebAppManifest(session: GeckoSession, manifest: Any) {}
    
    func onSlowScript(session: GeckoSession, scriptFileName: String) async -> SlowScriptResponse {
        .halt
    }
    
    func onShowDynamicToolbar(session: GeckoSession) {}
    
    func onCookieBannerDetected(session: GeckoSession) {}
    
    func onCookieBannerHandled(session: GeckoSession) {}
}

extension TabManagerImplementation: NavigationDelegate {
    func onLocationChange(session: GeckoSession, url: String?, permissions: [ContentPermission]) {
        guard let index = tabIndex(for: session) else {
            return
        }
        
        let normalizedURL = url?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if tabs[index].suppressInitialNavigation,
           let normalizedURL,
           normalizedURL.hasPrefix("about:blank") {
            return
        }
        
        if let normalizedURL, !normalizedURL.isEmpty {
            tabs[index].suppressInitialNavigation = false
        }
        
        tabs[index].url = url
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .location)
    }
    
    func onCanGoBack(session: GeckoSession, canGoBack: Bool) {
        guard let index = tabIndex(for: session) else {
            return
        }
        
        tabs[index].canGoBack = canGoBack
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .navigationState)
    }
    
    func onCanGoForward(session: GeckoSession, canGoForward: Bool) {
        guard let index = tabIndex(for: session) else {
            return
        }
        
        tabs[index].canGoForward = canGoForward
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .navigationState)
    }
    
    func onLoadRequest(session: GeckoSession, request: LoadRequest) async -> AllowOrDeny {
        .allow
    }
    
    func onSubframeLoadRequest(session: GeckoSession, request: LoadRequest) async -> AllowOrDeny {
        .allow
    }
    
    func onNewSession(session: GeckoSession, uri: String) async -> GeckoSession? {
        let index = addTab(selecting: true, windowId: nil)
        let newTab = tabs[index]
        newTab.url = uri
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .location)
        browse(to: uri, in: newTab)
        return newTab.session
    }
}

extension TabManagerImplementation: ProgressDelegate {
    func onPageStart(session: GeckoSession, url: String) {
        guard let index = tabIndex(for: session) else {
            return
        }
        
        tabs[index].isLoading = true
        tabs[index].progress = 0
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .loading)
    }
    
    func onPageStop(session: GeckoSession, success: Bool) {
        guard let index = tabIndex(for: session) else {
            return
        }
        
        tabs[index].isLoading = false
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .loading)
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .thumbnail)
    }
    
    func onProgressChange(session: GeckoSession, progress: Int) {
        guard let index = tabIndex(for: session) else {
            return
        }
        
        tabs[index].progress = Float(progress) / 100
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .loading)
    }
}
