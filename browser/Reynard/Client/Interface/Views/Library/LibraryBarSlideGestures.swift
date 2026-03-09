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
    private var sectionsByView: [ObjectIdentifier: LibrarySection] = [:]
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
    
    func registerGestureView(_ view: UIView, section: LibrarySection) {
        sectionsByView[ObjectIdentifier(view)] = section
        
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        gesture.minimumPressDuration = 0.08
        gesture.allowableMovement = .greatestFiniteMagnitude
        gesture.cancelsTouchesInView = false
        view.addGestureRecognizer(gesture)
    }
    
    func beginDirectInteraction() {
        directInteractionDepth += 1
        guard directInteractionDepth == 1 else {
            return
        }
        
        suppressAncestorPanGestures()
    }
    
    func endDirectInteraction() {
        guard directInteractionDepth > 0 else {
            return
        }
        
        directInteractionDepth -= 1
        guard directInteractionDepth == 0 else {
            return
        }
        
        restoreAncestorPanGestures()
    }
    
    @objc private func handleGesture(_ gesture: UILongPressGestureRecognizer) {
        guard let hostView else {
            return
        }
        
        let point = gesture.location(in: hostView)
        
        switch gesture.state {
        case .began:
            guard let gestureView = gesture.view,
                  let section = sectionsByView[ObjectIdentifier(gestureView)],
                  section == currentSection() else {
                isTrackingActiveTab = false
                return
            }
            isTrackingActiveTab = true
            
        case .changed:
            guard isTrackingActiveTab, let section = sectionAtPoint(point) else {
                return
            }
            
            if section != currentSection() {
                selectSection(section)
            }
            
        case .ended, .cancelled, .failed:
            isTrackingActiveTab = false
            
        default:
            break
        }
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
