//
//  TabOverviewCollection.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import UIKit

final class TabOverviewCollection {
    typealias TabCollectionHandler = UICollectionViewDataSource & UICollectionViewDelegate & UICollectionViewDelegateFlowLayout
    
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = overviewSpacing
        layout.minimumInteritemSpacing = overviewSpacing
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.alwaysBounceVertical = true
        view.contentInset = UIEdgeInsets(top: overviewInset, left: overviewInset, bottom: overviewInset, right: overviewInset)
        view.dataSource = tabCollectionHandler
        view.delegate = tabCollectionHandler
        let reorderGesture = UILongPressGestureRecognizer(
            target: tabCollectionHandler as AnyObject,
            action: #selector(BrowserViewController.handleOverviewReorderLongPress(_:))
        )
        reorderGesture.minimumPressDuration = 0.35
        reorderGesture.delegate = tabCollectionHandler as? UIGestureRecognizerDelegate
        view.addGestureRecognizer(reorderGesture)
        view.register(TabOverviewCard.self, forCellWithReuseIdentifier: TabOverviewCard.reuseIdentifier)
        return view
    }()
    
    var topPhoneConstraint: NSLayoutConstraint!
    var bottomPhoneConstraint: NSLayoutConstraint!
    var topPadConstraint: NSLayoutConstraint!
    var bottomPadConstraint: NSLayoutConstraint!
    
    private let overviewInset: CGFloat
    private let overviewSpacing: CGFloat
    private let tabCollectionHandler: TabCollectionHandler
    
    init(overviewInset: CGFloat, overviewSpacing: CGFloat, tabCollectionHandler: TabCollectionHandler) {
        self.overviewInset = overviewInset
        self.overviewSpacing = overviewSpacing
        self.tabCollectionHandler = tabCollectionHandler
    }
}
