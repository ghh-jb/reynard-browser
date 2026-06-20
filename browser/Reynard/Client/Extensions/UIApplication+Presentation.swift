//
//  UIApplication+Presentation.swift
//  Reynard
//
//  Created by Minh Ton on 18/6/26.
//

import UIKit

extension UIApplication {
    var isSidebarOverlayWidth: Bool {
        guard
            let windowScene = connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            return false
        }
        
        return isSidebarOverlayWidth(forWindowWidth: window.bounds.width, screen: window.screen)
    }
    
    var shouldUseCompactPadLayout: Bool {
        guard
            let windowScene = connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            return false
        }
        
        return shouldUseCompactPadLayout(forWindowWidth: window.bounds.width, screen: window.screen)
    }
    
    var shouldUseBottomTabOverviewToolbar: Bool {
        guard
            let windowScene = connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            return false
        }
        
        return shouldUseBottomTabOverviewToolbar(forWindowWidth: window.bounds.width, screen: window.screen)
    }
    
    func isSidebarOverlayWidth(forWindowWidth windowWidth: CGFloat, screen: UIScreen) -> Bool {
        let screenWidth = max(screen.bounds.width, screen.bounds.height)
        return windowWidth <= (3.0 / 4.0) * screenWidth + 0.5
    }
    
    func shouldUseCompactPadLayout(forWindowWidth windowWidth: CGFloat, screen: UIScreen) -> Bool {
        let screenWidth = max(screen.bounds.width, screen.bounds.height)
        return windowWidth <= (2.0 / 5.0) * screenWidth + 0.5
    }
    
    func shouldUseBottomTabOverviewToolbar(forWindowWidth windowWidth: CGFloat, screen: UIScreen) -> Bool {
        let screenWidth = max(screen.bounds.width, screen.bounds.height)
        return windowWidth <= (3.0 / 5.0) * screenWidth + 0.5
    }
    
    func topViewController() -> UIViewController? {
        let rootViewController = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        
        guard let rootViewController else {
            return nil
        }
        
        return topViewController(from: rootViewController)
    }
    
    func topViewController(from rootViewController: UIViewController) -> UIViewController {
        var controller = rootViewController
        while let presentedController = controller.presentedViewController {
            controller = presentedController
        }
        return controller
    }
}
