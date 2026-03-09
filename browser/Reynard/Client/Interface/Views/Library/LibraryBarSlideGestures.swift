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
        gesture.minimumPressDuration = 0.18
        gesture.allowableMovement = .greatestFiniteMagnitude
        gesture.cancelsTouchesInView = false
        view.addGestureRecognizer(gesture)
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
}
