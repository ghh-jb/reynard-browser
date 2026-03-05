//
//  TopBarButtons.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import UIKit

final class PadTopBarButtons {
    lazy var backButton = MakeButtons.makeToolbarButton(controller: controller, imageName: "chevron.backward", action: #selector(BrowserViewController.padBackTapped))
    lazy var forwardButton = MakeButtons.makeToolbarButton(controller: controller, imageName: "chevron.forward", action: #selector(BrowserViewController.padForwardTapped))
    lazy var shareButton = MakeButtons.makeToolbarButton(controller: controller, imageName: "square.and.arrow.up", action: #selector(BrowserViewController.shareTapped))
    lazy var newTabButton = MakeButtons.makeToolbarButton(controller: controller, imageName: "plus", action: #selector(BrowserViewController.newTabTapped))
    lazy var tabOverviewButton = MakeButtons.makeToolbarButton(controller: controller, imageName: "square.on.square", action: #selector(BrowserViewController.tabsTapped))
    
    lazy var leftStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [backButton, forwardButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually
        return stack
    }()
    
    lazy var rightStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [shareButton, newTabButton, tabOverviewButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually
        return stack
    }()
    
    var leftLeadingConstraint: NSLayoutConstraint!
    var rightTrailingConstraint: NSLayoutConstraint!
    var leftWidthConstraint: NSLayoutConstraint!
    var rightWidthConstraint: NSLayoutConstraint!
    var leftHeightConstraint: NSLayoutConstraint!
    var rightHeightConstraint: NSLayoutConstraint!
    
    private unowned let controller: BrowserViewController
    
    init(controller: BrowserViewController) {
        self.controller = controller
    }
}
