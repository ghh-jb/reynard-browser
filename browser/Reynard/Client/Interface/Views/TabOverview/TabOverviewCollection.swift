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
            action: #selector(TabCollectionCoordinator.handleOverviewReorderLongPress(_:))
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

final class TabCollectionCoordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate {
    private unowned let controller: BrowserViewController
    private weak var activeReorderingCell: TabOverviewCard?
    private var pendingReorderStartWorkItem: DispatchWorkItem?
    private var isInteractiveReorderActive = false
    
    init(controller: BrowserViewController) {
        self.controller = controller
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        controller.tabManager.tabs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        collectionView === controller.browserUI.tabOverviewCollection.collectionView
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView === controller.browserUI.tabOverviewCollection.collectionView {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: TabOverviewCard.reuseIdentifier,
                for: indexPath
            ) as? TabOverviewCard else {
                return UICollectionViewCell()
            }
            
            let tab = controller.tabManager.tabs[indexPath.item]
            cell.configure(tab: tab)
            cell.onClose = { [weak self, weak collectionView, weak cell] in
                guard let self,
                      let collectionView,
                      let cell,
                      let currentIndexPath = collectionView.indexPath(for: cell) else {
                    return
                }
                self.controller.closeTab(at: currentIndexPath.item)
            }
            return cell
        }
        
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TabBarCell.reuseIdentifier,
            for: indexPath
        ) as? TabBarCell else {
            return UICollectionViewCell()
        }
        
        let tab = controller.tabManager.tabs[indexPath.item]
        let metrics = controller.browserUI.tabBar.layoutMetrics(
            for: indexPath.item,
            fallbackWidth: controller.view.bounds.width,
            tabCount: controller.tabManager.tabs.count,
            usesExpandedWidth: { [unowned controller] index in
                controller.usesExpandedTabBarWidth(at: index)
            }
        )
        cell.configure(
            tab: tab,
            selected: indexPath.item == controller.tabManager.selectedTabIndex,
            layoutMode: metrics.mode,
            itemWidth: metrics.width
        )
        cell.onClose = { [weak self] in
            self?.controller.closeTab(at: indexPath.item)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView === controller.browserUI.tabOverviewCollection.collectionView {
            let previewImage: UIImage?
            if let cell = collectionView.cellForItem(at: indexPath) as? TabOverviewCard {
                previewImage = cell.currentPreviewImage
            } else {
                previewImage = controller.tabManager.tabs[safe: indexPath.item]?.thumbnail
            }
            
            controller.tabOverviewPresentation.prepareDismissSelection(to: indexPath.item, previewImage: previewImage)
            controller.browserUI.tabOverviewCollection.collectionView.reloadData()
            controller.setTabOverviewVisible(false, animated: true)
            return
        }
        
        controller.selectTab(at: indexPath.item, animated: true)
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        moveItemAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        guard collectionView === controller.browserUI.tabOverviewCollection.collectionView else {
            return
        }
        
        controller.moveTab(from: sourceIndexPath.item, to: destinationIndexPath.item)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard collectionView === controller.browserUI.tabOverviewCollection.collectionView,
              let tabCell = cell as? TabOverviewCard else {
            return
        }
        tabCell.setNeedsLayout()
        tabCell.layoutIfNeeded()
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        if collectionView === controller.browserUI.tabOverviewCollection.collectionView {
            return controller.tabOverviewPresentation.itemSize(for: collectionView)
        }
        
        if collectionView === controller.browserUI.tabBar.collectionView {
            let metrics = controller.browserUI.tabBar.layoutMetrics(
                for: indexPath.item,
                fallbackWidth: controller.view.bounds.width,
                tabCount: controller.tabManager.tabs.count,
                usesExpandedWidth: { [unowned controller] index in
                    controller.usesExpandedTabBarWidth(at: index)
                }
            )
            return CGSize(width: metrics.width, height: collectionView.bounds.height)
        }
        
        let title = controller.tabManager.tabs[indexPath.item].title
        let width = max(120, min(240, (title as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 14, weight: .medium)]).width + 52))
        return CGSize(width: width, height: 30)
    }
    
    private func cancelPendingReorderStart() {
        pendingReorderStartWorkItem?.cancel()
        pendingReorderStartWorkItem = nil
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let longPress = gestureRecognizer as? UILongPressGestureRecognizer,
              let collectionView = longPress.view as? UICollectionView,
              collectionView === controller.browserUI.tabOverviewCollection.collectionView else {
            return true
        }
        
        let location = longPress.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: location),
              let cell = collectionView.cellForItem(at: indexPath) as? TabOverviewCard else {
            return false
        }
        
        let pointInCell = collectionView.convert(location, to: cell)
        return !cell.containsCloseButton(point: pointInCell)
    }
    
    @objc func handleOverviewReorderLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard let collectionView = gestureRecognizer.view as? UICollectionView,
              collectionView === controller.browserUI.tabOverviewCollection.collectionView else {
            return
        }
        
        let location = gestureRecognizer.location(in: collectionView)
        
        switch gestureRecognizer.state {
        case .began:
            guard let indexPath = collectionView.indexPathForItem(at: location),
                  let cell = collectionView.cellForItem(at: indexPath) as? TabOverviewCard else {
                return
            }
            
            let pointInCell = collectionView.convert(location, to: cell)
            guard !cell.containsCloseButton(point: pointInCell) else {
                return
            }
            
            activeReorderingCell = cell
            cancelPendingReorderStart()
            cell.setReorderLifted(true, animated: true)
            
            let workItem = DispatchWorkItem { [weak self, weak collectionView, weak cell] in
                guard let self,
                      let collectionView,
                      let cell,
                      self.activeReorderingCell === cell,
                      !self.isInteractiveReorderActive else {
                    return
                }
                
                guard collectionView.beginInteractiveMovementForItem(at: indexPath) else {
                    cell.setReorderLifted(false, animated: true)
                    self.activeReorderingCell = nil
                    return
                }
                
                self.isInteractiveReorderActive = true
            }
            pendingReorderStartWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: workItem)
            
        case .changed:
            if isInteractiveReorderActive {
                collectionView.updateInteractiveMovementTargetPosition(location)
            }
            
        case .ended:
            cancelPendingReorderStart()
            if isInteractiveReorderActive {
                collectionView.endInteractiveMovement()
                isInteractiveReorderActive = false
                if let activeReorderingCell {
                    activeReorderingCell.setReorderLifted(false, animated: true)
                }
                activeReorderingCell = nil
            } else if let activeReorderingCell {
                activeReorderingCell.setReorderLifted(false, animated: true)
                self.activeReorderingCell = nil
            }
            
        default:
            cancelPendingReorderStart()
            if isInteractiveReorderActive {
                collectionView.cancelInteractiveMovement()
                isInteractiveReorderActive = false
            }
            if let activeReorderingCell {
                activeReorderingCell.setReorderLifted(false, animated: true)
            }
            self.activeReorderingCell = nil
        }
    }
    
}
