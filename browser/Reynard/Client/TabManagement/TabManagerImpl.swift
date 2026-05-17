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
    private(set) var selectedTabIndex = -1
    
    var selectedTab: Tab? {
        tabs[safe: selectedTabIndex]
    }
    
    private weak var delegate: TabManagerDelegate?
    private let store: TabManagementStore
    private let faviconStore: FaviconStore
    private let historyStore: HistoryStore
    private let sessionStore: TabSessionStore
    private var faviconTasks: [UUID: Task<Void, Never>] = [:]
    
    private lazy var isURLLenient: NSRegularExpression = {
        let pattern = "^\\s*(\\w+-+)*[\\w\\[]+(://[/]*|:|\\.)(\\w+-+)*[\\w\\[:]+([\\S&&[^\\w-]]\\S*)?\\s*$"
        return try! NSRegularExpression(pattern: pattern)
    }()
    
    init(
        delegate: TabManagerDelegate?,
        store: TabManagementStore = .shared,
        sessionStore: TabSessionStore = .shared,
        faviconStore: FaviconStore = .shared,
        historyStore: HistoryStore = .shared
    ) {
        self.delegate = delegate
        self.store = store
        self.sessionStore = sessionStore
        self.faviconStore = faviconStore
        self.historyStore = historyStore
    }
    
    private func closeSession(_ session: GeckoSession) {
        if session.isOpen() {
            session.setActive(false)
        }
        session.close()
    }
    
    private func cancelFaviconTask(for tabID: UUID) {
        faviconTasks.removeValue(forKey: tabID)?.cancel()
    }
    
    private func persistState() {
        store.saveTabs(tabs, selectedTabID: selectedTab?.id)
    }
    
    private func loadURL(_ url: String, in tab: Tab) {
        tab.session.updateUserAgent(UserAgentController.shared.userAgent(for: url, tabID: tab.id))
        tab.session.load(url)
    }
    
    private func applyNavigationState(to tab: Tab) {
        let snapshot = sessionStore.loadSnapshot(for: tab.id)
        if snapshot.ownsNav {
            tab.canNavigateBack = snapshot.canGoBack
            tab.canNavigateForward = snapshot.canGoForward
            return
        }
        
        tab.canNavigateBack = snapshot.canGoBack || tab.sessionCanGoBack
        tab.canNavigateForward = snapshot.canGoForward || tab.sessionCanGoForward
    }
    
    private func recordNavigation(_ url: String, for tab: Tab) {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty,
              trimmedURL.lowercased() != "about:blank" else {
            return
        }
        
        let snapshot = sessionStore.recordNavigation(to: trimmedURL, for: tab.id)
        if snapshot.ownsNav {
            tab.canNavigateBack = snapshot.canGoBack
            tab.canNavigateForward = snapshot.canGoForward
            return
        }
        
        tab.canNavigateBack = snapshot.canGoBack || tab.sessionCanGoBack
        tab.canNavigateForward = snapshot.canGoForward || tab.sessionCanGoForward
    }
    
    private func makeTab(windowId: String?) -> Tab {
        let tab = Tab(session: createSession(windowId: windowId))
        let controller = NowPlayingController(session: tab.session)
        tab.session.mediaSessionDelegate = controller
        tab.nowPlayingController = controller
        return tab
    }
    
    private func bindDelegates(to session: GeckoSession, for tab: Tab) {
        session.contentDelegate = self
        session.progressDelegate = self
        session.navigationDelegate = self
        let controller = NowPlayingController(session: session)
        session.mediaSessionDelegate = controller
        tab.nowPlayingController = controller
    }
    
    private func applyTransferredState(to tab: Tab, url: String, title: String?) {
        tab.url = url
        if let title,
           !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tab.title = title
        }
        tab.pendingDisplayText = nil
        tab.suppressInitialNavigation = true
        tab.favicon = cachedFavicon(for: url)
        tab.session.updateUserAgent(UserAgentController.shared.userAgent(for: url, tabID: tab.id))
    }
    
    private func recordTransferredHistory(for tab: Tab, title: String?) {
        guard let url = remoteURL(from: tab.url) else {
            return
        }
        
        historyStore.recordVisit(url: url, title: tab.title)
        if let title,
           !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            historyStore.updateTitle(for: url, title: title)
        }
    }
    
    private func restoredURL(from value: String?) -> String? {
        guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmedValue.isEmpty,
              trimmedValue.lowercased() != "about:blank" else {
            return nil
        }
        
        return trimmedValue
    }
    
    private func remoteURL(from value: String?) -> URL? {
        guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: trimmedValue),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = url.host,
              !host.isEmpty else {
            return nil
        }
        
        return url
    }
    
    private func cachedFavicon(for value: String?) -> UIImage? {
        guard let url = remoteURL(from: value) else {
            return nil
        }
        
        return faviconStore.cachedImage(for: url)
    }
    
    private func scheduleFaviconUpdate(forTabAt index: Int) {
        guard tabs.indices.contains(index) else {
            return
        }
        
        let tab = tabs[index]
        cancelFaviconTask(for: tab.id)
        
        let cachedImage = cachedFavicon(for: tab.url)
        tab.favicon = cachedImage
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .favicon)
        
        guard cachedImage == nil,
              let url = remoteURL(from: tab.url) else {
            return
        }
        
        let tabID = tab.id
        let expectedURL = url.absoluteString
        faviconTasks[tabID] = Task { [weak self] in
            guard let self else {
                return
            }
            
            let image = await self.faviconStore.resolveFavicon(for: url)
            guard !Task.isCancelled else {
                return
            }
            
            await MainActor.run {
                self.applyResolvedFavicon(image, toTabWithID: tabID, expectedURL: expectedURL)
            }
        }
    }
    
    @MainActor
    private func applyResolvedFavicon(_ image: UIImage?, toTabWithID tabID: UUID, expectedURL: String) {
        defer {
            faviconTasks.removeValue(forKey: tabID)
        }
        
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].url == expectedURL else {
            return
        }
        
        tabs[index].favicon = image
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .favicon)
    }
    
    private func restoreTabsIfNeeded() -> Bool {
        guard tabs.isEmpty else {
            return true
        }
        
        let snapshot = store.loadSnapshot()
        guard !snapshot.tabs.isEmpty else {
            return false
        }
        
        tabs = snapshot.tabs.map { snapshot in
            let tab = Tab(
                id: snapshot.id,
                session: createSession(windowId: nil),
                title: snapshot.title,
                url: snapshot.url,
                favicon: cachedFavicon(for: snapshot.url),
                thumbnail: snapshot.thumbnail
            )
            tab.pendingRestoreURL = restoredURL(from: snapshot.url)
            let sessionSnapshot = sessionStore.loadSnapshot(for: tab.id)
            if sessionSnapshot.canGoBack || sessionSnapshot.canGoForward {
                _ = sessionStore.setOwnsNav(true, for: tab.id)
            }
            applyNavigationState(to: tab)
            let controller = NowPlayingController(session: tab.session)
            tab.session.mediaSessionDelegate = controller
            tab.nowPlayingController = controller
            return tab
        }
        selectedTabIndex = -1
        
        delegate?.tabManagerDidChangeTabs(self)
        
        let selectedIndex = snapshot.selectedTabID.flatMap { selectedTabID in
            tabs.firstIndex(where: { $0.id == selectedTabID })
        } ?? 0
        selectTab(at: selectedIndex)
        return true
    }
    
    private func loadRestoredURLIfNeeded(for index: Int) {
        guard tabs.indices.contains(index) else {
            return
        }
        
        let tab = tabs[index]
        guard let url = tab.pendingRestoreURL else {
            return
        }
        
        tab.pendingRestoreURL = nil
        tab.suppressInitialNavigation = false
        loadURL(url, in: tab)
    }
    
    func createInitialTab() {
        if restoreTabsIfNeeded() {
            return
        }
        
        addTab(selecting: true, windowId: nil, at: nil)
    }
    
    @discardableResult
    func addTab(selecting: Bool, windowId: String? = nil, at insertionIndex: Int? = nil) -> Int {
        let tab = makeTab(windowId: windowId)
        let index = min(max(insertionIndex ?? tabs.count, 0), tabs.count)
        
        if index == tabs.count {
            tabs.append(tab)
        } else {
            tabs.insert(tab, at: index)
            if selectedTabIndex >= index {
                selectedTabIndex += 1
            }
        }
        
        delegate?.tabManagerDidChangeTabs(self)
        
        if selecting {
            selectTab(at: index)
        } else {
            persistState()
        }
        
        return index
    }
    
    @discardableResult
    func addTab(using session: GeckoSession, url: String, title: String?, selecting: Bool, at insertionIndex: Int?) -> Int {
        let tab = Tab(session: session)
        bindDelegates(to: session, for: tab)
        applyTransferredState(to: tab, url: url, title: title)
        recordNavigation(url, for: tab)
        
        let index = min(max(insertionIndex ?? tabs.count, 0), tabs.count)
        if index == tabs.count {
            tabs.append(tab)
        } else {
            tabs.insert(tab, at: index)
            if selectedTabIndex >= index {
                selectedTabIndex += 1
            }
        }
        
        delegate?.tabManagerDidChangeTabs(self)
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .location)
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .title)
        scheduleFaviconUpdate(forTabAt: index)
        recordTransferredHistory(for: tab, title: title)
        
        if selecting {
            delegate?.tabManager(self, animateNewTabSelectionAt: index) { [weak self] in
                self?.selectTab(at: index)
            }
            session.setFocused(true)
        } else {
            persistState()
        }
        
        return index
    }
    
    func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else {
            return
        }
        
        let previousIndex = tabs.indices.contains(selectedTabIndex) ? selectedTabIndex : nil
        
        selectedTabIndex = index
        tabs[index].session.setActive(true)
        applyNavigationState(to: tabs[index])
        
        delegate?.tabManager(self, didSelectTabAt: index, previousIndex: previousIndex)
        loadRestoredURLIfNeeded(for: index)
        persistState()
    }
    
    func moveTab(from sourceIndex: Int, to destinationIndex: Int) {
        guard tabs.indices.contains(sourceIndex),
              tabs.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else {
            return
        }
        
        let selectedTabID = selectedTab?.id
        let movedTab = tabs.remove(at: sourceIndex)
        tabs.insert(movedTab, at: destinationIndex)
        
        if let selectedTabID,
           let selectedIndex = tabs.firstIndex(where: { $0.id == selectedTabID }) {
            selectedTabIndex = selectedIndex
        }
        
        persistState()
    }
    
    func removeTab(at index: Int) {
        guard tabs.indices.contains(index) else {
            return
        }
        
        let wasSelected = index == selectedTabIndex
        let removedTab = tabs.remove(at: index)
        cancelFaviconTask(for: removedTab.id)
        UserAgentController.shared.clearOverrides(forTabID: removedTab.id)
        sessionStore.removeSession(for: removedTab.id)
        
        if tabs.isEmpty {
            selectedTabIndex = -1
            delegate?.tabManagerDidChangeTabs(self)
            addTab(selecting: true, windowId: nil, at: nil)
            closeSession(removedTab.session)
            return
        }
        
        if wasSelected {
            selectedTabIndex = -1
        } else if index < selectedTabIndex {
            selectedTabIndex -= 1
        }
        
        delegate?.tabManagerDidChangeTabs(self)
        
        if wasSelected {
            let fallback = min(index, tabs.count - 1)
            selectTab(at: fallback)
        } else {
            persistState()
        }
        
        closeSession(removedTab.session)
    }
    
    func removeAllTabs() {
        guard !tabs.isEmpty else {
            return
        }
        
        let removedTabs = tabs
        tabs.removeAll(keepingCapacity: true)
        removedTabs.forEach { cancelFaviconTask(for: $0.id) }
        removedTabs.forEach { UserAgentController.shared.clearOverrides(forTabID: $0.id) }
        removedTabs.forEach { sessionStore.removeSession(for: $0.id) }
        selectedTabIndex = -1
        delegate?.tabManagerDidChangeTabs(self)
        addTab(selecting: true, windowId: nil)
        
        removedTabs.forEach { closeSession($0.session) }
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
        tab.pendingDisplayText = trimmedValue
        
        let fullRange = NSRange(location: 0, length: (trimmedValue as NSString).length)
        let isURL = isURLLenient.firstMatch(in: trimmedValue, range: fullRange) != nil
        
        if isURL {
            loadURL(trimmedValue, in: tab)
            return
        }
        
        let searchTarget = searchURL(for: trimmedValue)
        loadURL(searchTarget, in: tab)
    }
    
    func goBack() {
        guard let tab = selectedTab else {
            return
        }
        
        let snapshot = sessionStore.loadSnapshot(for: tab.id)
        if !snapshot.ownsNav && tab.sessionCanGoBack {
            _ = sessionStore.previousURL(for: tab.id)
            applyNavigationState(to: tab)
            delegate?.tabManager(self, didUpdateTabAt: selectedTabIndex, reason: .navigationState)
            tab.session.goBack()
            return
        }
        
        guard let url = sessionStore.previousURL(for: tab.id) else {
            return
        }
        
        _ = sessionStore.setOwnsNav(true, for: tab.id)
        applyNavigationState(to: tab)
        delegate?.tabManager(self, didUpdateTabAt: selectedTabIndex, reason: .navigationState)
        loadURL(url, in: tab)
    }
    
    func goForward() {
        guard let tab = selectedTab else {
            return
        }
        
        let snapshot = sessionStore.loadSnapshot(for: tab.id)
        if !snapshot.ownsNav && tab.sessionCanGoForward {
            _ = sessionStore.nextURL(for: tab.id)
            applyNavigationState(to: tab)
            delegate?.tabManager(self, didUpdateTabAt: selectedTabIndex, reason: .navigationState)
            tab.session.goForward()
            return
        }
        
        guard let url = sessionStore.nextURL(for: tab.id) else {
            return
        }
        
        _ = sessionStore.setOwnsNav(true, for: tab.id)
        applyNavigationState(to: tab)
        delegate?.tabManager(self, didUpdateTabAt: selectedTabIndex, reason: .navigationState)
        loadURL(url, in: tab)
    }
    
    func replaceSession(with session: GeckoSession, url: String, title: String?) {
        guard let tab = selectedTab else {
            return
        }
        
        let oldSession = tab.session
        oldSession.setActive(false)
        oldSession.close()
        
        bindDelegates(to: session, for: tab)
        tab.session = session
        applyTransferredState(to: tab, url: url, title: title)
        tab.sessionCanGoBack = false
        tab.sessionCanGoForward = false
        recordNavigation(url, for: tab)
        _ = sessionStore.setOwnsNav(true, for: tab.id)
        applyNavigationState(to: tab)
        session.setActive(true)
        session.setFocused(true)
        
        delegate?.tabManagerDidChangeTabs(self)
        delegate?.tabManager(self, didUpdateTabAt: selectedTabIndex, reason: .location)
        delegate?.tabManager(self, didUpdateTabAt: selectedTabIndex, reason: .title)
        scheduleFaviconUpdate(forTabAt: selectedTabIndex)
        persistState()
        recordTransferredHistory(for: tab, title: title)
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
    
    func updateThumbnail(_ image: UIImage?, forTabAt index: Int) {
        guard tabs.indices.contains(index) else {
            return
        }
        
        let tab = tabs[index]
        tab.thumbnail = image
        store.saveThumbnail(image, for: tab.id)
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
        
        tabs[index].title = title
        if let url = remoteURL(from: tabs[index].url) {
            historyStore.updateTitle(for: url, title: title)
        }
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .title)
        persistState()
    }
    
    func onPreviewImage(session: GeckoSession, previewImageUrl: String) {}
    
    func onFocusRequest(session: GeckoSession) {
        guard selectedTab?.session === session else {
            return
        }
        
        session.setActive(true)
        session.setFocused(true)
    }
    
    func onCloseRequest(session: GeckoSession) {
        guard let index = tabIndex(for: session) else {
            return
        }
        removeTab(at: index)
    }
    
    func onFullScreen(session: GeckoSession, fullScreen: Bool) {
        guard selectedTab?.session === session else {
            return
        }
        
        delegate?.tabManager(self, didChangeFullscreen: fullScreen, for: session)
    }
    
    func onMetaViewportFitChange(session: GeckoSession, viewportFit: String) {}
    
    func onProductUrl(session: GeckoSession) {}
    
    func onContextMenu(session: GeckoSession, screenX: Int, screenY: Int, element: ContextElement) {
        guard selectedTab?.session === session else {
            return
        }
        
        let hasImageSource = element.type == .image && element.srcUri?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasLink = element.linkUri?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        guard hasImageSource || hasLink else {
            return
        }
        
        delegate?.tabManager(self, didRequestContextMenuAt: CGPoint(x: screenX, y: screenY), for: element, in: session)
    }
    
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
    
    func onExternalResponse(session: GeckoSession, response: ExternalResponseInfo) {
        if delegate?.tabManager(self, shouldHandleExternalResponse: response, for: session) == true {
            return
        }
        guard let download = DownloadStore.shared.prepareDownload(from: response) else {
            return
        }
        
        delegate?.tabManager(self, didRequestDownload: download)
    }
    
    func onSavePdf(session: GeckoSession, request: SavePdfInfo) {
        guard let download = DownloadStore.shared.prepareDownload(from: request) else {
            return
        }
        
        delegate?.tabManager(self, didRequestDownload: download)
    }
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
        
        if let url {
            session.updateUserAgent(UserAgentController.shared.userAgent(for: url, tabID: tabs[index].id))
        }
        
        tabs[index].url = url
        if let url {
            recordNavigation(url, for: tabs[index])
        }
        tabs[index].pendingDisplayText = nil
        tabs[index].favicon = nil
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .location)
        scheduleFaviconUpdate(forTabAt: index)
        persistState()
        
        guard let url = remoteURL(from: tabs[index].url) else {
            return
        }
        
        historyStore.recordVisit(url: url, title: tabs[index].title)
    }
    
    func onCanGoBack(session: GeckoSession, canGoBack: Bool) {
        guard let index = tabIndex(for: session) else {
            return
        }
        
        tabs[index].sessionCanGoBack = canGoBack
        applyNavigationState(to: tabs[index])
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .navigationState)
    }
    
    func onCanGoForward(session: GeckoSession, canGoForward: Bool) {
        guard let index = tabIndex(for: session) else {
            return
        }
        
        tabs[index].sessionCanGoForward = canGoForward
        applyNavigationState(to: tabs[index])
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .navigationState)
    }
    
    func onLoadRequest(session: GeckoSession, request: LoadRequest) async -> AllowOrDeny {
        .allow
    }
    
    func onSubframeLoadRequest(session: GeckoSession, request: LoadRequest) async -> AllowOrDeny {
        .allow
    }
    
    func onNewSession(session: GeckoSession, uri: String, windowId: String) async -> GeckoSession? {
        let newSession = GeckoSession()
        newSession.contentDelegate = self
        newSession.progressDelegate = self
        newSession.navigationDelegate = self
        
        let newTab = Tab(session: newSession)
        newSession.userAgentOverride = UserAgentController.shared.userAgent(for: uri, tabID: newTab.id)
        let controller = NowPlayingController(session: newSession)
        newSession.mediaSessionDelegate = controller
        newTab.nowPlayingController = controller
        newTab.url = uri
        newTab.favicon = cachedFavicon(for: uri)
        recordNavigation(uri, for: newTab)
        
        let insertionIndex = tabIndex(for: session).map { $0 + 1 }
        let index = min(max(insertionIndex ?? tabs.count, 0), tabs.count)
        if index == tabs.count {
            tabs.append(newTab)
        } else {
            tabs.insert(newTab, at: index)
            if selectedTabIndex >= index {
                selectedTabIndex += 1
            }
        }
        
        delegate?.tabManagerDidChangeTabs(self)
        delegate?.tabManager(self, didUpdateTabAt: index, reason: .location)
        scheduleFaviconUpdate(forTabAt: index)
        persistState()
        delegate?.tabManager(self, animateNewTabSelectionAt: index) { [weak self] in
            self?.selectTab(at: index)
        }
        return newSession
    }
}

extension TabManagerImplementation: ProgressDelegate {
    func onPageStart(session: GeckoSession, url: String) {
        guard let index = tabIndex(for: session) else {
            return
        }
        
        let currentHost = tabs[index].url.flatMap { UserAgentController.shared.extractHost(from: $0) }
        let requestedHost = UserAgentController.shared.extractHost(from: url)
        let desiredUserAgent = UserAgentController.shared.userAgent(for: url, tabID: tabs[index].id)
        
        if currentHost != nil,
           requestedHost != nil,
           currentHost != requestedHost,
           desiredUserAgent != session.userAgentOverride {
            loadURL(url, in: tabs[index])
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
