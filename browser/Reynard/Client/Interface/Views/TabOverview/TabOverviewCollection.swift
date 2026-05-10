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

final class TabCollectionCoordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    private struct PadTabLayoutMetrics {
        let width: CGFloat
        let mode: PadTabCell.LayoutMode
    }
    
    private unowned let controller: BrowserViewController
    
    init(controller: BrowserViewController) {
        self.controller = controller
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        controller.tabManager.tabs.count
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
            cell.onClose = { [weak self] in
                self?.controller.closeTab(at: indexPath.item)
            }
            return cell
        }
        
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PadTabCell.reuseIdentifier,
            for: indexPath
        ) as? PadTabCell else {
            return UICollectionViewCell()
        }
        
        let tab = controller.tabManager.tabs[indexPath.item]
        let metrics = padTabLayoutMetrics(for: collectionView, at: indexPath)
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
        
        if collectionView === controller.browserUI.padTabBar.collectionView {
            let metrics = padTabLayoutMetrics(for: collectionView, at: indexPath)
            return CGSize(width: metrics.width, height: collectionView.bounds.height)
        }
        
        let title = controller.tabManager.tabs[indexPath.item].title
        let width = max(120, min(240, (title as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 14, weight: .medium)]).width + 52))
        return CGSize(width: width, height: 30)
    }
    
    private func padTabLayoutMetrics(for collectionView: UICollectionView, at indexPath: IndexPath) -> PadTabLayoutMetrics {
        let horizontalInsets = collectionView.adjustedContentInset.left + collectionView.adjustedContentInset.right
        let baseWidth = collectionView.bounds.width > 1 ? collectionView.bounds.width : controller.view.bounds.width
        let availableWidth = max(0, baseWidth - horizontalInsets)
        let tabCount = max(1, controller.tabManager.tabs.count)
        let equalWidth = floor(availableWidth / CGFloat(tabCount))
        
        let needsExpandedClamp = equalWidth < PadTabCell.expandedMinimumWidth
        if !needsExpandedClamp {
            return PadTabLayoutMetrics(width: equalWidth, mode: .expanded)
        }
        
        let usesExpandedWidth = controller.usesExpandedPadTabWidth(at: indexPath.item)
        let expandedTabCount = max(1, controller.tabManager.tabs.indices.reduce(0) {
            $0 + (controller.usesExpandedPadTabWidth(at: $1) ? 1 : 0)
        })
        let unselectedCount = max(0, tabCount - expandedTabCount)
        
        let hasReachedCollapsedThreshold: Bool
        let widthForUnselected: CGFloat
        if unselectedCount == 0 {
            hasReachedCollapsedThreshold = false
            widthForUnselected = availableWidth
        } else {
            let remainingWidth = availableWidth - (PadTabCell.expandedMinimumWidth * CGFloat(expandedTabCount))
            widthForUnselected = floor(remainingWidth / CGFloat(unselectedCount))
            hasReachedCollapsedThreshold = widthForUnselected <= PadTabCell.collapsedMinimumWidth
        }
        
        let itemWidth: CGFloat
        let mode: PadTabCell.LayoutMode
        if usesExpandedWidth {
            itemWidth = PadTabCell.expandedMinimumWidth
            mode = .expanded
        } else if hasReachedCollapsedThreshold {
            itemWidth = PadTabCell.collapsedMinimumWidth
            mode = .faviconOnly
        } else {
            itemWidth = max(0, widthForUnselected)
            mode = .expanded
        }
        
        return PadTabLayoutMetrics(width: itemWidth, mode: mode)
    }
}
