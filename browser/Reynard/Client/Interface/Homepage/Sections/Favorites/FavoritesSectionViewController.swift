//
//  FavoritesSectionViewController.swift
//  Reynard
//
//  Created by Minh Ton on 21/6/26.
//

import UIKit

protocol FavoritesSectionViewControllerDelegate: AnyObject {
    func favoritesSectionViewController(_ controller: FavoritesSectionViewController, didSelectFavorite favorite: BookmarkSnapshot)
    func favoritesSectionViewController(_ controller: FavoritesSectionViewController, didSelectFolder folder: BookmarkFolderSnapshot)
}

final class FavoritesSectionViewController: UIViewController {
    private enum UX {
        static let horizontalInset: CGFloat = 2
        static let titleBottomSpacing: CGFloat = 3
        static let titleFontSize: CGFloat = 22
        static let reorderMinimumPressDuration: TimeInterval = 0.35
        static let rowSpacing: CGFloat = 16
    }
    
    weak var delegate: FavoritesSectionViewControllerDelegate?
    
    private static let titleFont = UIFontMetrics(forTextStyle: .title2).scaledFont(
        for: .systemFont(ofSize: UX.titleFontSize, weight: .bold)
    )
    
    private let bookmarkStore: BookmarkStore
    private let folder: BookmarkFolderSnapshot?
    private let showsSectionTitle: Bool
    private var favoriteItems: [BookmarkContentSnapshot] = []
    private var favoritesFolderGUID: String?
    private var contentMode: HomepageContentMode = .embeddedNarrow
    private var collectionHeightConstraint: NSLayoutConstraint?
    private var lastLaidOutWidth: CGFloat = -1
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = FavoritesSectionViewController.titleFont
        label.textColor = .label
        label.text = "Favorites"
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private let collectionLayout = FavoritesCollectionViewLayout()
    
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionLayout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.clipsToBounds = false
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            FavoriteSiteCollectionViewCell.self,
            forCellWithReuseIdentifier: FavoriteSiteCollectionViewCell.reuseIdentifier
        )
        collectionView.register(
            FavoriteFolderCollectionViewCell.self,
            forCellWithReuseIdentifier: FavoriteFolderCollectionViewCell.reuseIdentifier
        )
        return collectionView
    }()
    
    // MARK: - Lifecycle
    
    init(bookmarkStore: BookmarkStore = .shared, folder: BookmarkFolderSnapshot? = nil, showsSectionTitle: Bool = true) {
        self.bookmarkStore = bookmarkStore
        self.folder = folder
        self.showsSectionTitle = showsSectionTitle
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        configureHierarchy()
        configureConstraints()
        configureGestures()
        observeBookmarks()
        reloadFavorites()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateFavoriteGridLayout()
    }
    
    
    func setContentMode(_ contentMode: HomepageContentMode) {
        guard self.contentMode != contentMode else {
            return
        }
        
        self.contentMode = contentMode
        invalidateFavoriteLayout()
    }
    
    // MARK: - Configuration
    
    private func configureAppearance() {
        view.backgroundColor = .clear
        titleLabel.isHidden = !showsSectionTitle
    }
    
    private func configureHierarchy() {
        view.addSubview(titleLabel)
        view.addSubview(collectionView)
    }
    
    private func configureConstraints() {
        let heightConstraint = collectionView.heightAnchor.constraint(equalToConstant: 1)
        let collectionTopAnchor = showsSectionTitle ? titleLabel.bottomAnchor : view.topAnchor
        let collectionTopSpacing = showsSectionTitle ? UX.titleBottomSpacing : 0
        collectionHeightConstraint = heightConstraint
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: UX.horizontalInset),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -UX.horizontalInset),
            
            collectionView.topAnchor.constraint(equalTo: collectionTopAnchor, constant: collectionTopSpacing),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            heightConstraint,
        ])
    }
    
    private func configureGestures() {
        let reorderGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleReorderLongPress(_:)))
        reorderGesture.minimumPressDuration = UX.reorderMinimumPressDuration
        collectionView.addGestureRecognizer(reorderGesture)
    }
    
    private func observeBookmarks() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(bookmarksDidChange),
            name: .bookmarkStoreDidChange,
            object: nil
        )
    }
    
    // MARK: - Bookmarks
    
    private func reloadFavorites() {
        let contents: BookmarkFolderContentsSnapshot
        if let folder {
            contents = bookmarkStore.contents(of: folder.guid)
        } else {
            contents = bookmarkStore.favoritesFolderContents()
        }
        
        favoritesFolderGUID = contents.parent.guid
        favoriteItems = contents.items
        collectionView.reloadData()
        view.isHidden = favoriteItems.isEmpty
        invalidateFavoriteLayout()
    }
    
    @objc private func bookmarksDidChange() {
        reloadFavorites()
    }
    
    // MARK: - Layout
    
    private func invalidateFavoriteLayout() {
        lastLaidOutWidth = -1
        UIView.performWithoutAnimation {
            collectionLayout.invalidateLayout()
            view.setNeedsLayout()
        }
    }
    
    private func updateFavoriteGridLayout() {
        let width = collectionView.bounds.width
        guard width > 0 else {
            return
        }
        
        let metrics = FavoritesLayoutMetrics(
            width: width,
            columnCount: contentMode.favoriteColumnCount,
            horizontalInset: UX.horizontalInset,
            lineSpacing: UX.rowSpacing
        )
        if abs(lastLaidOutWidth - width) > 0.5
            || collectionLayout.metrics != metrics {
            lastLaidOutWidth = width
            collectionLayout.metrics = metrics
        }
        
        let rowCount = Int(ceil(CGFloat(favoriteItems.count) / CGFloat(metrics.columnCount)))
        let contentHeight = metrics.contentHeight(rowCount: rowCount)
        guard abs((collectionHeightConstraint?.constant ?? 0) - contentHeight) > 0.5 else {
            return
        }
        
        collectionHeightConstraint?.constant = contentHeight
    }
    
    // MARK: - Reorder
    
    @objc private func handleReorderLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        let pressLocation = gestureRecognizer.location(in: collectionView)
        
        switch gestureRecognizer.state {
        case .began:
            guard let indexPath = collectionView.indexPathForItem(at: pressLocation) else {
                return
            }
            collectionView.beginInteractiveMovementForItem(at: indexPath)
            
        case .changed:
            collectionView.updateInteractiveMovementTargetPosition(pressLocation)
            
        case .ended:
            collectionView.endInteractiveMovement()
            
        default:
            collectionView.cancelInteractiveMovement()
        }
    }
    
}

// MARK: - Collection View Delegate

extension FavoritesSectionViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return favoriteItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch favoriteItems[indexPath.item] {
        case let .bookmark(bookmark):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: FavoriteSiteCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as! FavoriteSiteCollectionViewCell
            cell.configure(favorite: bookmark)
            return cell
            
        case let .folder(folder):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: FavoriteFolderCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as! FavoriteFolderCollectionViewCell
            cell.configure(folder: folder, previewBookmarks: previewBookmarks(for: folder))
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard favoriteItems.indices.contains(indexPath.item) else {
            return
        }
        
        switch favoriteItems[indexPath.item] {
        case let .bookmark(bookmark):
            delegate?.favoritesSectionViewController(self, didSelectFavorite: bookmark)
        case let .folder(folder):
            delegate?.favoritesSectionViewController(self, didSelectFolder: folder)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return favoriteItems.indices.contains(indexPath.item)
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard favoriteItems.indices.contains(sourceIndexPath.item) else {
            reloadFavorites()
            return
        }
        
        let destinationIndex = min(max(destinationIndexPath.item, 0), favoriteItems.count - 1)
        let favoriteItem = favoriteItems.remove(at: sourceIndexPath.item)
        favoriteItems.insert(favoriteItem, at: destinationIndex)
        
        guard let favoritesFolderGUID,
              bookmarkStore.moveBookmarkItem(guid: favoriteItem.guid, to: destinationIndex, in: favoritesFolderGUID) else {
            reloadFavorites()
            return
        }
    }
    
    private func previewBookmarks(for folder: BookmarkFolderSnapshot) -> [BookmarkSnapshot] {
        let contents = bookmarkStore.contents(of: folder.guid)
        return contents.items.compactMap { item in
            guard case let .bookmark(bookmark) = item else {
                return nil
            }
            return bookmark
        }
    }
}

private extension BookmarkContentSnapshot {
    var guid: String {
        switch self {
        case let .bookmark(bookmark):
            return bookmark.guid
        case let .folder(folder):
            return folder.guid
        }
    }
}
