//
//  BrowserViewController+Gestures.swift
//  Reynard
//
//  Created by Minh Ton on 4/3/26.
//

import UIKit

extension BrowserViewController {
    func createAddressBarPreview(for tab: BrowserTab) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        container.layer.cornerCurve = .continuous
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.12
        container.layer.shadowRadius = 10
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.clipsToBounds = false
        
        let iconView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = .secondaryLabel
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .secondaryLabel
        label.text = tab.url ?? "Search or enter website name"
        label.lineBreakMode = .byTruncatingTail
        
        container.addSubview(iconView)
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        
        return container
    }
    
    func createContentPreview(for tab: BrowserTab) -> UIView {
        let preview = UIView()
        preview.backgroundColor = .systemBackground
        
        if let image = tab.thumbnail {
            let imageView = UIImageView(image: image)
            imageView.frame = preview.bounds
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            preview.addSubview(imageView)
        } else {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 28, weight: .bold)
            label.textColor = .secondaryLabel
            label.text = tab.title.isEmpty ? "Homepage" : tab.title
            label.textAlignment = .center
            label.numberOfLines = 2
            preview.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: preview.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: preview.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: preview.leadingAnchor, constant: 24),
                label.trailingAnchor.constraint(lessThanOrEqualTo: preview.trailingAnchor, constant: -24),
            ])
        }
        
        return preview
    }
    
    func updateHorizontalTabInteraction(translationX: CGFloat) {
        let direction = translationX < 0 ? 1 : -1
        
        if horizontalDirection != direction {
            cleanupHorizontalTransition()
            horizontalDirection = direction
        }
        
        if horizontalTargetIndex == nil {
            let candidate = selectedTabIndex + direction
            if tabs.indices.contains(candidate) {
                horizontalTargetIndex = candidate
                
                let targetTab = tabs[candidate]
                
                let targetContent = createContentPreview(for: targetTab)
                targetContent.frame = browserUI.geckoView.frame.offsetBy(dx: CGFloat(direction) * browserUI.geckoView.bounds.width, dy: 0)
                view.insertSubview(targetContent, belowSubview: browserUI.geckoView)
                horizontalTargetContentView = targetContent
                
                if let barHost = activeAddressBar.superview {
                    let targetBar = createAddressBarPreview(for: targetTab)
                    let outsidePadding: CGFloat = 24
                    let horizontalOffset = CGFloat(direction) * (activeAddressBar.bounds.width + outsidePadding)
                    targetBar.frame = activeAddressBar.frame.offsetBy(dx: horizontalOffset, dy: 0)
                    barHost.addSubview(targetBar)
                    horizontalTargetBarView = targetBar
                }
            }
        }
        
        if horizontalTargetIndex == nil {
            let damped = translationX * 0.18
            browserUI.geckoView.transform = CGAffineTransform(translationX: damped, y: 0)
            activeAddressBar.transform = CGAffineTransform(translationX: damped, y: 0)
            return
        }
        
        let transform = CGAffineTransform(translationX: translationX, y: 0)
        browserUI.geckoView.transform = transform
        activeAddressBar.transform = transform
        horizontalTargetContentView?.transform = transform
        horizontalTargetBarView?.transform = transform
    }
    
    func finishHorizontalTabInteraction(translationX: CGFloat, velocityX: CGFloat) {
        let width = browserUI.geckoView.bounds.width
        let shouldSwitch = horizontalTargetIndex != nil && (abs(translationX) > width * 0.28 || abs(velocityX) > 700)
        let shouldCreateNewTab = !usesPadChromeLayout
        && horizontalTargetIndex == nil
        && selectedTabIndex == tabs.count - 1
        && horizontalDirection == 1
        && (abs(translationX) > width * 0.28 || velocityX < -700)
        
        if shouldSwitch, let targetIndex = horizontalTargetIndex {
            let finalTranslation = CGFloat(-horizontalDirection) * width
            UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseOut]) {
                let transform = CGAffineTransform(translationX: finalTranslation, y: 0)
                self.browserUI.geckoView.transform = transform
                self.activeAddressBar.transform = transform
                self.horizontalTargetContentView?.transform = transform
                self.horizontalTargetBarView?.transform = transform
            } completion: { _ in
                self.cleanupHorizontalTransition()
                self.selectTab(at: targetIndex, animated: true)
            }
        } else if shouldCreateNewTab {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
                let transform = CGAffineTransform(translationX: -width * 0.34, y: 0)
                self.browserUI.geckoView.transform = transform
                self.activeAddressBar.transform = transform
            } completion: { _ in
                self.cleanupHorizontalTransition()
                self.createTab(selecting: true)
            }
        } else {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
                self.browserUI.geckoView.transform = .identity
                self.activeAddressBar.transform = .identity
                self.horizontalTargetContentView?.transform = .identity
                self.horizontalTargetBarView?.transform = .identity
            } completion: { _ in
                self.cleanupHorizontalTransition()
            }
        }
    }
    
    func cleanupHorizontalTransition() {
        browserUI.geckoView.transform = .identity
        activeAddressBar.transform = .identity
        
        horizontalTargetContentView?.removeFromSuperview()
        horizontalTargetBarView?.removeFromSuperview()
        
        horizontalTargetContentView = nil
        horizontalTargetBarView = nil
        horizontalTargetIndex = nil
        horizontalDirection = 0
    }
    
    @objc func handleSearchPan(_ recognizer: UIPanGestureRecognizer) {
        if usesPadChromeLayout {
            cleanupHorizontalTransition()
            searchPanMode = .blocked
            return
        }
        
        if isSearchFocused && recognizer.state == .began {
            return
        }
        
        let translation = recognizer.translation(in: view)
        let velocity = recognizer.velocity(in: view)
        
        switch recognizer.state {
        case .began:
            searchPanMode = .undecided
            cleanupHorizontalTransition()
            
        case .changed:
            if searchPanMode == .undecided {
                if abs(translation.x) < 6, abs(translation.y) < 6 {
                    return
                }
                
                if abs(translation.x) > abs(translation.y) {
                    searchPanMode = (!isTabOverviewVisible && !isSearchFocused) ? .horizontalTabs : .blocked
                } else {
                    searchPanMode = .blocked
                }
            }
            
            switch searchPanMode {
            case .horizontalTabs:
                updateHorizontalTabInteraction(translationX: translation.x)
            default:
                break
            }
            
        case .ended, .cancelled, .failed:
            switch searchPanMode {
            case .horizontalTabs:
                finishHorizontalTabInteraction(translationX: translation.x, velocityX: velocity.x)
            default:
                cleanupHorizontalTransition()
            }
            searchPanMode = .blocked
            
        default:
            break
        }
    }
    
    @objc func handleSearchSwipeUp(_ recognizer: UISwipeGestureRecognizer) {
        guard recognizer.state == .ended,
              !usesPadChromeLayout,
              !isSearchFocused,
              !isTabOverviewVisible,
              !isOverviewMorphTransitionRunning else {
            return
        }
        
        setTabOverviewVisible(true, animated: true)
    }
}

extension BrowserViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIButton {
            return false
        }
        return true
    }
}
