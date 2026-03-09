//
//  LibraryBar.swift
//  Reynard
//
//  Created by Minh Ton on 9/3/26.
//

import UIKit

enum LibrarySection: CaseIterable {
    case bookmarks
    case history
    case downloads
    case settings
    
    var title: String {
        switch self {
        case .bookmarks:
            return "Bookmarks"
        case .history:
            return "History"
        case .downloads:
            return "Downloads"
        case .settings:
            return "Settings"
        }
    }
    
    var symbolName: String {
        switch self {
        case .bookmarks:
            return "heart"
        case .history:
            return "clock"
        case .downloads:
            return "arrow.down.circle"
        case .settings:
            return "gearshape"
        }
    }
}

protocol LibraryBarDelegate: AnyObject {
    func libraryBar(_ libraryBar: LibraryBar, didSelect section: LibrarySection)
}

private final class LibraryBarButton: UIControl {
    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 23, weight: .regular)
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()
    
    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.85 : 1
        }
    }
    
    init(section: LibrarySection) {
        super.init(frame: .zero)
        
        translatesAutoresizingMaskIntoConstraints = false
        
        iconView.image = UIImage(systemName: section.symbolName)
        titleLabel.text = section.title
        
        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 0
        stack.isUserInteractionEnabled = false
        
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 66),
        ])
        
        accessibilityLabel = section.title
        updateAppearance()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateAppearance() {
        backgroundColor = .clear
        iconView.tintColor = isSelected ? .label : .secondaryLabel
        titleLabel.textColor = isSelected ? .label : .secondaryLabel
        
        var traits: UIAccessibilityTraits = [.button]
        if isSelected {
            traits.insert(.selected)
        }
        accessibilityTraits = traits
    }
}

final class LibraryBar: UIView {
    weak var delegate: LibraryBarDelegate?
    
    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? .secondarySystemBackground : UIColor(white: 0.95, alpha: 1)
        }
        view.layer.cornerRadius = 28
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }()
    
    private let selectionView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 0
        return stack
    }()
    
    private let interactionStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 0
        return stack
    }()
    
    private var buttons: [LibrarySection: LibraryBarButton] = [:]
    private var interactionButtons: [LibrarySection: UIView] = [:]
    private(set) var selectedSection: LibrarySection = .bookmarks
    private var selectionLeadingConstraint: NSLayoutConstraint?
    private var selectionWidthConstraint: NSLayoutConstraint?
    private let selectionMaskLayer = CAShapeLayer()
    private var slideGestureCoordinator: LibraryBarSlideGestures?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        translatesAutoresizingMaskIntoConstraints = false
        selectionView.layer.mask = selectionMaskLayer
        addSubview(containerView)
        containerView.addSubview(selectionView)
        containerView.addSubview(stackView)
        containerView.addSubview(interactionStackView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            interactionStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            interactionStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            interactionStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            interactionStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        
        selectionLeadingConstraint = selectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 0)
        selectionWidthConstraint = selectionView.widthAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            selectionView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            selectionView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4),
            selectionLeadingConstraint,
            selectionWidthConstraint,
        ].compactMap { $0 })
        
        for (index, section) in LibrarySection.allCases.enumerated() {
            let button = LibraryBarButton(section: section)
            button.tag = index
            buttons[section] = button
            stackView.addArrangedSubview(button)
            
            let interactionButton = UIView()
            interactionButton.translatesAutoresizingMaskIntoConstraints = false
            interactionButton.backgroundColor = .clear
            interactionButton.tag = index
            interactionButton.isUserInteractionEnabled = true
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(interactionTapped(_:)))
            interactionButton.addGestureRecognizer(tapGesture)
            interactionButtons[section] = interactionButton
            interactionStackView.addArrangedSubview(interactionButton)
        }
        
        slideGestureCoordinator = LibraryBarSlideGestures(
            hostView: containerView,
            currentSection: { [weak self] in
                self?.selectedSection ?? .bookmarks
            },
            sectionAtPoint: { [weak self] point in
                self?.section(at: point)
            },
            selectSection: { [weak self] section in
                self?.select(section)
            }
        )
        
        for section in LibrarySection.allCases {
            if let button = interactionButtons[section] {
                slideGestureCoordinator?.registerGestureView(button, section: section)
            }
        }
        
        select(.bookmarks, notify: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateSelectionIndicator(animated: false)
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateSelectionIndicator(animated: false)
        }
    }
    
    func select(_ section: LibrarySection, notify: Bool = true) {
        selectedSection = section
        for candidate in LibrarySection.allCases {
            buttons[candidate]?.isSelected = candidate == section
        }
        updateSelectionShape()
        updateSelectionIndicator(animated: window != nil)
        
        if notify {
            delegate?.libraryBar(self, didSelect: section)
        }
    }
    
    private func updateSelectionShape() {
        selectionMaskLayer.path = makeSelectionPath(in: selectionView.bounds).cgPath
    }
    
    private func updateSelectionIndicator(animated: Bool) {
        guard let button = buttons[selectedSection],
              let leadingConstraint = selectionLeadingConstraint,
              let widthConstraint = selectionWidthConstraint else {
            return
        }
        
        let horizontalInset: CGFloat = 4
        stackView.layoutIfNeeded()
        let frame = containerView.convert(button.frame, from: stackView)
        leadingConstraint.constant = frame.minX + horizontalInset
        widthConstraint.constant = max(0, frame.width - (horizontalInset * 2))
        
        guard animated else {
            layoutIfNeeded()
            updateSelectionShape()
            return
        }
        
        UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
            self.layoutIfNeeded()
            self.updateSelectionShape()
        }
    }
    
    private func makeSelectionPath(in rect: CGRect) -> UIBezierPath {
        roundedPath(in: rect, topLeft: 24, topRight: 24, bottomRight: 24, bottomLeft: 24)
    }
    
    private func roundedPath(in rect: CGRect, topLeft: CGFloat, topRight: CGFloat, bottomRight: CGFloat, bottomLeft: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let width = rect.width
        let height = rect.height
        guard width > 0, height > 0 else {
            return path
        }
        
        let maxRadius = min(width, height) / 2
        let tl = min(topLeft, maxRadius)
        let tr = min(topRight, maxRadius)
        let br = min(bottomRight, maxRadius)
        let bl = min(bottomLeft, maxRadius)
        
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 {
            path.addArc(withCenter: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 {
            path.addArc(withCenter: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 {
            path.addArc(withCenter: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 {
            path.addArc(withCenter: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        
        path.close()
        return path
    }
    
    private func section(at point: CGPoint) -> LibrarySection? {
        let pointInStack = interactionStackView.convert(point, from: containerView)
        return LibrarySection.allCases.first { section in
            guard let button = interactionButtons[section] else {
                return false
            }
            return button.frame.contains(pointInStack)
        }
    }
    
    @objc private func interactionTapped(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view,
              let section = LibrarySection.allCases.first(where: { interactionButtons[$0] === view }) else {
            return
        }
        
        select(section)
    }
}
