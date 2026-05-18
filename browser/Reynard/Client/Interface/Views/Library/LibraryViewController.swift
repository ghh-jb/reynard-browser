//
//  LibraryViewController.swift
//  Reynard
//
//  Created by Minh Ton on 9/3/26.
//

import UIKit

final class LibraryViewController: UITabBarController, UITabBarControllerDelegate, UINavigationControllerDelegate {
    private let initialSection: LibrarySection
    private let isPrivateMode: Bool
    private let onClose: (() -> Void)?
    private var visibleSections: [LibrarySection] {
        isPrivateMode ? LibrarySection.allCases.filter { $0 != .history } : LibrarySection.allCases
    }
    
    init(initialSection: LibrarySection = .bookmarks, isPrivateMode: Bool = false, onClose: (() -> Void)? = nil) {
        self.initialSection = initialSection
        self.isPrivateMode = isPrivateMode
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        delegate = self
        setViewControllers(makeSectionViewControllers(), animated: false)
        let selectedSection = visibleSections.contains(initialSection) ? initialSection : .bookmarks
        selectedIndex = visibleSections.firstIndex(of: selectedSection) ?? 0
        LibraryTabBarStyle.apply(to: tabBar)
        if onClose != nil {
            navigationItem.rightBarButtonItem = makeCloseBarButtonItem()
        }
        updateNavigationTitle()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applySettingsTabBadge),
            name: AppUpdates.updateAvailableNotification,
            object: nil
        )
        if AppUpdates.shared.hasUpdate {
            applySettingsTabBadge()
        }
    }
    
    @objc private func applySettingsTabBadge() {
        viewControllers?.first { viewController in
            viewController.tabBarItem.tag == LibrarySection.settings.rawValue
        }?.tabBarItem.badgeValue = ""
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.delegate = self
        navigationItem.leftItemsSupplementBackButton = false
        navigationItem.leftBarButtonItems = []
        navigationItem.leftBarButtonItem = nil
    }
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        guard onClose != nil else {
            return
        }
        
        viewController.navigationItem.rightBarButtonItem = makeCloseBarButtonItem()
    }
    
    private func makeSectionViewControllers() -> [UIViewController] {
        visibleSections.map { section in
            switch section {
            case .bookmarks:
                return makeSectionViewController(for: section, contentViewController: LibraryHostedSectionViewController(hostedViewFactory: { BookmarksManagerView() }))
            case .history:
                return makeSectionViewController(for: section, contentViewController: LibraryHostedSectionViewController(hostedViewFactory: { HistoryManagerView() }))
            case .downloads:
                return makeSectionViewController(for: section, contentViewController: LibraryHostedSectionViewController(hostedViewFactory: { DownloadsManagerView() }))
            case .settings:
                return makeSectionViewController(for: section, contentViewController: LibraryHostedSectionViewController(hostedViewFactory: { SettingsView() }))
            }
        }
    }
    
    private func makeSectionViewController(for section: LibrarySection, contentViewController: UIViewController) -> UIViewController {
        contentViewController.tabBarItem = section.tabBarItem
        return contentViewController
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        updateNavigationTitle()
    }
    
    private func updateNavigationTitle() {
        guard let tag = viewControllers?[safe: selectedIndex]?.tabBarItem.tag,
              let section = LibrarySection(rawValue: tag) else {
            title = nil
            return
        }
        
        title = section.title
    }
    
    @objc private func dismissLibraryMenu() {
        onClose?()
    }
    
    private func makeCloseBarButtonItem() -> UIBarButtonItem {
        if #available(iOS 26.0, *) {
            let button = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(dismissLibraryMenu)
            )
            button.tintColor = .label
            return button
        }
        
        return UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissLibraryMenu)
        )
    }
}

private final class LibraryHostedSectionViewController: UIViewController {
    private let hostedViewFactory: () -> UIView
    
    init(hostedViewFactory: @escaping () -> UIView) {
        self.hostedViewFactory = hostedViewFactory
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGray6
        
        let hostedView = hostedViewFactory()
        
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostedView)
        
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: view.topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
