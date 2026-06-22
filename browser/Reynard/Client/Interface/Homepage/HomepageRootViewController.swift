//
//  HomepageRootViewController.swift
//  Reynard
//
//  Created by Minh Ton on 21/6/26.
//

import UIKit

final class HomepageRootViewController: UIViewController {
    private enum UX {
        static let topInset: CGFloat = 48
        static let horizontalInset: CGFloat = 16
        static let bottomInset: CGFloat = 24
    }
    
    weak var delegate: HomepageViewControllerDelegate?
    
    private let bookmarkStore: BookmarkStore
    private var contentMode: HomepageContentMode = .embeddedNarrow
    private var sectionViewControllers: [HomepageSection: UIViewController] = [:]
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        scrollView.keyboardDismissMode = .none
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let sectionStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        return stackView
    }()
    
    // MARK: - Lifecycle
    
    init(bookmarkStore: BookmarkStore) {
        self.bookmarkStore = bookmarkStore
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureScrollView()
        configureHierarchy()
        configureConstraints()
        configureSections()
    }
    
    // MARK: - Public API
    
    func setContentMode(_ contentMode: HomepageContentMode) {
        guard self.contentMode != contentMode else {
            return
        }
        
        self.contentMode = contentMode
        favoritesSectionViewController?.setContentMode(contentMode)
    }
    
    func resetScrollPosition() {
        loadViewIfNeeded()
        scrollView.setContentOffset(
            CGPoint(x: 0, y: -scrollView.adjustedContentInset.top),
            animated: false
        )
    }
    
    // MARK: - Configuration
    
    private func configureScrollView() {
        scrollView.delegate = self
        scrollView.contentInset = UIEdgeInsets(
            top: UX.topInset,
            left: 0,
            bottom: UX.bottomInset,
            right: 0
        )
        scrollView.scrollIndicatorInsets = scrollView.contentInset
    }
    
    private func configureHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(sectionStackView)
    }
    
    private func configureConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            sectionStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            sectionStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: UX.horizontalInset),
            sectionStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -UX.horizontalInset),
            sectionStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            sectionStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -(UX.horizontalInset * 2)),
        ])
    }
    
    private func configureSections() {
        HomepageSection.allCases.forEach { section in
            let viewController = makeSectionViewController(for: section)
            addChild(viewController)
            viewController.view.translatesAutoresizingMaskIntoConstraints = false
            sectionStackView.addArrangedSubview(viewController.view)
            viewController.didMove(toParent: self)
            sectionViewControllers[section] = viewController
        }
    }
    
    private func makeSectionViewController(for section: HomepageSection) -> UIViewController {
        switch section {
        case .favorites:
            let viewController = FavoritesSectionViewController(bookmarkStore: bookmarkStore)
            viewController.delegate = self
            viewController.setContentMode(contentMode)
            return viewController
        }
    }
    
    // MARK: - Helpers
    
    private var favoritesSectionViewController: FavoritesSectionViewController? {
        return sectionViewControllers[.favorites] as? FavoritesSectionViewController
    }
}

// MARK: - Scroll View Delegate

extension HomepageRootViewController: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.homepageViewControllerDidStartScrolling()
    }
}

// MARK: - Favorites Section Delegate

extension HomepageRootViewController: FavoritesSectionViewControllerDelegate {
    func favoritesSectionViewController(_ controller: FavoritesSectionViewController, didSelectFavorite favorite: BookmarkSnapshot) {
        delegate?.homepageViewControllerDidSelectFavorite(favorite)
    }
}
