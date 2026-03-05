//
//  BrowserToolbarView.swift
//  Reynard
//
//  Created by Minh Ton on 4/3/26.
//

import UIKit

protocol BrowserToolbarViewDelegate: AnyObject {
    func backButtonClicked()
    func forwardButtonClicked()
    func shareButtonClicked()
    func menuButtonClicked()
    func tabsButtonClicked()
}

final class BrowserToolbarView: UIView {
    weak var delegate: BrowserToolbarViewDelegate?
    
    private let backButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let menuButton = UIButton(type: .system)
    private let tabsButton = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .clear
        
        backButton.translatesAutoresizingMaskIntoConstraints = false
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        tabsButton.translatesAutoresizingMaskIntoConstraints = false
        
        backButton.tintColor = .label
        forwardButton.tintColor = .label
        shareButton.tintColor = .label
        menuButton.tintColor = .label
        tabsButton.tintColor = .label
        
        backButton.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        forwardButton.setImage(UIImage(systemName: "chevron.forward"), for: .normal)
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        menuButton.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
        tabsButton.setImage(UIImage(systemName: "square.on.square"), for: .normal)
        shareButton.isEnabled = false
        
        backButton.addTarget(self, action: #selector(backButtonClicked), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(forwardButtonClicked), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareButtonClicked), for: .touchUpInside)
        menuButton.addTarget(self, action: #selector(menuButtonClicked), for: .touchUpInside)
        tabsButton.addTarget(self, action: #selector(tabsButtonClicked), for: .touchUpInside)
        
        let stack = UIStackView(arrangedSubviews: [backButton, forwardButton, shareButton, menuButton, tabsButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.spacing = 8
        
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateBackButton(canGoBack: Bool) {
        backButton.isEnabled = canGoBack
    }
    
    func updateForwardButton(canGoForward: Bool) {
        forwardButton.isEnabled = canGoForward
    }
    
    func updateShareButton(isEnabled: Bool) {
        shareButton.isEnabled = isEnabled
    }
    
    @objc func backButtonClicked() {
        delegate?.backButtonClicked()
    }
    
    @objc func forwardButtonClicked() {
        delegate?.forwardButtonClicked()
    }
    
    @objc func shareButtonClicked() {
        delegate?.shareButtonClicked()
    }
    
    @objc func menuButtonClicked() {
        delegate?.menuButtonClicked()
    }
    
    @objc func tabsButtonClicked() {
        delegate?.tabsButtonClicked()
    }
}
