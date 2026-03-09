//
//  LibraryBarSlideGestures.swift
//  Reynard
//
//  Created by Minh Ton on 9/3/26.
//

import UIKit

final class LibraryBarSlideGestures: NSObject {
    private weak var hostView: UIView?
    private let currentSection: () -> LibrarySection
    private let sectionAtPoint: (CGPoint) -> LibrarySection?
    private let selectSection: (LibrarySection) -> Void
    private var isTrackingActiveTab = false
    private var suppressedPanRecognizers: [UIGestureRecognizer] = []
    private var directInteractionDepth = 0
    
    init(
        hostView: UIView,
        currentSection: @escaping () -> LibrarySection,
        sectionAtPoint: @escaping (CGPoint) -> LibrarySection?,
        selectSection: @escaping (LibrarySection) -> Void
    ) {
        self.hostView = hostView
        self.currentSection = currentSection
        self.sectionAtPoint = sectionAtPoint
        self.selectSection = selectSection
        super.init()
    }
    
    func beginDirectInteraction(from section: LibrarySection) {
        directInteractionDepth += 1
        guard directInteractionDepth == 1 else {
            return
        }
        
        isTrackingActiveTab = section == currentSection()
        
        suppressAncestorPanGestures()
    }
    
    func updateDirectInteraction(at point: CGPoint) {
        guard isTrackingActiveTab,
              let section = sectionAtPoint(point),
              section != currentSection() else {
            return
        }
        
        selectSection(section)
    }
    
    func endDirectInteraction() {
        guard directInteractionDepth > 0 else {
            return
        }
        
        directInteractionDepth -= 1
        guard directInteractionDepth == 0 else {
            return
        }
        
        isTrackingActiveTab = false
        
        restoreAncestorPanGestures()
    }
    
    private func suppressAncestorPanGestures() {
        guard suppressedPanRecognizers.isEmpty,
              let hostView else {
            return
        }
        
        var ancestor: UIView? = hostView.superview
        while let view = ancestor {
            for recognizer in view.gestureRecognizers ?? [] where recognizer is UIPanGestureRecognizer {
                guard recognizer.isEnabled else {
                    continue
                }
                
                recognizer.isEnabled = false
                suppressedPanRecognizers.append(recognizer)
            }
            ancestor = view.superview
        }
    }
    
    private func restoreAncestorPanGestures() {
        guard !suppressedPanRecognizers.isEmpty else {
            return
        }
        
        for recognizer in suppressedPanRecognizers {
            recognizer.isEnabled = true
        }
        suppressedPanRecognizers.removeAll()
    }
}
