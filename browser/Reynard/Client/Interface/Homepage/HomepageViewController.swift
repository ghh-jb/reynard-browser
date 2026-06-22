//
//  HomepageViewController.swift
//  Reynard
//
//  Created by Minh Ton on 21/6/26.
//

import UIKit

protocol HomepageViewControllerDelegate: AnyObject {
    func homepageViewControllerDidSelectFavorite(_ favorite: BookmarkSnapshot)
    func homepageViewControllerDidStartScrolling()
}

final class HomepageViewController: UINavigationController {
    weak var homepageDelegate: HomepageViewControllerDelegate? {
        didSet {
            rootViewController.delegate = homepageDelegate
        }
    }
    
    private let rootViewController: HomepageRootViewController
    
    // MARK: - Lifecycle
    
    init(bookmarkStore: BookmarkStore = .shared) {
        rootViewController = HomepageRootViewController(bookmarkStore: bookmarkStore)
        super.init(rootViewController: rootViewController)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
    }
    
    // MARK: - Public API
    
    func setContentMode(_ contentMode: HomepageContentMode) {
        rootViewController.setContentMode(contentMode)
    }
    
    func prepareForPresentation() {
        loadViewIfNeeded()
        rootViewController.resetScrollPosition()
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    func renderSnapshot(size: CGSize, contentMode: HomepageContentMode) -> UIImage? {
        loadViewIfNeeded()
        setContentMode(contentMode)
        
        let wasAttached = view.superview != nil
        let originalFrame = view.frame
        let snapshotContainer = UIView(frame: CGRect(origin: .zero, size: size))
        
        if !wasAttached {
            snapshotContainer.addSubview(view)
            view.frame = snapshotContainer.bounds
        }
        
        view.layoutIfNeeded()
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
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
        isNavigationBarHidden = true
    }
}
