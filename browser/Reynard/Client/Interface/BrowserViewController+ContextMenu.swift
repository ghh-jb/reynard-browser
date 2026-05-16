//
//  BrowserViewController+ContextMenu.swift
//  Reynard
//
//  Created by Minh Ton on 16/5/26.
//

import GeckoView
import ObjectiveC
import UIKit

private enum ContextMenuAssociatedKeys {
    static var pendingContextMenuContext = 0
    static var contextMenuInteraction = 0
    static var contextMenuViewController = 0
    static var isCommittingContextMenu = 0
    static var haptic = 0
}

extension BrowserViewController: UIContextMenuInteractionDelegate {
    var pendingContextMenuContext: ContextMenuContext? {
        get {
            objc_getAssociatedObject(self, &ContextMenuAssociatedKeys.pendingContextMenuContext) as? ContextMenuContext
        }
        set {
            objc_setAssociatedObject(self, &ContextMenuAssociatedKeys.pendingContextMenuContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var contextMenuInteraction: UIContextMenuInteraction? {
        get {
            objc_getAssociatedObject(self, &ContextMenuAssociatedKeys.contextMenuInteraction) as? UIContextMenuInteraction
        }
        set {
            objc_setAssociatedObject(self, &ContextMenuAssociatedKeys.contextMenuInteraction, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private var contextMenuViewController: LinkPreviewViewController? {
        get {
            objc_getAssociatedObject(self, &ContextMenuAssociatedKeys.contextMenuViewController) as? LinkPreviewViewController
        }
        set {
            objc_setAssociatedObject(self, &ContextMenuAssociatedKeys.contextMenuViewController, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private var isCommittingContextMenu: Bool {
        get {
            (objc_getAssociatedObject(self, &ContextMenuAssociatedKeys.isCommittingContextMenu) as? NSNumber)?.boolValue ?? false
        }
        set {
            objc_setAssociatedObject(
                self,
                &ContextMenuAssociatedKeys.isCommittingContextMenu,
                NSNumber(value: newValue),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    private var presentHaptic: UIImpactFeedbackGenerator {
        if let existing = objc_getAssociatedObject(self, &ContextMenuAssociatedKeys.haptic) as? UIImpactFeedbackGenerator {
            return existing
        }
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        objc_setAssociatedObject(self, &ContextMenuAssociatedKeys.haptic, generator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return generator
    }
    
    func configureContextMenu() {
        guard contextMenuInteraction == nil else {
            return
        }
        
        let interaction = UIContextMenuInteraction(delegate: self)
        browserUI.geckoView.addInteraction(interaction)
        contextMenuInteraction = interaction
    }
    
    func presentContextMenu(at point: CGPoint, for url: URL) {
        guard let interaction = contextMenuInteraction else {
            return
        }
        
        presentHaptic.prepare()
        pendingContextMenuContext = ContextMenuContext(url: url, point: point)
        isCommittingContextMenu = false
        
        let selector = NSSelectorFromString("_presentMenuAtLocation:")
        guard interaction.responds(to: selector) else {
            pendingContextMenuContext = nil
            return
        }
        
        presentHaptic.impactOccurred()
        _ = interaction.perform(selector, with: NSValue(cgPoint: point))
    }
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard interaction === contextMenuInteraction,
              let context = pendingContextMenuContext else {
            return nil
        }
        
        return LinkPreviewMenu.configuration(
            for: context,
            onPreviewCreated: { [weak self] preview in
                self?.contextMenuViewController = preview
            },
            openInNewTab: { [weak self] in
                self?.openPreviewInNewTab()
            },
            shareLink: { [weak self] url in
                self?.presentShareSheet(url: url.absoluteString)
            }
        )
    }
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionCommitAnimating
    ) {
        animator.preferredCommitStyle = .pop
        guard interaction === contextMenuInteraction else {
            return
        }
        
        guard let preview = animator.previewViewController as? LinkPreviewViewController,
              let session = preview.releaseSessionForCommit() else {
            return
        }
        
        isCommittingContextMenu = true
        tabManager.replaceSession(with: session, url: preview.pageURL, title: preview.pageTitle)
        contextMenuViewController = nil
        
        animator.addCompletion { [weak self] in
            guard let self else {
                return
            }
            self.isCommittingContextMenu = false
            self.pendingContextMenuContext = nil
        }
    }
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        guard interaction === contextMenuInteraction else {
            return nil
        }
        
        return makeTargetedPreview()
    }
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        guard interaction === contextMenuInteraction else {
            return nil
        }
        
        return makeTargetedPreview()
    }
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        guard interaction === contextMenuInteraction else {
            return
        }
        
        guard let animator else {
            if !isCommittingContextMenu {
                closeContextMenu()
                restoreBrowserTabInteraction()
            } else {
                isCommittingContextMenu = false
            }
            pendingContextMenuContext = nil
            return
        }
        
        animator.addCompletion { [weak self] in
            guard let self else {
                return
            }
            if !self.isCommittingContextMenu {
                self.closeContextMenu()
                self.restoreBrowserTabInteraction()
            } else {
                self.isCommittingContextMenu = false
            }
            self.pendingContextMenuContext = nil
        }
    }
    
    private func openPreviewInNewTab() {
        guard let preview = contextMenuViewController,
              let session = preview.releaseSessionForCommit() else {
            return
        }
        
        isCommittingContextMenu = true
        let selectedIndex = tabManager.selectedTabIndex
        let insertionIndex = selectedIndex >= 0 ? selectedIndex + 1 : tabManager.tabs.count
        tabManager.addTab(
            using: session,
            url: preview.pageURL,
            title: preview.pageTitle,
            selecting: true,
            at: insertionIndex
        )
        contextMenuViewController = nil
    }
    
    private func makeTargetedPreview() -> UITargetedPreview {
        let sourcePoint = pendingContextMenuContext?.point ?? CGPoint(
            x: browserUI.geckoView.bounds.midX,
            y: browserUI.geckoView.bounds.midY
        )
        let target = UIPreviewTarget(container: browserUI.geckoView, center: sourcePoint)
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        view.backgroundColor = .clear
        return UITargetedPreview(view: view, parameters: parameters, target: target)
    }
    
    private func closeContextMenu() {
        contextMenuViewController?.closeSessionIfNeeded()
        contextMenuViewController = nil
    }
    
    private func restoreBrowserTabInteraction() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let session = self.tabManager.selectedTab?.session else {
                return
            }
            
            self.browserUI.geckoView.session = session
            session.setActive(true)
            session.setFocused(true)
        }
    }
}
