//
//  RecentlyClosedTabsSectionViewController.swift
//  Reynard
//
//  Created by Minh Ton on 25/6/26.
//

import UIKit

final class RecentlyClosedTabsSectionViewController: UIViewController {
    private enum UX {
        static let maximumClosedTabCount = 10
        static let horizontalInset: CGFloat = 2
        static let titleTopSpacing: CGFloat = 14
        static let titleBottomSpacing: CGFloat = 16
        static let titleFontSize: CGFloat = 22
        static let pillHeight: CGFloat = 44
        static let columnSpacing: CGFloat = 10
        static let rowSpacing: CGFloat = 10
        static let shadowMargin: CGFloat = 20
    }
    
    private static let titleFont = UIFontMetrics(forTextStyle: .title2).scaledFont(
        for: .systemFont(ofSize: UX.titleFontSize, weight: .bold)
    )
    
    weak var delegate: HomepageSectionDelegate?
    
    private let tabStore: TabManagementStore
    private var closedTabs: [TabManagementStore.RecentlyClosedTabSnapshot] = []
    private var contentMode: HomepageContentMode = .embeddedNarrow
    private var isPrivateBrowsing = false
    private var collectionHeightConstraint: NSLayoutConstraint?
    private var lastLaidOutWidth: CGFloat = -1
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = RecentlyClosedTabsSectionViewController.titleFont
        label.textColor = .label
        label.text = "Recently Closed Tabs"
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private let collectionLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = UX.columnSpacing
        layout.minimumLineSpacing = UX.rowSpacing
        layout.sectionInset = UIEdgeInsets(
            top: UX.shadowMargin,
            left: UX.shadowMargin,
            bottom: UX.shadowMargin,
            right: UX.shadowMargin
        )
        return layout
    }()
    
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionLayout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            RecentlyClosedTabCollectionViewCell.self,
            forCellWithReuseIdentifier: RecentlyClosedTabCollectionViewCell.reuseIdentifier
        )
        return collectionView
    }()
    
    // MARK: - Lifecycle
    
    init(tabStore: TabManagementStore = .shared) {
        self.tabStore = tabStore
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        configureHierarchy()
        configureConstraints()
        reloadClosedTabs()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadClosedTabs()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionLayout()
    }
    
    func setContentMode(_ contentMode: HomepageContentMode) {
        guard self.contentMode != contentMode else {
            return
        }
        
        self.contentMode = contentMode
        invalidateCollectionLayout()
    }
    
    func setPrivateBrowsing(_ isPrivateBrowsing: Bool) {
        guard self.isPrivateBrowsing != isPrivateBrowsing else {
            return
        }
        
        self.isPrivateBrowsing = isPrivateBrowsing
        reloadClosedTabs()
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
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: UX.titleTopSpacing),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: UX.horizontalInset),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -UX.horizontalInset),
            
            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: UX.titleBottomSpacing - UX.shadowMargin),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -UX.shadowMargin),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: UX.shadowMargin),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            heightConstraint,
        ])
    }
    
    private func reloadClosedTabs() {
        if isPrivateBrowsing {
            closedTabs.removeAll(keepingCapacity: true)
        } else {
            closedTabs = tabStore.recentlyClosedTabs(limit: UX.maximumClosedTabCount)
        }
        
        collectionView.reloadData()
        view.isHidden = isPrivateBrowsing || closedTabs.isEmpty
        invalidateCollectionLayout()
    }
    
    // MARK: - Layout
    
    private func invalidateCollectionLayout() {
        lastLaidOutWidth = -1
        UIView.performWithoutAnimation {
            collectionLayout.invalidateLayout()
            updateCollectionHeight()
            view.setNeedsLayout()
        }
    }
    
    private func updateCollectionLayout() {
        let width = collectionView.bounds.width
        guard width > 0 else {
            updateCollectionHeight()
            return
        }
        
        let columnCount = max(contentMode.recentlyCloseTabsColumnCount, 1)
        let spacingWidth = CGFloat(columnCount - 1) * UX.columnSpacing
        let horizontalInset = collectionLayout.sectionInset.left + collectionLayout.sectionInset.right
        let itemWidth = max(1, floor((width - horizontalInset - spacingWidth) / CGFloat(columnCount)))
        if abs(lastLaidOutWidth - width) > 0.5
            || collectionLayout.itemSize.width != itemWidth {
            lastLaidOutWidth = width
            collectionLayout.itemSize = CGSize(width: itemWidth, height: UX.pillHeight)
            collectionLayout.invalidateLayout()
        }
        
        updateCollectionHeight()
    }
    
    private func updateCollectionHeight() {
        let columnCount = max(contentMode.recentlyCloseTabsColumnCount, 1)
        let rowCount = Int(ceil(CGFloat(closedTabs.count) / CGFloat(columnCount)))
        let verticalInset = collectionLayout.sectionInset.top + collectionLayout.sectionInset.bottom
        let contentHeight = rowCount == 0
        ? verticalInset
        : verticalInset + (CGFloat(rowCount) * UX.pillHeight) + (CGFloat(rowCount - 1) * UX.rowSpacing)
        guard abs((collectionHeightConstraint?.constant ?? 0) - contentHeight) > 0.5 else {
            return
        }
        
        collectionHeightConstraint?.constant = contentHeight
    }
}

// MARK: - Collection View Delegate

extension RecentlyClosedTabsSectionViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return closedTabs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RecentlyClosedTabCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as! RecentlyClosedTabCollectionViewCell
        cell.configure(tab: closedTabs[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard closedTabs.indices.contains(indexPath.item) else {
            return
        }
        
        delegate?.homepageSection(self, didSelectRecentlyClosedTab: closedTabs[indexPath.item].id)
    }
}
