//
//  HomepageOverlayCoordinator.swift
//  Reynard
//
//  Created by Minh Ton on 21/6/26.
//

import UIKit

protocol HomepageOverlayCoordinatorDelegate: AnyObject {
    var homepageLayout: BrowserLayout { get }
    var homepageGridWidth: HomepageGridWidth { get }
    var homepageSelectedTab: Tab? { get }
    var isHomepageTabOverviewPresented: Bool { get }
    var isHomepageShowingFullscreenMedia: Bool { get }
    var homepageChrome: BrowserChrome { get }
    var homepageContentView: ContentView { get }
    
    // Homepage section actions
    func browseURLFromHomepage(_ url: URL)
    func openSettingsFromHomepage()
    func restoreClosedTabFromHomepage(id: UUID) -> Bool
    
    func endHomepageEditing()
    func updateHomepageThumbnailFromCachedSnapshot()
    func updateHomepageLayout(animated: Bool, duration: TimeInterval)
}

final class HomepageOverlayCoordinator {
    private enum UX {
        static let layoutAnimationDuration: TimeInterval = 0.2
        static let snapshotRefreshDelay: TimeInterval = 0.45
        static let snapshotMaximumWidth: CGFloat = 360 // TODO: Improve for multiple device size
    }
    
    private weak var delegate: HomepageOverlayCoordinatorDelegate?
    private let overlayCoordinator: OverlayCoordinator
    private let homepageViewController: HomepageViewController
    private var presentationIntent: HomepagePresentationIntent = .inactive
    private var snapshotCache: HomepageSnapshotCache?
    private var isSnapshotDirty = true
    private var isSnapshotRefreshPaused = false
    private var snapshotRefreshWorkItem: DispatchWorkItem?
    
    private struct HomepagePresentation: Equatable {
        let host: OverlayCoordinator.Host
        let contentMode: HomepageContentMode
    }
    
    // MARK: - Lifecycle
    
    init(delegate: HomepageOverlayCoordinatorDelegate, overlayCoordinator: OverlayCoordinator) {
        self.delegate = delegate
        self.overlayCoordinator = overlayCoordinator
        homepageViewController = HomepageViewController()
        homepageViewController.homepageDelegate = self
        homepageViewController.setPrivateBrowsing(isPrivateBrowsing)
        observeHomepageChanges()
    }
    
    deinit {
        snapshotRefreshWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - State
    
    func updatePresentation(animated: Bool) {
        guard let presentation = homepagePresentation else {
            dismiss(animated: animated)
            return
        }
        
        presentHomepage(presentation, animated: animated)
    }
    
    func updatePresentedLayout() {
        guard let presentation = homepagePresentation,
              overlayCoordinator.contains(.homepage, on: presentation.host) else {
            return
        }
        
        homepageViewController.setPrivateBrowsing(isPrivateBrowsing)
        homepageViewController.setContentMode(presentation.contentMode)
        configureOverlay(for: presentation)
        markSnapshotDirty()
    }
    
    func tabOverviewWillPresent() {
        guard !showsHomepageForBlankTabs || !isSelectedTabBlankPage else {
            return
        }
        
        dismiss(animated: false)
    }
    
    func resetPresentationSession() {
        presentationIntent = .inactive
        overlayCoordinator.clearAddressBarScrollDismissal(for: .homepage)
    }
    
    // MARK: - Snapshot
    
    private func renderSnapshot(size: CGSize, isPrivateBrowsing: Bool) -> UIImage? {
        guard let delegate,
              size.width > 1,
              size.height > 1 else {
            return nil
        }
        
        let scale = UIScreen.main.scale
        let outputSize = snapshotOutputSize(for: size)
        let pixelSize = CGSize(width: outputSize.width * scale, height: outputSize.height * scale)
        let contentMode = embeddedContentMode(layout: delegate.homepageLayout)
        let userInterfaceStyle = homepageViewController.traitCollection.userInterfaceStyle
        if let snapshotCache,
           snapshotCache.matches(
            pixelSize: pixelSize,
            contentMode: contentMode,
            isPrivateBrowsing: isPrivateBrowsing,
            userInterfaceStyle: userInterfaceStyle
           ) {
            return snapshotCache.image
        }
        
        homepageViewController.setPrivateBrowsing(isPrivateBrowsing)
        guard let image = homepageViewController.renderSnapshot(
            size: size,
            outputSize: outputSize,
            contentMode: contentMode
        ) else {
            return nil
        }
        
        snapshotCache = HomepageSnapshotCache(
            pixelSize: pixelSize,
            contentMode: contentMode,
            isPrivateBrowsing: isPrivateBrowsing,
            userInterfaceStyle: userInterfaceStyle,
            image: image
        )
        isSnapshotDirty = false
        return image
    }
    
    private func scheduleSnapshotRefreshIfNeeded() {
        guard isSnapshotDirty,
              !isSnapshotRefreshPaused,
              snapshotSize != nil,
              isSelectedTabBlankPage else {
            return
        }
        
        snapshotRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshSnapshotCache()
        }
        snapshotRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + UX.snapshotRefreshDelay,
            execute: workItem
        )
    }
    
    private func refreshSnapshotCache() {
        snapshotRefreshWorkItem = nil
        guard isSelectedTabBlankPage,
              let size = snapshotSize else {
            return
        }
        
        snapshotCache = nil
        guard renderSnapshot(size: size, isPrivateBrowsing: isPrivateBrowsing) != nil else {
            return
        }
        
        delegate?.updateHomepageThumbnailFromCachedSnapshot()
    }
    
    private var snapshotSize: CGSize? {
        guard let size = delegate?.homepageContentView.bounds.size,
              size.width > 1,
              size.height > 1 else {
            return nil
        }
        
        return size
    }
    
    private func snapshotOutputSize(for size: CGSize) -> CGSize {
        let scale = min(1, UX.snapshotMaximumWidth / size.width)
        return CGSize(
            width: floor(size.width * scale),
            height: floor(size.height * scale)
        )
    }
    
    func snapshotForBlankTab(_ tab: Tab, size: CGSize) -> UIImage? {
        guard showsHomepageForBlankTabs,
              isBlankTab(tab) else {
            return nil
        }
        
        if isSnapshotDirty {
            scheduleSnapshotRefreshIfNeeded()
        }
        
        if let snapshotCache {
            return snapshotCache.image
        }
        
        return renderSnapshot(size: size, isPrivateBrowsing: tab.isPrivate)
    }
    
    // MARK: - Presentation
    
    private func presentHomepage(_ presentation: HomepagePresentation, animated: Bool) {
        overlayCoordinator.dismiss(.homepage, on: otherHost(from: presentation.host), animated: false)
        
        guard !overlayCoordinator.contains(.homepage, on: presentation.host),
              !overlayCoordinator.isPresented(.search, on: presentation.host) else {
            homepageViewController.setPrivateBrowsing(isPrivateBrowsing)
            homepageViewController.setContentMode(presentation.contentMode)
            homepageViewController.prepareForPresentation(resetNavigation: false)
            configureOverlay(for: presentation)
            markSnapshotDirty()
            return
        }
        
        overlayCoordinator.present(
            homepageViewController,
            for: .homepage,
            on: presentation.host,
            animated: animated
        ) { [weak self] in
            self?.homepageViewController.setPrivateBrowsing(self?.isPrivateBrowsing == true)
            self?.homepageViewController.setContentMode(presentation.contentMode)
            self?.homepageViewController.prepareForPresentation(resetNavigation: true)
            self?.configureOverlay(for: presentation)
            self?.markSnapshotDirty()
        }
    }
    
    private func dismiss(animated: Bool) {
        overlayCoordinator.dismiss(.homepage, on: .embedded, animated: animated)
        overlayCoordinator.dismiss(.homepage, on: .detached, animated: animated)
    }
    
    private func configureOverlay(for presentation: HomepagePresentation) {
        guard presentation.host == .detached,
              let delegate else {
            return
        }
        
        delegate.homepageChrome.setOverlayHeightMode(.default)
        delegate.homepageChrome.setOverlayAvailableContentHeight(delegate.homepageContentView.bounds.height)
    }
    
    private func markSnapshotDirty() {
        isSnapshotDirty = true
        scheduleSnapshotRefreshIfNeeded()
    }
    
    func setSnapshotRefreshPaused(_ paused: Bool) {
        guard isSnapshotRefreshPaused != paused else {
            return
        }
        
        isSnapshotRefreshPaused = paused
        if paused {
            snapshotRefreshWorkItem?.cancel()
            snapshotRefreshWorkItem = nil
            return
        }
        
        scheduleSnapshotRefreshIfNeeded()
    }
    
    // MARK: - Presentation Resolution
    
    private var homepagePresentation: HomepagePresentation? {
        guard let delegate,
              !delegate.isHomepageShowingFullscreenMedia else {
            return nil
        }
        
        if showsHomepageForBlankTabs && isSelectedTabBlankPage {
            return HomepagePresentation(
                host: .embedded,
                contentMode: embeddedContentMode(layout: delegate.homepageLayout)
            )
        }
        
        guard !delegate.isHomepageTabOverviewPresented else {
            return nil
        }
        
        guard presentationIntent == .addressBarFocus else {
            return nil
        }
        
        return presentationForFocusedAddressBar(
            layout: delegate.homepageLayout,
            gridWidth: delegate.homepageGridWidth
        )
    }
    
    private var isSelectedTabBlankPage: Bool {
        guard let tab = delegate?.homepageSelectedTab else {
            return false
        }
        
        return isBlankTab(tab)
    }
    
    private var isPrivateBrowsing: Bool {
        return delegate?.homepageSelectedTab?.isPrivate == true
    }
    
    private var showsHomepageForBlankTabs: Bool {
        return Prefs.NewTabSettings.newTabDisplayOption == .homepage
    }
    
    private func isBlankTab(_ tab: Tab) -> Bool {
        if case let .pending(value) = tab.state.displayState {
            return isBlankURL(value)
        }
        
        return isBlankURL(tab.url)
    }
    
    private func isBlankURL(_ urlString: String?) -> Bool {
        guard let urlString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty else {
            return true
        }
        
        return urlString.lowercased().hasPrefix("about:blank")
    }
    
    private func presentationForFocusedAddressBar(
        layout: BrowserLayout,
        gridWidth: HomepageGridWidth
    ) -> HomepagePresentation? {
        if layout.interfaceIdiom == .pad,
           gridWidth == .fourColumn {
            return HomepagePresentation(
                host: .embedded,
                contentMode: embeddedContentMode(layout: layout)
            )
        }
        
        switch (layout.interfaceIdiom, layout.chromeMode, layout.orientation) {
        case (.phone, _, .portrait), (.pad, .compact, _):
            return HomepagePresentation(
                host: .embedded,
                contentMode: embeddedContentMode(layout: layout)
            )
        case (.phone, _, .landscape), (.pad, .pad, _):
            return HomepagePresentation(
                host: .detached,
                contentMode: HomepageContentMode.detached(layout: layout)
            )
        default:
            return nil
        }
    }
    
    private func embeddedContentMode(layout: BrowserLayout) -> HomepageContentMode {
        guard let delegate else {
            return HomepageContentMode.embedded(layout: layout)
        }
        
        return HomepageContentMode.embedded(
            layout: layout,
            gridWidth: delegate.homepageGridWidth
        )
    }
    
    private func otherHost(from host: OverlayCoordinator.Host) -> OverlayCoordinator.Host {
        switch host {
        case .embedded:
            return .detached
        case .detached:
            return .embedded
        }
    }
    
    // MARK: - Bookmarks
    
    private func observeHomepageChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(bookmarksDidChange),
            name: .bookmarkStoreDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(homepageSettingsDidChange),
            name: .homepageSettingsDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(historyDidChange),
            name: .historyStoreDidChange,
            object: nil
        )
    }
    
    @objc private func bookmarksDidChange() {
        markSnapshotDirty()
    }
    
    @objc private func homepageSettingsDidChange() {
        markSnapshotDirty()
    }
    
    @objc private func historyDidChange() {
        markSnapshotDirty()
    }
}

private enum HomepagePresentationIntent {
    case inactive
    case addressBarFocus
}

// MARK: - Address Bar Search Delegate

extension HomepageOverlayCoordinator: AddressBarSearchDelegate {
    func addressBarDidSubmit(_ searchTerm: String) {}
    
    func addressBarDidTapDismiss(_ addressBar: AddressBar) {
        if overlayCoordinator.endAddressBarScrollDismissal(for: .homepage) {
            presentationIntent = .inactive
            delegate?.updateHomepageLayout(animated: true, duration: UX.layoutAnimationDuration)
            updatePresentation(animated: true)
            return
        }
        
        presentationIntent = .inactive
        overlayCoordinator.clearAddressBarScrollDismissal(for: .homepage)
        updatePresentation(animated: true)
    }
    
    func addressBarDidBeginEditing(_ addressBar: AddressBar) {
        overlayCoordinator.clearAddressBarScrollDismissal(for: .homepage)
        presentationIntent = isSelectedTabBlankPage ? .inactive : .addressBarFocus
        updatePresentation(animated: true)
    }
    
    func addressBarDidEndEditing(_ addressBar: AddressBar) {
        if overlayCoordinator.consumeAddressBarScrollDismissal(for: .homepage) {
            delegate?.updateHomepageLayout(animated: false, duration: UX.layoutAnimationDuration)
            return
        }
        
        presentationIntent = .inactive
        updatePresentation(animated: true)
    }
    
    func addressBar(_ addressBar: AddressBar, didChangeText text: String, previousText: String, isDelete: Bool) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            updatePresentation(animated: true)
            return
        }
    }
}

// MARK: - Homepage View Controller Delegate

extension HomepageOverlayCoordinator: HomepageViewControllerDelegate {
    func homepageViewController(_ controller: HomepageViewController, didSelectURL url: URL) {
        overlayCoordinator.clearAddressBarScrollDismissal(for: .homepage)
        delegate?.browseURLFromHomepage(url)
        delegate?.endHomepageEditing()
        presentationIntent = .inactive
        dismiss(animated: true)
    }
    
    func homepageViewController(_ controller: HomepageViewController, didSelectRecentlyClosedTab id: UUID) {
        overlayCoordinator.clearAddressBarScrollDismissal(for: .homepage)
        guard delegate?.restoreClosedTabFromHomepage(id: id) == true else {
            return
        }
        
        delegate?.endHomepageEditing()
        presentationIntent = .inactive
        dismiss(animated: true)
    }
    
    func homepageViewControllerDidSelectSettings(_ controller: HomepageViewController) {
        overlayCoordinator.clearAddressBarScrollDismissal(for: .homepage)
        delegate?.openSettingsFromHomepage()
        delegate?.endHomepageEditing()
    }
    
    func homepageViewControllerDidChangeLayout(_ controller: HomepageViewController) {
        markSnapshotDirty()
    }
    
    func homepageViewControllerDidStartScrolling() {
        guard overlayCoordinator.beginAddressBarScrollDismissal(for: .homepage) else {
            return
        }
        
        delegate?.updateHomepageLayout(animated: false, duration: UX.layoutAnimationDuration)
    }
}
