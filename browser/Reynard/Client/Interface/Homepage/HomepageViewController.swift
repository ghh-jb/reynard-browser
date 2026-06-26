//
//  HomepageViewController.swift
//  Reynard
//
//  Created by Minh Ton on 21/6/26.
//

import UIKit

protocol HomepageViewControllerDelegate: AnyObject {
    func homepageViewController(_ controller: HomepageViewController, didSelectURL url: URL)
    func homepageViewController(_ controller: HomepageViewController, didSelectRecentlyClosedTab id: UUID)
    func homepageViewControllerDidChangeLayout(_ controller: HomepageViewController)
    func homepageViewControllerDidSelectSettings(_ controller: HomepageViewController)
    func homepageViewControllerDidStartScrolling()
}

final class HomepageViewController: UINavigationController {
    weak var homepageDelegate: HomepageViewControllerDelegate?
    
    private let rootViewController: HomepageRootViewController
    private let bookmarkStore: BookmarkStore
    private var isPrivateBrowsing: Bool
    private var contentMode: HomepageContentMode = .embeddedNarrow
    
    // MARK: - Lifecycle
    
    init(bookmarkStore: BookmarkStore = .shared, isPrivateBrowsing: Bool = false) {
        self.bookmarkStore = bookmarkStore
        self.isPrivateBrowsing = isPrivateBrowsing
        rootViewController = HomepageRootViewController(
            bookmarkStore: bookmarkStore,
            isPrivateBrowsing: isPrivateBrowsing
        )
        super.init(rootViewController: rootViewController)
        rootViewController.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
    }
    
    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        super.setViewControllers(viewControllers, animated: animated)
        viewControllers.forEach { viewController in
            (viewController as? HomepageRootViewController)?.delegate = self
        }
    }
    
    // MARK: - Public API
    
    func setContentMode(_ contentMode: HomepageContentMode) {
        self.contentMode = contentMode
        viewControllers.forEach { viewController in
            (viewController as? HomepageRootViewController)?.setContentMode(contentMode)
        }
    }
    
    func setPrivateBrowsing(_ isPrivateBrowsing: Bool) {
        guard self.isPrivateBrowsing != isPrivateBrowsing else {
            return
        }
        
        self.isPrivateBrowsing = isPrivateBrowsing
        viewControllers.forEach { viewController in
            (viewController as? HomepageRootViewController)?.setPrivateBrowsing(isPrivateBrowsing)
        }
    }
    
    func prepareForPresentation(resetNavigation: Bool) {
        loadViewIfNeeded()
        if resetNavigation {
            popToRootViewController(animated: false)
            rootViewController.resetScrollPosition()
        }
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    func renderSnapshot(size: CGSize, outputSize: CGSize, contentMode: HomepageContentMode) -> UIImage? {
        loadViewIfNeeded()
        setContentMode(contentMode)
        guard outputSize.width > 1,
              outputSize.height > 1 else {
            return nil
        }
        
        let wasAttached = view.superview != nil
        let originalFrame = view.frame
        let snapshotContainer = UIView(frame: CGRect(origin: .zero, size: size))
        
        if !wasAttached {
            snapshotContainer.addSubview(view)
            view.frame = snapshotContainer.bounds
        }
        
        view.layoutIfNeeded()
        
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        let image = renderer.image { context in
            context.cgContext.scaleBy(
                x: outputSize.width / size.width,
                y: outputSize.height / size.height
            )
            view.layer.render(in: context.cgContext)
        }
        
        if !wasAttached {
            view.removeFromSuperview()
        }
        view.frame = originalFrame
        return image
    }
    
    // MARK: - Configuration
    
    private func configureAppearance() {
        view.backgroundColor = .clear
        delegate = self
        navigationBar.isTranslucent = false
        setNavigationBarHidden(true, animated: false)
    }
}

extension HomepageViewController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        setNavigationBarHidden(viewController === rootViewController, animated: false)
    }
}

extension HomepageViewController: HomepageRootViewControllerDelegate {
    func homepageRootViewController(_ controller: HomepageRootViewController, didSelectURL url: URL) {
        homepageDelegate?.homepageViewController(self, didSelectURL: url)
    }
    
    func homepageRootViewController(_ controller: HomepageRootViewController, didSelectRecentlyClosedTab id: UUID) {
        homepageDelegate?.homepageViewController(self, didSelectRecentlyClosedTab: id)
    }
    
    func homepageRootViewControllerDidChangeLayout(_ controller: HomepageRootViewController) {
        homepageDelegate?.homepageViewControllerDidChangeLayout(self)
    }
    
    func homepageRootViewControllerDidSelectSettings(_ controller: HomepageRootViewController) {
        homepageDelegate?.homepageViewControllerDidSelectSettings(self)
    }
    
    func homepageRootViewControllerDidSelectFolder(_ folder: BookmarkFolderSnapshot) {
        let viewController = HomepageRootViewController(
            bookmarkStore: bookmarkStore,
            folder: folder,
            sections: [.favorites],
            isPrivateBrowsing: isPrivateBrowsing
        )
        viewController.delegate = self
        viewController.setContentMode(contentMode)
        setNavigationBarHidden(false, animated: false)
        pushViewController(viewController, animated: true)
    }
    
    func homepageRootViewControllerDidStartScrolling() {
        homepageDelegate?.homepageViewControllerDidStartScrolling()
    }
}
