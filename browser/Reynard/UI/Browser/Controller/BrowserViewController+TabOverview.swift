//
//  BrowserViewController+TabOverview.swift
//  Reynard
//
//  Created by Minh Ton on 4/3/26.
//

import UIKit

extension BrowserViewController {
    private func overviewPreviewSnapshotView(for index: Int) -> UIView? {
        let image = pendingOverviewPreviewImage ?? tabs[safe: index]?.thumbnail
        guard let image else {
            return nil
        }
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 18
        imageView.layer.cornerCurve = .continuous
        return imageView
    }
    
    private func overviewAnimationIndex() -> Int {
        let candidate = tabOverviewDismissTargetIndex ?? selectedTabIndex
        if tabs.indices.contains(candidate) {
            return candidate
        }
        return min(max(selectedTabIndex, 0), max(tabs.count - 1, 0))
    }
    
    private func applyPendingOverviewTabSelectionIfNeeded() {
        defer {
            pendingTabSelectionFromOverview = nil
            tabOverviewDismissTargetIndex = nil
            pendingOverviewPreviewImage = nil
        }
        
        guard let target = pendingTabSelectionFromOverview,
              target != selectedTabIndex,
              tabs.indices.contains(target) else {
            return
        }
        
        selectTab(at: target, animated: false)
    }
    
    func tabOverviewItemSize(for collectionView: UICollectionView) -> CGSize {
        let horizontalInsets = collectionView.adjustedContentInset.left + collectionView.adjustedContentInset.right
        let availableWidth = collectionView.bounds.width - horizontalInsets
        let tabViewAspectRatio = max(0.4, browserUI.geckoView.bounds.height / max(browserUI.geckoView.bounds.width, 1))
        
        let targetWidth: CGFloat = usesPadChromeLayout ? 250 : 170
        let computedColumns = Int((availableWidth + overviewSpacing) / (targetWidth + overviewSpacing))
        let columns = max(2, computedColumns)
        
        let totalSpacing = CGFloat(columns - 1) * overviewSpacing
        let itemWidth = floor((availableWidth - totalSpacing) / CGFloat(columns))
        let itemHeight = floor((itemWidth * tabViewAspectRatio) + 22)
        return CGSize(width: itemWidth, height: itemHeight)
    }
    
    func refreshTabOverviewForCurrentOrientation() {
        guard isTabOverviewVisible else {
            return
        }
        
        browserUI.tabOverviewCollectionView.collectionViewLayout.invalidateLayout()
        browserUI.tabOverviewCollectionView.reloadData()
        browserUI.tabOverviewCollectionView.layoutIfNeeded()
    }
    
    func setTabOverviewVisible(_ visible: Bool, animated: Bool) {
        if isOverviewMorphTransitionRunning {
            return
        }
        
        if visible == isTabOverviewVisible, currentOverviewProgress == (visible ? 1 : 0) {
            return
        }
        
        if animated {
            if usesPadChromeLayout {
                if visible {
                    animatePadOverviewPresentation()
                } else {
                    animatePadOverviewDismissal()
                }
            } else if visible {
                animatePhoneOverviewPresentation()
            } else {
                animatePhoneOverviewDismissal()
            }
            return
        }
        
        if visible {
            tabOverviewDismissTargetIndex = selectedTabIndex
            pendingTabSelectionFromOverview = nil
            pendingOverviewPreviewImage = nil
            captureThumbnail(for: selectedTabIndex)
            browserUI.tabOverviewCollectionView.reloadData()
            browserUI.tabOverviewContainer.isHidden = false
            view.bringSubviewToFront(browserUI.tabOverviewContainer)
            view.endEditing(true)
            setSearchFocused(false, animated: true)
        }
        
        let finalProgress: CGFloat = visible ? 1 : 0
        let animations = {
            self.applyOverviewProgress(finalProgress)
        }
        
        let completion: (Bool) -> Void = { _ in
            self.isTabOverviewVisible = visible
            if !visible {
                self.applyPendingOverviewTabSelectionIfNeeded()
                self.browserUI.tabOverviewContainer.isHidden = true
                self.applyOverviewProgress(0)
            }
            self.applyChromeLayout(animated: false)
        }
        
        animations()
        completion(true)
    }
    
    private func animatePhoneOverviewPresentation() {
        isOverviewMorphTransitionRunning = true
        
        captureThumbnail(for: selectedTabIndex)
        browserUI.tabOverviewCollectionView.reloadData()
        browserUI.tabOverviewContainer.isHidden = false
        browserUI.tabOverviewContainer.alpha = 1
        browserUI.tabOverviewBlurView.alpha = 0
        browserUI.overviewPhoneBottomBar.alpha = 0
        browserUI.overviewPhoneBottomSafeAreaFillView.alpha = 0
        view.bringSubviewToFront(browserUI.tabOverviewContainer)
        view.endEditing(true)
        setSearchFocused(false, animated: false)
        view.layoutIfNeeded()
        
        let indexPath = IndexPath(item: selectedTabIndex, section: 0)
        tabOverviewDismissTargetIndex = selectedTabIndex
        browserUI.tabOverviewCollectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        browserUI.tabOverviewCollectionView.layoutIfNeeded()
        
        guard let selectedCell = selectedOverviewCell(at: selectedTabIndex),
              let targetFrame = selectedOverviewPreviewFrame(at: selectedTabIndex),
              let pageSnapshot = browserUI.geckoView.snapshotView(afterScreenUpdates: false),
              let bottomSnapshot = browserUI.toolbarView.snapshotView(afterScreenUpdates: true) else {
            isOverviewMorphTransitionRunning = false
            let finalProgress: CGFloat = 1
            applyOverviewProgress(finalProgress)
            isTabOverviewVisible = true
            applyChromeLayout(animated: false)
            return
        }
        
        selectedCell.setTransitionHidden(true)
        
        pageSnapshot.frame = browserUI.geckoView.frame
        pageSnapshot.layer.cornerRadius = 0
        pageSnapshot.layer.cornerCurve = .continuous
        pageSnapshot.layer.masksToBounds = true
        
        bottomSnapshot.frame = browserUI.toolbarView.convert(browserUI.toolbarView.bounds, to: view)
        
        view.addSubview(pageSnapshot)
        view.addSubview(bottomSnapshot)
        
        browserUI.geckoView.isHidden = true
        browserUI.phoneChromeContainer.isHidden = true
        
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseInOut]) {
            pageSnapshot.frame = targetFrame
            pageSnapshot.layer.cornerRadius = 18
            bottomSnapshot.alpha = 0
            self.browserUI.tabOverviewBlurView.alpha = 1
            self.browserUI.overviewPhoneBottomBar.alpha = 1
            self.browserUI.overviewPhoneBottomSafeAreaFillView.alpha = 1
        } completion: { _ in
            pageSnapshot.removeFromSuperview()
            bottomSnapshot.removeFromSuperview()
            selectedCell.setTransitionHidden(false)
            
            self.browserUI.geckoView.isHidden = false
            self.isTabOverviewVisible = true
            self.currentOverviewProgress = 1
            self.applyChromeLayout(animated: false)
            self.isOverviewMorphTransitionRunning = false
        }
    }
    
    private func animatePhoneOverviewDismissal() {
        isOverviewMorphTransitionRunning = true
        let overviewIndex = overviewAnimationIndex()
        
        browserUI.tabOverviewContainer.isHidden = false
        browserUI.tabOverviewContainer.alpha = 1
        browserUI.tabOverviewBlurView.alpha = 1
        browserUI.overviewPhoneBottomBar.alpha = 1
        browserUI.overviewPhoneBottomSafeAreaFillView.alpha = 1
        view.bringSubviewToFront(browserUI.tabOverviewContainer)
        view.layoutIfNeeded()
        
        let indexPath = IndexPath(item: overviewIndex, section: 0)
        browserUI.tabOverviewCollectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        browserUI.tabOverviewCollectionView.layoutIfNeeded()
        
        guard let selectedCell = selectedOverviewCell(at: overviewIndex),
              let sourceFrame = selectedOverviewPreviewFrame(at: overviewIndex),
              let bottomSnapshot = browserUI.overviewPhoneBottomBar.snapshotView(afterScreenUpdates: false) else {
            isOverviewMorphTransitionRunning = false
            let finalProgress: CGFloat = 0
            applyOverviewProgress(finalProgress)
            isTabOverviewVisible = false
            browserUI.tabOverviewContainer.isHidden = true
            applyPendingOverviewTabSelectionIfNeeded()
            applyChromeLayout(animated: false)
            return
        }
        
        selectedCell.setTransitionHidden(true)
        
        let pageSnapshot = overviewPreviewSnapshotView(for: overviewIndex) ?? selectedCell.previewSnapshotView()
        guard let pageSnapshot else {
            isOverviewMorphTransitionRunning = false
            let finalProgress: CGFloat = 0
            applyOverviewProgress(finalProgress)
            isTabOverviewVisible = false
            browserUI.tabOverviewContainer.isHidden = true
            applyPendingOverviewTabSelectionIfNeeded()
            applyChromeLayout(animated: false)
            return
        }
        
        pageSnapshot.frame = sourceFrame
        pageSnapshot.layer.cornerRadius = 18
        pageSnapshot.layer.cornerCurve = .continuous
        pageSnapshot.layer.masksToBounds = true
        
        bottomSnapshot.frame = browserUI.overviewPhoneBottomBar.frame
        
        view.addSubview(pageSnapshot)
        view.addSubview(bottomSnapshot)
        
        browserUI.phoneChromeContainer.isHidden = false
        browserUI.phoneChromeContainer.alpha = 0
        browserUI.geckoView.isHidden = true
        browserUI.overviewPhoneBottomBar.alpha = 0
        
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseInOut]) {
            pageSnapshot.frame = self.browserUI.geckoView.frame
            pageSnapshot.layer.cornerRadius = 0
            bottomSnapshot.alpha = 0
            self.browserUI.tabOverviewBlurView.alpha = 0
            self.browserUI.tabOverviewCollectionView.alpha = 0
            self.browserUI.phoneChromeContainer.alpha = 1
            self.browserUI.overviewPhoneBottomSafeAreaFillView.alpha = 0
        } completion: { _ in
            pageSnapshot.removeFromSuperview()
            bottomSnapshot.removeFromSuperview()
            selectedCell.setTransitionHidden(false)
            
            self.applyPendingOverviewTabSelectionIfNeeded()
            
            self.browserUI.geckoView.isHidden = false
            self.browserUI.tabOverviewCollectionView.alpha = 1
            self.browserUI.tabOverviewCollectionView.transform = .identity
            self.browserUI.tabOverviewContainer.alpha = 0
            self.browserUI.tabOverviewContainer.isHidden = true
            self.browserUI.tabOverviewBlurView.alpha = 1
            self.browserUI.overviewPhoneBottomBar.alpha = 1
            self.browserUI.overviewPhoneBottomSafeAreaFillView.alpha = 1
            
            self.isTabOverviewVisible = false
            self.currentOverviewProgress = 0
            self.applyChromeLayout(animated: false)
            self.isOverviewMorphTransitionRunning = false
        }
    }
    
    private func animatePadOverviewPresentation() {
        isOverviewMorphTransitionRunning = true
        
        captureThumbnail(for: selectedTabIndex)
        browserUI.tabOverviewCollectionView.reloadData()
        browserUI.tabOverviewContainer.isHidden = false
        browserUI.tabOverviewContainer.alpha = 1
        browserUI.tabOverviewBlurView.alpha = 0
        browserUI.overviewPadTopBar.alpha = 0
        view.bringSubviewToFront(browserUI.tabOverviewContainer)
        view.endEditing(true)
        view.layoutIfNeeded()
        
        let indexPath = IndexPath(item: selectedTabIndex, section: 0)
        tabOverviewDismissTargetIndex = selectedTabIndex
        browserUI.tabOverviewCollectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        browserUI.tabOverviewCollectionView.layoutIfNeeded()
        
        guard let selectedCell = selectedOverviewCell(at: selectedTabIndex),
              let targetFrame = selectedOverviewPreviewFrame(at: selectedTabIndex),
              let pageSnapshot = browserUI.geckoView.snapshotView(afterScreenUpdates: false) else {
            isOverviewMorphTransitionRunning = false
            applyOverviewProgress(1)
            isTabOverviewVisible = true
            applyChromeLayout(animated: false)
            return
        }
        
        selectedCell.setTransitionHidden(true)
        
        pageSnapshot.frame = browserUI.geckoView.frame
        pageSnapshot.layer.cornerRadius = 0
        pageSnapshot.layer.cornerCurve = .continuous
        pageSnapshot.layer.masksToBounds = true
        
        view.addSubview(pageSnapshot)
        browserUI.geckoView.isHidden = true
        
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseInOut]) {
            pageSnapshot.frame = targetFrame
            pageSnapshot.layer.cornerRadius = 18
            self.browserUI.tabOverviewBlurView.alpha = 1
            self.browserUI.overviewPadTopBar.alpha = 1
            self.browserUI.padTopBar.alpha = 0
            self.browserUI.padTopSafeAreaFillView.alpha = 0
            self.browserUI.padTabStripCollectionView.alpha = 0
        } completion: { _ in
            pageSnapshot.removeFromSuperview()
            selectedCell.setTransitionHidden(false)
            
            self.browserUI.geckoView.isHidden = false
            self.isTabOverviewVisible = true
            self.currentOverviewProgress = 1
            self.applyChromeLayout(animated: false)
            self.isOverviewMorphTransitionRunning = false
        }
    }
    
    private func animatePadOverviewDismissal() {
        isOverviewMorphTransitionRunning = true
        let overviewIndex = overviewAnimationIndex()
        
        browserUI.tabOverviewContainer.isHidden = false
        browserUI.tabOverviewContainer.alpha = 1
        browserUI.tabOverviewBlurView.alpha = 1
        browserUI.overviewPadTopBar.alpha = 1
        view.bringSubviewToFront(browserUI.tabOverviewContainer)
        view.layoutIfNeeded()
        
        let indexPath = IndexPath(item: overviewIndex, section: 0)
        browserUI.tabOverviewCollectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        browserUI.tabOverviewCollectionView.layoutIfNeeded()
        
        guard let selectedCell = selectedOverviewCell(at: overviewIndex),
              let sourceFrame = selectedOverviewPreviewFrame(at: overviewIndex) else {
            isOverviewMorphTransitionRunning = false
            applyOverviewProgress(0)
            isTabOverviewVisible = false
            browserUI.tabOverviewContainer.isHidden = true
            applyPendingOverviewTabSelectionIfNeeded()
            applyChromeLayout(animated: false)
            return
        }
        
        selectedCell.setTransitionHidden(true)
        
        let pageSnapshot = overviewPreviewSnapshotView(for: overviewIndex) ?? selectedCell.previewSnapshotView()
        guard let pageSnapshot else {
            isOverviewMorphTransitionRunning = false
            applyOverviewProgress(0)
            isTabOverviewVisible = false
            browserUI.tabOverviewContainer.isHidden = true
            applyPendingOverviewTabSelectionIfNeeded()
            applyChromeLayout(animated: false)
            return
        }
        
        pageSnapshot.frame = sourceFrame
        pageSnapshot.layer.cornerRadius = 18
        pageSnapshot.layer.cornerCurve = .continuous
        pageSnapshot.layer.masksToBounds = true
        
        view.addSubview(pageSnapshot)
        
        browserUI.geckoView.isHidden = true
        browserUI.padTopBar.alpha = 0
        browserUI.padTopSafeAreaFillView.alpha = 0
        browserUI.padTabStripCollectionView.alpha = 0
        
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseInOut]) {
            pageSnapshot.frame = self.browserUI.geckoView.frame
            pageSnapshot.layer.cornerRadius = 0
            self.browserUI.tabOverviewBlurView.alpha = 0
            self.browserUI.tabOverviewCollectionView.alpha = 0
            self.browserUI.overviewPadTopBar.alpha = 0
            self.browserUI.padTopBar.alpha = 1
            self.browserUI.padTopSafeAreaFillView.alpha = 1
            self.browserUI.padTabStripCollectionView.alpha = 1
        } completion: { _ in
            pageSnapshot.removeFromSuperview()
            selectedCell.setTransitionHidden(false)
            
            self.applyPendingOverviewTabSelectionIfNeeded()
            
            self.browserUI.geckoView.isHidden = false
            self.browserUI.tabOverviewCollectionView.alpha = 1
            self.browserUI.tabOverviewCollectionView.transform = .identity
            self.browserUI.tabOverviewContainer.alpha = 0
            self.browserUI.tabOverviewContainer.isHidden = true
            self.browserUI.tabOverviewBlurView.alpha = 1
            self.browserUI.overviewPadTopBar.alpha = 1
            
            self.isTabOverviewVisible = false
            self.currentOverviewProgress = 0
            self.applyChromeLayout(animated: false)
            self.isOverviewMorphTransitionRunning = false
        }
    }
    
    private func selectedOverviewCell(at index: Int) -> TabGridCell? {
        guard tabs.indices.contains(index) else {
            return nil
        }
        let indexPath = IndexPath(item: index, section: 0)
        return browserUI.tabOverviewCollectionView.cellForItem(at: indexPath) as? TabGridCell
    }
    
    private func selectedOverviewPreviewFrame(at index: Int) -> CGRect? {
        guard let cell = selectedOverviewCell(at: index) else {
            return nil
        }
        return cell.previewFrame(in: view)
    }
    
    func applyOverviewProgress(_ progress: CGFloat) {
        let clamped = max(0, min(1, progress))
        currentOverviewProgress = clamped
        
        browserUI.tabOverviewContainer.alpha = clamped
        
        let collectionOffset = (1 - clamped) * 26
        browserUI.tabOverviewCollectionView.transform = CGAffineTransform(translationX: 0, y: collectionOffset)
        
        let pageScale = 1 - (0.08 * clamped)
        browserUI.geckoView.transform = CGAffineTransform(scaleX: pageScale, y: pageScale)
        
        if usesPadChromeLayout {
            browserUI.padTopBar.alpha = 1 - clamped
            browserUI.padTopSafeAreaFillView.alpha = 1 - clamped
            browserUI.padTabStripCollectionView.alpha = 1 - clamped
        } else {
            browserUI.phoneChromeContainer.alpha = 1 - clamped
            browserUI.phoneChromeContainer.transform = CGAffineTransform(translationX: 0, y: 24 * clamped)
        }
    }
    
}
