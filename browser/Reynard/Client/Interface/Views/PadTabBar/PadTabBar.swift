//
//  PadTabBar.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import UIKit

final class PadTabBar {
    typealias TabCollectionHandler = UICollectionViewDataSource & UICollectionViewDelegate & UICollectionViewDelegateFlowLayout
    
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero
        
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        view.showsHorizontalScrollIndicator = false
        view.contentInset = .zero
        view.contentInsetAdjustmentBehavior = .never
        view.dataSource = tabCollectionHandler
        view.delegate = tabCollectionHandler
        view.register(PadTabCell.self, forCellWithReuseIdentifier: PadTabCell.reuseIdentifier)
        return view
    }()
    
    var heightConstraint: NSLayoutConstraint!
    
    private let tabCollectionHandler: TabCollectionHandler
    
    init(tabCollectionHandler: TabCollectionHandler) {
        self.tabCollectionHandler = tabCollectionHandler
    }
}
