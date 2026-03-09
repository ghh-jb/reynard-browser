//
//  LibraryMenuViewController.swift
//  Reynard
//
//  Created by Minh Ton on 9/3/26.
//

import UIKit

final class LibraryMenuViewController: UIViewController, LibraryBarDelegate {
    private enum Layout {
        static let insetBarHeight: CGFloat = 66
        static let dockedBarHeight: CGFloat = 50
    }
    
    private let libraryBar = LibraryBar()
    private let contentContainer = UIView()
    private var libraryBarBottomConstraint: NSLayoutConstraint?
    private var libraryBarLeadingConstraint: NSLayoutConstraint?
    private var libraryBarTrailingConstraint: NSLayoutConstraint?
    private var libraryBarHeightConstraint: NSLayoutConstraint?
    private let backgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        return view
    }()
    private let bookmarksView = BookmarksManagerView()
    private let historyView = HistoryManagerView()
    private let downloadsView = DownloadsManagerView()
    private let settingsView = SettingsView()
    
    private lazy var sectionViews: [LibrarySection: UIView] = [
        .bookmarks: bookmarksView,
        .history: historyView,
        .downloads: downloadsView,
        .settings: settingsView,
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = backgroundView.backgroundColor
        view.isOpaque = true
        setupViews()
        libraryBar.select(.bookmarks, notify: false)
        setVisibleSection(.bookmarks)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateLibraryBarLayout()
    }
    
    func libraryBar(_ libraryBar: LibraryBar, didSelect section: LibrarySection) {
        setVisibleSection(section)
    }
    
    private func setupViews() {
        libraryBar.delegate = self
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.backgroundColor = .clear
        
        libraryBarBottomConstraint = libraryBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 18)
        libraryBarLeadingConstraint = libraryBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18)
        libraryBarTrailingConstraint = libraryBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18)
        libraryBarHeightConstraint = libraryBar.heightAnchor.constraint(equalToConstant: Layout.insetBarHeight)
        
        view.addSubview(backgroundView)
        view.addSubview(contentContainer)
        view.addSubview(libraryBar)
        view.bringSubviewToFront(libraryBar)
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        NSLayoutConstraint.activate([
            libraryBarBottomConstraint,
            libraryBarLeadingConstraint,
            libraryBarTrailingConstraint,
            libraryBarHeightConstraint,
            contentContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            contentContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ].compactMap { $0 })
        
        for section in LibrarySection.allCases {
            guard let sectionView = sectionViews[section] else {
                continue
            }
            
            sectionView.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview(sectionView)
            
            NSLayoutConstraint.activate([
                sectionView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                sectionView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                sectionView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                sectionView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
                sectionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
            ])
        }
        
        updateLibraryBarLayout()
    }
    
    private func updateLibraryBarLayout() {
        let usesInsetLibraryBarLayout = view.safeAreaInsets.bottom > 0
        libraryBarBottomConstraint?.constant = usesInsetLibraryBarLayout ? 18 : 0
        libraryBarLeadingConstraint?.constant = usesInsetLibraryBarLayout ? 18 : 0
        libraryBarTrailingConstraint?.constant = usesInsetLibraryBarLayout ? -18 : 0
        libraryBarHeightConstraint?.constant = usesInsetLibraryBarLayout ? Layout.insetBarHeight : Layout.dockedBarHeight
        libraryBar.setUsesInsetLayout(usesInsetLibraryBarLayout)
    }
    
    private func setVisibleSection(_ section: LibrarySection) {
        for candidate in LibrarySection.allCases {
            sectionViews[candidate]?.isHidden = candidate != section
        }
    }
}
