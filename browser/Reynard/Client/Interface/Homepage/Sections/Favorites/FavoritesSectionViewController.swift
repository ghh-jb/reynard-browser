//
//  FavoritesSectionViewController.swift
//  Reynard
//
//  Created by Minh Ton on 21/6/26.
//

import UIKit

protocol FavoritesSectionViewControllerDelegate: AnyObject {
    func favoritesSectionViewController(_ controller: FavoritesSectionViewController, didSelectFavorite favorite: BookmarkSnapshot)
}

final class FavoritesSectionViewController: UIViewController {
    private enum UX {
        static let horizontalInset: CGFloat = 2
        static let titleBottomSpacing: CGFloat = 3
        static let titleFontSize: CGFloat = 22
        static let reorderMinimumPressDuration: TimeInterval = 0.35
        static let rowSpacing: CGFloat = 16
    }
    
    private static let sectionTitle = "Favorites"
    private static let titleFont = UIFontMetrics(forTextStyle: .title2).scaledFont(
        for: .systemFont(ofSize: UX.titleFontSize, weight: .bold)
    )
    
    weak var delegate: FavoritesSectionViewControllerDelegate?
    
    private let bookmarkStore: BookmarkStore
    private var favoriteBookmarks: [BookmarkSnapshot] = []
    private var favoritesFolderID: String?
    private var contentMode: HomepageContentMode = .embeddedNarrow
    private var collectionHeightConstraint: NSLayoutConstraint?
    private var lastLaidOutWidth: CGFloat = -1
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = FavoritesSectionViewController.titleFont
        label.textColor = .label
        label.text = FavoritesSectionViewController.sectionTitle
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
        collectionView.register(FavoriteCollectionViewCell.self, forCellWithReuseIdentifier: FavoriteCollectionViewCell.reuseIdentifier)
        return collectionView
    }()
    
    // MARK: - Lifecycle
    
    init(bookmarkStore: BookmarkStore = .shared) {
        self.bookmarkStore = bookmarkStore
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
    
    // MARK: - Public API
    
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
    }
    
    private func configureHierarchy() {
        view.addSubview(titleLabel)
        view.addSubview(collectionView)
    }
    
    private func configureConstraints() {
        let heightConstraint = collectionView.heightAnchor.constraint(equalToConstant: 1)
        collectionHeightConstraint = heightConstraint
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: UX.horizontalInset),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -UX.horizontalInset),
            
            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: UX.titleBottomSpacing),
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
        let contents = bookmarkStore.favoritesFolderContents()
        favoritesFolderID = contents.parent.guid
        favoriteBookmarks = contents.items.compactMap { item in
            guard case let .bookmark(bookmark) = item else {
                return nil
            }
            return bookmark
        }
        collectionView.reloadData()
        view.isHidden = favoriteBookmarks.isEmpty
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
        
        let rowCount = Int(ceil(CGFloat(favoriteBookmarks.count) / CGFloat(metrics.columnCount)))
        let contentHeight = metrics.contentHeight(rowCount: rowCount)
        guard abs((collectionHeightConstraint?.constant ?? 0) - contentHeight) > 0.5 else {
            return
        }
        
        collectionHeightConstraint?.constant = contentHeight
    }
    
    // MARK: - Reorder
    
    @objc private func handleReorderLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        let location = gestureRecognizer.location(in: collectionView)
        
        switch gestureRecognizer.state {
        case .began:
            guard let indexPath = collectionView.indexPathForItem(at: location) else {
                return
            }
            collectionView.beginInteractiveMovementForItem(at: indexPath)
            
        case .changed:
            collectionView.updateInteractiveMovementTargetPosition(location)
            
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
        return favoriteBookmarks.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FavoriteCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as! FavoriteCollectionViewCell
        cell.configure(favorite: favoriteBookmarks[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard favoriteBookmarks.indices.contains(indexPath.item) else {
            return
        }
        
        delegate?.favoritesSectionViewController(self, didSelectFavorite: favoriteBookmarks[indexPath.item])
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return favoriteBookmarks.indices.contains(indexPath.item)
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard favoriteBookmarks.indices.contains(sourceIndexPath.item) else {
            reloadFavorites()
            return
        }
        
        let targetIndex = min(max(destinationIndexPath.item, 0), favoriteBookmarks.count - 1)
        let favorite = favoriteBookmarks.remove(at: sourceIndexPath.item)
        favoriteBookmarks.insert(favorite, at: targetIndex)
        
        guard let favoritesFolderID,
              bookmarkStore.moveBookmarkItem(guid: favorite.guid, to: targetIndex, in: favoritesFolderID) else {
            reloadFavorites()
            return
        }
    }
}
