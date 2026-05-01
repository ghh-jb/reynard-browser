//
//  ChromeContainer.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import UIKit

final class ChromeContainer {
    let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        return view
    }()
    
    let bottomSafeAreaFillView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        return view
    }()
    
    var bottomConstraint: NSLayoutConstraint!
    var heightConstraint: NSLayoutConstraint!
}
