//
//  AddressBar.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import UIKit

protocol AddressBarDelegate: AnyObject {
    func addressBarDidSubmit(_ searchTerm: String)
    func addressBarDidBeginEditing(_ addressBar: AddressBar)
    func addressBarDidEndEditing(_ addressBar: AddressBar)
}

final class AddressBar: UIView {
    private weak var delegate: AddressBarDelegate?
    private var shadowEnabled = true
    private var showsSearchIconWhenPlaceholder = true
    private var currentText: String?
    private var currentTextIsCommittedLocation = false
    private var canDisplayHostOnly = false
    private var addonsMenu: UIMenu?
    private var urlFieldLeadingToIconConstraint: NSLayoutConstraint!
    private var urlFieldLeadingToBarConstraint: NSLayoutConstraint!
    private var displayLabelLeadingToIconConstraint: NSLayoutConstraint!
    private var displayLabelLeadingToBarConstraint: NSLayoutConstraint!
    private var displayLabelTrailingToIconConstraint: NSLayoutConstraint!
    private var displayLabelTrailingToBarConstraint: NSLayoutConstraint!
    
    private let backgroundFillView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? .tertiarySystemBackground : .systemBackground
        }
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()
    
    private let leadingButton: AddressBarButton = {
        let button = AddressBarButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .secondaryLabel
        button.showsMenuAsPrimaryAction = true
        button.isUserInteractionEnabled = false
        return button
    }()
    
    private let urlField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.placeholder = "Search or enter website name"
        field.keyboardType = .default
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.textContentType = .none
        field.returnKeyType = .go
        field.clearButtonMode = .whileEditing
        return field
    }()
    
    private let displayLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = .label
        label.font = .systemFont(ofSize: 17)
        label.lineBreakMode = .byTruncatingMiddle
        label.isUserInteractionEnabled = false
        return label
    }()
    
    private let progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.progressTintColor = .label
        view.trackTintColor = .clear
        view.isHidden = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.cornerCurve = .continuous
        layer.cornerRadius = 16
        layer.shadowColor = traitCollection.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.3).cgColor : UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 2)
        clipsToBounds = false
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(delegate: AddressBarDelegate) {
        self.delegate = delegate
        urlField.delegate = self
        urlField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    func setText(_ text: String?, isCommittedLocation: Bool = false, canDisplayHostOnly: Bool = false) {
        currentText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        currentTextIsCommittedLocation = isCommittedLocation
        self.canDisplayHostOnly = canDisplayHostOnly
        if !urlField.isFirstResponder {
            urlField.text = currentText
        }
        updateDisplayState()
    }
    
    func setAddonsMenu(_ menu: UIMenu?) {
        addonsMenu = menu
        updateDisplayState()
    }
    
    func setShowsSearchIconWhenPlaceholder(_ showsSearchIconWhenPlaceholder: Bool) {
        self.showsSearchIconWhenPlaceholder = showsSearchIconWhenPlaceholder
        updateDisplayState()
    }
    
    func setShadowEnabled(_ enabled: Bool) {
        shadowEnabled = enabled
        layer.shadowOpacity = enabled ? 0.12 : 0
        setNeedsLayout()
    }
    
    func getText() -> String? {
        urlField.text
    }
    
    func setLoadingProgress(_ progress: Float, isLoading: Bool) {
        progressView.progress = progress
        progressView.isHidden = !isLoading
    }
    
    var isEditingText: Bool {
        urlField.isFirstResponder
    }
    
    override var canBecomeFirstResponder: Bool {
        urlField.canBecomeFirstResponder
    }
    
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        urlField.becomeFirstResponder()
    }
    
    @discardableResult
    override func resignFirstResponder() -> Bool {
        urlField.resignFirstResponder()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = shadowEnabled ? UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath : nil
    }
    
    private func setupView() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBarTap))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
        
        addSubview(backgroundFillView)
        backgroundFillView.addSubview(leadingButton)
        backgroundFillView.addSubview(urlField)
        backgroundFillView.addSubview(displayLabel)
        backgroundFillView.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            backgroundFillView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundFillView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundFillView.topAnchor.constraint(equalTo: topAnchor),
            backgroundFillView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            leadingButton.leadingAnchor.constraint(equalTo: backgroundFillView.leadingAnchor, constant: 12),
            leadingButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            leadingButton.widthAnchor.constraint(equalToConstant: 18),
            leadingButton.heightAnchor.constraint(equalToConstant: 18),
            
            urlField.topAnchor.constraint(equalTo: backgroundFillView.topAnchor),
            urlField.bottomAnchor.constraint(equalTo: backgroundFillView.bottomAnchor),
            urlField.trailingAnchor.constraint(equalTo: backgroundFillView.trailingAnchor, constant: -12),
            
            displayLabel.topAnchor.constraint(equalTo: backgroundFillView.topAnchor),
            displayLabel.bottomAnchor.constraint(equalTo: backgroundFillView.bottomAnchor),
            
            progressView.leadingAnchor.constraint(equalTo: backgroundFillView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: backgroundFillView.trailingAnchor),
            progressView.bottomAnchor.constraint(equalTo: backgroundFillView.bottomAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
        ])
        
        urlFieldLeadingToIconConstraint = urlField.leadingAnchor.constraint(equalTo: leadingButton.trailingAnchor, constant: 8)
        urlFieldLeadingToBarConstraint = urlField.leadingAnchor.constraint(equalTo: backgroundFillView.leadingAnchor, constant: 12)
        displayLabelLeadingToIconConstraint = displayLabel.leadingAnchor.constraint(equalTo: leadingButton.trailingAnchor, constant: 8)
        displayLabelLeadingToBarConstraint = displayLabel.leadingAnchor.constraint(equalTo: backgroundFillView.leadingAnchor, constant: 12)
        displayLabelTrailingToIconConstraint = displayLabel.trailingAnchor.constraint(equalTo: backgroundFillView.trailingAnchor, constant: -38)
        displayLabelTrailingToBarConstraint = displayLabel.trailingAnchor.constraint(equalTo: backgroundFillView.trailingAnchor, constant: -12)
        urlFieldLeadingToIconConstraint.isActive = true
        displayLabelLeadingToBarConstraint.isActive = true
        displayLabelTrailingToBarConstraint.isActive = true
        
        updateDisplayState()
    }
    
    private func updateDisplayState() {
        let hasText = !(currentText?.isEmpty ?? true)
        let isEditing = urlField.isFirstResponder
        let hasVisibleTypedText = !(urlField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let isEditingCommittedLocation = currentTextIsCommittedLocation && isEditing
        let isShowingPlaceholder = isEditing ? !hasVisibleTypedText : !hasText
        
        if !isEditing {
            displayLabel.text = displayedText(hasText: hasText)
            displayLabel.isHidden = !hasText
            urlField.isHidden = hasText
            urlField.textAlignment = .natural
        } else {
            displayLabel.isHidden = true
            urlField.isHidden = false
            urlField.textAlignment = .natural
        }
        
        if currentTextIsCommittedLocation && !isEditing {
            leadingButton.isHidden = false
            leadingButton.tintColor = .label
            leadingButton.setImage(UIImage(systemName: "list.bullet.below.rectangle"), for: .normal)
            leadingButton.menu = addonsMenu
            leadingButton.isUserInteractionEnabled = addonsMenu != nil
            urlFieldLeadingToIconConstraint.isActive = false
            urlFieldLeadingToBarConstraint.isActive = true
            displayLabelLeadingToBarConstraint.isActive = false
            displayLabelTrailingToBarConstraint.isActive = false
            displayLabelLeadingToIconConstraint.isActive = true
            displayLabelTrailingToIconConstraint.isActive = true
        } else if isEditingCommittedLocation {
            leadingButton.isHidden = true
            leadingButton.menu = nil
            leadingButton.isUserInteractionEnabled = false
            urlFieldLeadingToIconConstraint.isActive = false
            urlFieldLeadingToBarConstraint.isActive = true
            displayLabelLeadingToIconConstraint.isActive = false
            displayLabelTrailingToIconConstraint.isActive = false
            displayLabelLeadingToBarConstraint.isActive = true
            displayLabelTrailingToBarConstraint.isActive = true
        } else if showsSearchIconWhenPlaceholder && !isEditing && isShowingPlaceholder {
            leadingButton.isHidden = false
            leadingButton.tintColor = .secondaryLabel
            leadingButton.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
            leadingButton.menu = nil
            leadingButton.isUserInteractionEnabled = false
            urlFieldLeadingToBarConstraint.isActive = false
            urlFieldLeadingToIconConstraint.isActive = true
            displayLabelLeadingToIconConstraint.isActive = false
            displayLabelTrailingToIconConstraint.isActive = false
            displayLabelLeadingToBarConstraint.isActive = true
            displayLabelTrailingToBarConstraint.isActive = true
        } else {
            leadingButton.isHidden = true
            leadingButton.menu = nil
            leadingButton.isUserInteractionEnabled = false
            urlFieldLeadingToIconConstraint.isActive = false
            urlFieldLeadingToBarConstraint.isActive = true
            displayLabelLeadingToIconConstraint.isActive = false
            displayLabelTrailingToIconConstraint.isActive = false
            displayLabelLeadingToBarConstraint.isActive = true
            displayLabelTrailingToBarConstraint.isActive = true
        }
    }
    
    private func displayedText(hasText: Bool) -> String? {
        guard hasText else {
            return nil
        }
        
        guard let currentText else {
            return nil
        }
        
        if canDisplayHostOnly,
           let host = URL(string: currentText)?.host,
           !host.isEmpty {
            return host
        }
        
        return currentText
    }
    
    @objc
    private func handleBarTap() {
        guard !urlField.isFirstResponder else {
            return
        }
        
        urlField.becomeFirstResponder()
    }
    
    @objc
    private func textFieldDidChange() {
        if urlField.isFirstResponder {
            updateDisplayState()
        }
    }
}

extension AddressBar: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let searchText = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !searchText.isEmpty else {
            return false
        }
        
        delegate?.addressBarDidSubmit(searchText)
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if let currentText,
           !currentText.isEmpty {
            textField.text = currentText
        }
        updateDisplayState()
        delegate?.addressBarDidBeginEditing(self)
        
        guard let value = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return
        }
        
        DispatchQueue.main.async {
            guard textField.isFirstResponder else {
                return
            }
            textField.selectAll(nil)
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        currentText = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        currentTextIsCommittedLocation = false
        canDisplayHostOnly = false
        updateDisplayState()
        delegate?.addressBarDidEndEditing(self)
    }
}

extension AddressBar: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view?.isDescendant(of: leadingButton) == true {
            return false
        }
        
        if touch.view?.isDescendant(of: urlField) == true {
            return false
        }
        
        return true
    }
}
