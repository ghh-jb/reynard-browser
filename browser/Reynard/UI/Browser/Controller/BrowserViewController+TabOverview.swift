//
//  BrowserViewController+TabOverview.swift
//  Reynard
//
//  Created by Minh Ton on 4/3/26.
//

import UIKit

extension BrowserViewController {
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
                self.browserUI.tabOverviewContainer.isHidden = true
                self.applyOverviewProgress(0)
            }
            self.applyChromeLayout(animated: false)
        }
        
        if animated {
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseInOut], animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
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
        browserUI.tabOverviewCollectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        browserUI.tabOverviewCollectionView.layoutIfNeeded()
        
        guard let selectedCell = selectedOverviewCell(),
              let targetFrame = selectedOverviewPreviewFrame(),
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
        
        browserUI.tabOverviewContainer.isHidden = false
        browserUI.tabOverviewContainer.alpha = 1
        browserUI.tabOverviewBlurView.alpha = 1
        browserUI.overviewPhoneBottomBar.alpha = 1
        browserUI.overviewPhoneBottomSafeAreaFillView.alpha = 1
        view.bringSubviewToFront(browserUI.tabOverviewContainer)
        view.layoutIfNeeded()
        
        let indexPath = IndexPath(item: selectedTabIndex, section: 0)
        browserUI.tabOverviewCollectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        browserUI.tabOverviewCollectionView.layoutIfNeeded()
        
        guard let selectedCell = selectedOverviewCell(),
              let sourceFrame = selectedOverviewPreviewFrame(),
              let pageSnapshot = selectedCell.previewSnapshotView(),
              let bottomSnapshot = browserUI.overviewPhoneBottomBar.snapshotView(afterScreenUpdates: false) else {
            isOverviewMorphTransitionRunning = false
            let finalProgress: CGFloat = 0
            applyOverviewProgress(finalProgress)
            isTabOverviewVisible = false
            browserUI.tabOverviewContainer.isHidden = true
            applyChromeLayout(animated: false)
            return
        }
        
        selectedCell.setTransitionHidden(true)
        
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
        browserUI.tabOverviewCollectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        browserUI.tabOverviewCollectionView.layoutIfNeeded()
        
        guard let selectedCell = selectedOverviewCell(),
              let targetFrame = selectedOverviewPreviewFrame(),
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
        
        browserUI.tabOverviewContainer.isHidden = false
        browserUI.tabOverviewContainer.alpha = 1
        browserUI.tabOverviewBlurView.alpha = 1
        browserUI.overviewPadTopBar.alpha = 1
        view.bringSubviewToFront(browserUI.tabOverviewContainer)
        view.layoutIfNeeded()
        
        let indexPath = IndexPath(item: selectedTabIndex, section: 0)
        browserUI.tabOverviewCollectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        browserUI.tabOverviewCollectionView.layoutIfNeeded()
        
        guard let selectedCell = selectedOverviewCell(),
              let sourceFrame = selectedOverviewPreviewFrame(),
              let pageSnapshot = selectedCell.previewSnapshotView() else {
            isOverviewMorphTransitionRunning = false
            applyOverviewProgress(0)
            isTabOverviewVisible = false
            browserUI.tabOverviewContainer.isHidden = true
            applyChromeLayout(animated: false)
            return
        }
        
        selectedCell.setTransitionHidden(true)
        
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
    
    private func selectedOverviewCell() -> TabGridCell? {
        guard tabs.indices.contains(selectedTabIndex) else {
            return nil
        }
        let indexPath = IndexPath(item: selectedTabIndex, section: 0)
        return browserUI.tabOverviewCollectionView.cellForItem(at: indexPath) as? TabGridCell
    }
    
    private func selectedOverviewPreviewFrame() -> CGRect? {
        guard let cell = selectedOverviewCell() else {
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
