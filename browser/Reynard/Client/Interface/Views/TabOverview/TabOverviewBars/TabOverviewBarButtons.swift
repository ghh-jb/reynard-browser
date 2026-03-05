//
//  TabOverviewBarButtons.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import UIKit

final class TabOverviewBarButtons {
    lazy var clearButton: UIButton = {
        MakeButtons.makeTabOverviewBarButton(controller: controller, imageName: "trash", isFilled: false, action: #selector(BrowserViewController.clearAllTabsTapped))
    }()
    
    lazy var addButton: UIButton = {
        MakeButtons.makeTabOverviewBarButton(controller: controller, imageName: "plus", isFilled: false, action: #selector(BrowserViewController.newTabTapped))
    }()
    
    lazy var doneButton: UIButton = {
        MakeButtons.makeTabOverviewBarButton(controller: controller, imageName: "checkmark", isFilled: true, action: #selector(BrowserViewController.doneTapped))
    }()
    
    lazy var actionStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [clearButton, addButton, doneButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        return stack
    }()
    
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var centerYConstraint: NSLayoutConstraint?
    
    private unowned let controller: BrowserViewController
    
    init(controller: BrowserViewController) {
        self.controller = controller
        
        NSLayoutConstraint.activate([
            clearButton.widthAnchor.constraint(equalToConstant: 42),
            clearButton.heightAnchor.constraint(equalTo: clearButton.widthAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 42),
            addButton.heightAnchor.constraint(equalTo: addButton.widthAnchor),
            doneButton.widthAnchor.constraint(equalToConstant: 42),
            doneButton.heightAnchor.constraint(equalTo: doneButton.widthAnchor),
        ])
    }
    
    func attach(to hostView: UIView) {
        if actionStack.superview !== hostView {
            actionStack.removeFromSuperview()
            hostView.addSubview(actionStack)
            
            leadingConstraint = actionStack.leadingAnchor.constraint(equalTo: hostView.leadingAnchor, constant: 32)
            trailingConstraint = actionStack.trailingAnchor.constraint(equalTo: hostView.trailingAnchor, constant: -32)
            centerYConstraint = actionStack.centerYAnchor.constraint(equalTo: hostView.centerYAnchor)
            
            NSLayoutConstraint.activate([
                leadingConstraint,
                trailingConstraint,
                centerYConstraint,
            ].compactMap { $0 })
        }
    }
}
