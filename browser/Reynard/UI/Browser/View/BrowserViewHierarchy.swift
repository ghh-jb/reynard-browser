//
//  BrowserViewHierarchy.swift
//  Reynard
//
//  Created by Minh Ton on 4/3/26.
//

import GeckoView
import UIKit

final class BrowserViewHierarchy {
    let geckoView: GeckoView = {
        let view = GeckoView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let phoneChromeContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        return view
    }()
    
    let phoneBottomSafeAreaFillView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        return view
    }()
    
    let phoneAddressBar: AddressBarView = {
        let bar = AddressBarView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()
    
    let phoneDismissKeyboardButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .secondaryLabel
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.alpha = 0
        button.isHidden = true
        return button
    }()
    
    let toolbarView: BrowserToolbarView = {
        let bar = BrowserToolbarView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()
    
    let padTopBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        return view
    }()
    
    let padTopSafeAreaFillView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        return view
    }()
    
    let padAddressBar: AddressBarView = {
        let bar = AddressBarView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()
    
    lazy var padBackButton = makePadButton(imageName: "chevron.backward", action: #selector(BrowserViewController.padBackTapped))
    lazy var padForwardButton = makePadButton(imageName: "chevron.forward", action: #selector(BrowserViewController.padForwardTapped))
    lazy var padShareButton = makePadButton(imageName: "square.and.arrow.up", action: #selector(BrowserViewController.shareTapped))
    lazy var padNewTabButton = makePadButton(imageName: "plus", action: #selector(BrowserViewController.newTabTapped))
    lazy var padTabOverviewButton = makePadButton(imageName: "square.on.square", action: #selector(BrowserViewController.tabsTapped))
    
    lazy var padTabStripCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .zero
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        view.showsHorizontalScrollIndicator = false
        view.contentInset = .zero
        view.contentInsetAdjustmentBehavior = .never
        view.dataSource = controller
        view.delegate = controller
        view.register(TabStripCell.self, forCellWithReuseIdentifier: TabStripCell.reuseIdentifier)
        return view
    }()
    
    let tabOverviewContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        view.alpha = 0
        view.isHidden = true
        return view
    }()
    
    let tabOverviewBlurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var tabOverviewCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = overviewSpacing
        layout.minimumInteritemSpacing = overviewSpacing
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.alwaysBounceVertical = true
        view.contentInset = UIEdgeInsets(top: overviewInset, left: overviewInset, bottom: overviewInset, right: overviewInset)
        view.dataSource = controller
        view.delegate = controller
        view.register(TabGridCell.self, forCellWithReuseIdentifier: TabGridCell.reuseIdentifier)
        return view
    }()
    
    let overviewPhoneBottomBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    let overviewPhoneBottomSafeAreaFillView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    let overviewPadTopBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    lazy var overviewClearButton: UIButton = {
        makeOverviewCircleButton(imageName: "trash", isFilled: false, action: #selector(BrowserViewController.clearAllTabsTapped))
    }()
    
    lazy var overviewAddButton: UIButton = {
        makeOverviewCircleButton(imageName: "plus", isFilled: false, action: #selector(BrowserViewController.newTabTapped))
    }()
    
    lazy var overviewDoneButton: UIButton = {
        makeOverviewCircleButton(imageName: "checkmark", isFilled: true, action: #selector(BrowserViewController.doneTapped))
    }()
    
    lazy var overviewPadClearButton: UIButton = {
        makeOverviewCircleButton(imageName: "trash", isFilled: false, action: #selector(BrowserViewController.clearAllTabsTapped))
    }()
    
    lazy var overviewPadAddButton: UIButton = {
        makeOverviewCircleButton(imageName: "plus", isFilled: false, action: #selector(BrowserViewController.newTabTapped))
    }()
    
    lazy var overviewPadDoneButton: UIButton = {
        makeOverviewCircleButton(imageName: "checkmark", isFilled: true, action: #selector(BrowserViewController.doneTapped))
    }()
    
    var geckoTopPhoneConstraint: NSLayoutConstraint!
    var geckoTopPadConstraint: NSLayoutConstraint!
    var geckoBottomPhoneConstraint: NSLayoutConstraint!
    var geckoBottomPhoneKeyboardOverlayConstraint: NSLayoutConstraint!
    var geckoBottomPadConstraint: NSLayoutConstraint!
    var geckoLeadingPhoneConstraint: NSLayoutConstraint!
    var geckoTrailingPhoneConstraint: NSLayoutConstraint!
    var geckoLeadingPadConstraint: NSLayoutConstraint!
    var geckoTrailingPadConstraint: NSLayoutConstraint!
    
    var phoneChromeBottomConstraint: NSLayoutConstraint!
    var phoneChromeHeightConstraint: NSLayoutConstraint!
    var phoneToolbarHeightConstraint: NSLayoutConstraint!
    var phoneAddressBarTrailingFullConstraint: NSLayoutConstraint!
    var phoneAddressBarTrailingFocusedConstraint: NSLayoutConstraint!
    var padTabStripHeightConstraint: NSLayoutConstraint!
    
    var overviewCollectionTopPhoneConstraint: NSLayoutConstraint!
    var overviewCollectionBottomPhoneConstraint: NSLayoutConstraint!
    var overviewCollectionTopPadConstraint: NSLayoutConstraint!
    var overviewCollectionBottomPadConstraint: NSLayoutConstraint!
    var overviewPhoneBottomBarBottomConstraint: NSLayoutConstraint!
    
    private unowned let controller: BrowserViewController
    private let overviewInset: CGFloat
    private let overviewSpacing: CGFloat
    
    init(controller: BrowserViewController, overviewInset: CGFloat, overviewSpacing: CGFloat) {
        self.controller = controller
        self.overviewInset = overviewInset
        self.overviewSpacing = overviewSpacing
        
        phoneAddressBar.configure(delegate: controller)
        padAddressBar.configure(delegate: controller)
        toolbarView.delegate = controller
    }
    
    private func makePadButton(imageName: String, action: Selector) -> UIButton {
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
        button.addTarget(controller, action: action, for: .touchUpInside)
        button.layer.cornerRadius = 10
        button.layer.cornerCurve = .continuous
        return button
    }
    
    private func makeOverviewCircleButton(imageName: String, isFilled: Bool, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: imageName), for: .normal)
        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 17, weight: .regular),
            forImageIn: .normal
        )
        button.tintColor = isFilled ? .systemBackground : .label
        button.backgroundColor = isFilled ? .label : .systemBackground
        button.layer.borderWidth = isFilled ? 0 : 1
        button.layer.borderColor = isFilled ? UIColor.clear.cgColor : UIColor.systemGray3.cgColor
        button.layer.cornerCurve = .continuous
        button.layer.cornerRadius = 21
        button.addTarget(controller, action: action, for: .touchUpInside)
        return button
    }
}
