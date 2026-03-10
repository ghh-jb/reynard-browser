//
//  LibraryMenuViewController.swift
//  Reynard
//
//  Created by Minh Ton on 9/3/26.
//

import UIKit

final class LibraryMenuViewController: UITabBarController, UITabBarControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        delegate = self
        setViewControllers(makeSectionViewControllers(), animated: false)
        selectedIndex = LibrarySection.bookmarks.rawValue
        LibraryTabBarStyle.apply(to: tabBar)
        if #available(iOS 26.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(dismissLibraryMenu)
            )
            navigationItem.rightBarButtonItem?.tintColor = .label
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(dismissLibraryMenu)
            )
        }
        updateNavigationTitle()
    }
    
    private func makeSectionViewControllers() -> [UIViewController] {
        [
            makeSectionViewController(for: .bookmarks, contentViewController: LibraryHostedSectionViewController(hostedView: BookmarksManagerView())),
            makeSectionViewController(for: .history, contentViewController: LibraryHostedSectionViewController(hostedView: HistoryManagerView())),
            makeSectionViewController(for: .downloads, contentViewController: LibraryHostedSectionViewController(hostedView: DownloadsManagerView())),
            makeSectionViewController(for: .settings, contentViewController: SettingsRootViewController()),
        ]
    }
    
    private func makeSectionViewController(for section: LibrarySection, contentViewController: UIViewController) -> UIViewController {
        contentViewController.tabBarItem = section.tabBarItem
        return contentViewController
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        updateNavigationTitle()
    }
    
    private func updateNavigationTitle() {
        guard let section = LibrarySection(rawValue: selectedIndex) else {
            title = nil
            return
        }
        
        title = section.title
    }
    
    @objc private func dismissLibraryMenu() {
        dismiss(animated: true)
    }
}

private final class LibraryHostedSectionViewController: UIViewController {
    private let hostedView: UIView
    
    init(hostedView: UIView) {
        self.hostedView = hostedView
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemGray6
        
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostedView)
        
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }
}
