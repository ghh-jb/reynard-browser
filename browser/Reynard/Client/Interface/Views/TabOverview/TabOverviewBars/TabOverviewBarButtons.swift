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
    
    lazy var clearBarButtonItem: UIBarButtonItem = {
        MakeButtons.makeTabOverviewBarButtonItem(controller: controller, systemItem: .trash, action: #selector(BrowserViewController.clearAllTabsTapped))
    }()
    
    lazy var addBarButtonItem: UIBarButtonItem = {
        MakeButtons.makeTabOverviewBarButtonItem(controller: controller, systemItem: .add, action: #selector(BrowserViewController.newTabTapped))
    }()
    
    lazy var doneBarButtonItem: UIBarButtonItem = {
        MakeButtons.makeTabOverviewBarButtonItem(controller: controller, systemItem: .done, action: #selector(BrowserViewController.doneTapped))
    }()
    
    lazy var actionStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [clearButton, addButton, doneButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        return stack
    }()
    
    lazy var actionToolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.items = [
            clearBarButtonItem,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            addBarButtonItem,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            doneBarButtonItem,
        ]
        return toolbar
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
        let controlsView = MakeButtons.hasLiquidGlass ? actionToolbar : actionStack
        
        guard controlsView.superview !== hostView else {
            return
        }
        
        actionStack.removeFromSuperview()
        actionToolbar.removeFromSuperview()
        NSLayoutConstraint.deactivate([
            leadingConstraint,
            trailingConstraint,
            centerYConstraint,
        ].compactMap { $0 })
        
        hostView.addSubview(controlsView)
        
        leadingConstraint = controlsView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor, constant: 32)
        trailingConstraint = controlsView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor, constant: -32)
        centerYConstraint = controlsView.centerYAnchor.constraint(equalTo: hostView.centerYAnchor)
        
        NSLayoutConstraint.activate([
            leadingConstraint,
            trailingConstraint,
            centerYConstraint,
        ].compactMap { $0 })
    }
}
