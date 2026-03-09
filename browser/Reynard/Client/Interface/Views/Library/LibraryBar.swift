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
            return "bookmark"
        case .history:
            return "clock"
        case .downloads:
            return "arrow.down.circle"
        case .settings:
            return "gearshape"
        }
    }
    
    var selectedSymbolName: String {
        switch self {
        case .bookmarks:
            return "bookmark.fill"
        case .history:
            return "clock.fill"
        case .downloads:
            return "arrow.down.circle.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}

protocol LibraryBarDelegate: AnyObject {
    func libraryBar(_ libraryBar: LibraryBar, didSelect section: LibrarySection)
}

private final class LibraryBarInteractionButton: UIControl {
    var onPressBegan: (() -> Void)?
    var onPressMoved: ((CGPoint) -> Void)?
    var onPressEnded: (() -> Void)?
    var onTap: (() -> Void)?
    
    private var initialTouchPoint: CGPoint = .zero
    private var hasDragged = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        initialTouchPoint = touch.location(in: self)
        hasDragged = false
        onPressBegan?()
        return super.beginTracking(touch, with: event)
    }
    
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let currentPoint = touch.location(in: self)
        let deltaX = currentPoint.x - initialTouchPoint.x
        let deltaY = currentPoint.y - initialTouchPoint.y
        
        if !hasDragged {
            hasDragged = hypot(deltaX, deltaY) >= 6
        }
        
        onPressMoved?(currentPoint)
        return super.continueTracking(touch, with: event)
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)
        
        if let touch, !hasDragged, bounds.contains(touch.location(in: self)) {
            onTap?()
        }
        
        hasDragged = false
        onPressEnded?()
    }
    
    override func cancelTracking(with event: UIEvent?) {
        super.cancelTracking(with: event)
        
        hasDragged = false
        onPressEnded?()
    }
}

private enum LibraryBarLayoutMetrics {
    static let insetIconSize: CGFloat = 26
    static let dockedIconSize: CGFloat = 26
    static let insetTopPadding: CGFloat = 10
    static let dockedTopPadding: CGFloat = 4
    static let insetBottomPadding: CGFloat = 8
    static let dockedBottomPadding: CGFloat = 3
    static let insetMinimumHeight: CGFloat = 60
    static let dockedMinimumHeight: CGFloat = 50
}

private final class LibraryBarButton: UIControl {
    private let section: LibrarySection
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
        label.font = .systemFont(ofSize: 10, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()
    
    private var stackTopConstraint: NSLayoutConstraint?
    private var stackBottomConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?
    private var iconWidthConstraint: NSLayoutConstraint?
    private var minimumHeightConstraint: NSLayoutConstraint?
    
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
        self.section = section
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
        
        stackTopConstraint = stack.topAnchor.constraint(equalTo: topAnchor, constant: LibraryBarLayoutMetrics.insetTopPadding)
        stackBottomConstraint = stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -LibraryBarLayoutMetrics.insetBottomPadding)
        iconHeightConstraint = iconView.heightAnchor.constraint(equalToConstant: LibraryBarLayoutMetrics.insetIconSize)
        iconWidthConstraint = iconView.widthAnchor.constraint(equalToConstant: LibraryBarLayoutMetrics.insetIconSize)
        minimumHeightConstraint = heightAnchor.constraint(greaterThanOrEqualToConstant: LibraryBarLayoutMetrics.insetMinimumHeight)
        
        NSLayoutConstraint.activate([
            stackTopConstraint,
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackBottomConstraint,
            iconHeightConstraint,
            iconWidthConstraint,
            minimumHeightConstraint,
        ].compactMap { $0 })
        
        accessibilityLabel = section.title
        updateAppearance()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateAppearance() {
        backgroundColor = .clear
        iconView.image = UIImage(systemName: isSelected ? section.selectedSymbolName : section.symbolName)
        iconView.tintColor = isSelected ? .label : .secondaryLabel
        titleLabel.textColor = isSelected ? .label : .secondaryLabel
        
        var traits: UIAccessibilityTraits = [.button]
        if isSelected {
            traits.insert(.selected)
        }
        accessibilityTraits = traits
    }
    
    func setUsesInsetLayout(_ usesInsetLayout: Bool) {
        stackTopConstraint?.constant = usesInsetLayout ? LibraryBarLayoutMetrics.insetTopPadding : LibraryBarLayoutMetrics.dockedTopPadding
        stackBottomConstraint?.constant = -(usesInsetLayout ? LibraryBarLayoutMetrics.insetBottomPadding : LibraryBarLayoutMetrics.dockedBottomPadding)
        iconHeightConstraint?.constant = usesInsetLayout ? LibraryBarLayoutMetrics.insetIconSize : LibraryBarLayoutMetrics.dockedIconSize
        iconWidthConstraint?.constant = usesInsetLayout ? LibraryBarLayoutMetrics.insetIconSize : LibraryBarLayoutMetrics.dockedIconSize
        minimumHeightConstraint?.constant = usesInsetLayout ? LibraryBarLayoutMetrics.insetMinimumHeight : LibraryBarLayoutMetrics.dockedMinimumHeight
    }
}

final class LibraryBar: UIView {
    weak var delegate: LibraryBarDelegate?
    private let displayCornerRadius = (UIScreen.main.value(forKey: "_displayCornerRadius") as? NSNumber).map { CGFloat(truncating: $0) } ?? 0
    private var usesInsetLayout = true
    
    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? .secondarySystemBackground : .tertiarySystemFill
        }
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }()
    
    private let selectionView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
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
    private var interactionButtons: [LibrarySection: LibraryBarInteractionButton] = [:]
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
            
            let interactionButton = LibraryBarInteractionButton()
            interactionButton.tag = index
            interactionButton.onPressBegan = { [weak self] in
                self?.slideGestureCoordinator?.beginDirectInteraction(from: section)
            }
            interactionButton.onPressMoved = { [weak self, weak interactionButton] point in
                guard let self, let interactionButton else {
                    return
                }
                
                let pointInContainer = self.containerView.convert(point, from: interactionButton)
                self.slideGestureCoordinator?.updateDirectInteraction(at: pointInContainer)
            }
            interactionButton.onPressEnded = { [weak self] in
                self?.slideGestureCoordinator?.endDirectInteraction()
            }
            interactionButton.onTap = { [weak self] in
                self?.select(section)
            }
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
        
        updateLayoutMetrics()
        
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
    
    func setUsesInsetLayout(_ usesInsetLayout: Bool) {
        guard self.usesInsetLayout != usesInsetLayout else {
            return
        }
        
        self.usesInsetLayout = usesInsetLayout
        updateLayoutMetrics()
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
        let selectionCornerRadius = max(containerView.layer.cornerRadius - 4, 0)
        return roundedPath(
            in: rect,
            topLeft: selectionCornerRadius,
            topRight: selectionCornerRadius,
            bottomRight: selectionCornerRadius,
            bottomLeft: selectionCornerRadius
        )
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
    
    private func updateLayoutMetrics() {
        containerView.layer.cornerRadius = usesInsetLayout ? max(0, displayCornerRadius - 18) : displayCornerRadius
        selectionView.backgroundColor = usesInsetLayout ? UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? .tertiarySystemFill : .secondarySystemBackground
        } : .clear
        for button in buttons.values {
            button.setUsesInsetLayout(usesInsetLayout)
        }
        setNeedsLayout()
    }
    
}
