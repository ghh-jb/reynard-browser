//
//  MakeButtons.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import UIKit

enum MakeButtons {
    static func makeToolbarButton(target: AnyObject, imageName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: imageName), for: .normal)
        if imageName == "plus" {
            button.setPreferredSymbolConfiguration(
                UIImage.SymbolConfiguration(pointSize: 20, weight: .regular),
                forImageIn: .normal
            )
        }
        button.tintColor = .label
        button.addTarget(target, action: action, for: .touchUpInside)
        button.layer.cornerRadius = 10
        button.layer.cornerCurve = .continuous
        return button
    }
    
    static func makeToolbarButton(controller: BrowserViewController, imageName: String, action: Selector) -> UIButton {
        makeToolbarButton(target: controller, imageName: imageName, action: action)
    }
    
    static func makeTabOverviewBarButton(controller: BrowserViewController, imageName: String, isFilled: Bool, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: imageName), for: .normal)
        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 17, weight: .regular),
            forImageIn: .normal
        )
        button.tintColor = isFilled ? .systemBackground : .label
        button.backgroundColor = isFilled ? .label : .quaternarySystemFill
        button.layer.borderWidth = isFilled ? 0 : 1
        button.layer.borderColor = isFilled ? UIColor.clear.cgColor : UIColor.systemFill.cgColor
        button.layer.cornerCurve = .continuous
        button.layer.cornerRadius = 21
        button.addTarget(controller, action: action, for: .touchUpInside)
        return button
    }
}
