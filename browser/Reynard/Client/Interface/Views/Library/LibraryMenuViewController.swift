//
//  LibraryMenuViewController.swift
//  Reynard
//
//  Created by Minh Ton on 9/3/26.
//

import UIKit

final class LibraryMenuViewController: UIViewController, LibraryBarDelegate {
    private let libraryBar = LibraryBar()
    private let contentContainer = UIView()
    private let backgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6.withAlphaComponent(0.8)
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
    
    func libraryBar(_ libraryBar: LibraryBar, didSelect section: LibrarySection) {
        setVisibleSection(section)
    }
    
    private func setupViews() {
        libraryBar.delegate = self
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.backgroundColor = .clear
        
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
            libraryBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 18),
            libraryBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            libraryBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            libraryBar.heightAnchor.constraint(equalToConstant: 66),
            contentContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            contentContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        
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
    }
    
    private func setVisibleSection(_ section: LibrarySection) {
        for candidate in LibrarySection.allCases {
            sectionViews[candidate]?.isHidden = candidate != section
        }
    }
}
