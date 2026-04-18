//
//  GeckoView.swift
//  Reynard
//
//  Created by Minh Ton on 1/2/26.
//

import UIKit

public class GeckoView: UIView {
    var lastTouchPoint: CGPoint?
    
    public var session: GeckoSession? {
        didSet {
            lastTouchPoint = nil
            
            for view in subviews {
                view.removeFromSuperview()
            }
            
            guard let session else {
                return
            }
            
            guard let window = session.window else {
                NSLog("GeckoView: session window is unavailable during assignment")
                return
            }
            
            guard let sessionView = window.view() else {
                NSLog("GeckoView: session window has no view!")
                return
            }
            
            if sessionView.superview != nil {
                fatalError("attempt to assign GeckoSession to multiple GeckoView instances")
            }
            
            sessionView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(sessionView)
            
            NSLayoutConstraint.activate([
                sessionView.topAnchor.constraint(equalTo: topAnchor),
                sessionView.leadingAnchor.constraint(equalTo: leadingAnchor),
                sessionView.bottomAnchor.constraint(equalTo: bottomAnchor),
                sessionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    // This is for the file input fallback hack
    // TODO: A better workaround?
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if event?.type == .touches {
            lastTouchPoint = point
        }
        return super.hitTest(point, with: event)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
