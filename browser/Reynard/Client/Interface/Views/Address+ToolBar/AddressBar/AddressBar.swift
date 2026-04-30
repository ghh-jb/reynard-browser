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
    func addressBarDidTapTrailingButton(_ addressBar: AddressBar)
}

final class AddressBar: UIView {
    static let placeholderText = "Search or enter website name"
    
    private weak var delegate: AddressBarDelegate?
    private var shadowEnabled = true
    private var showsSearchIconWhenPlaceholder = true
    private var currentText: String?
    private var currentLocationText: String?
    private var currentLocationTitle: String?
    private var currentTextIsCommittedLocation = false
    private var isLoading = false
    private var addonsMenu: UIMenu?
    private var urlFieldLeadingToIconConstraint: NSLayoutConstraint!
    private var urlFieldLeadingToBarConstraint: NSLayoutConstraint!
    private var urlFieldTrailingToButtonConstraint: NSLayoutConstraint!
    private var urlFieldTrailingToBarConstraint: NSLayoutConstraint!
    private var displayLabelLeadingToIconConstraint: NSLayoutConstraint!
    private var displayLabelLeadingToBarConstraint: NSLayoutConstraint!
    private var displayLabelTrailingToButtonConstraint: NSLayoutConstraint!
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
    
    private let trailingButton: AddressBarButton = {
        let button = AddressBarButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .label
        button.isHidden = true
        button.isUserInteractionEnabled = false
        return button
    }()
    
    private let urlField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.placeholder = AddressBar.placeholderText
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
        label.textAlignment = .left
        label.textColor = .label
        label.font = .systemFont(ofSize: 17)
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
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
    
    func setText(
        _ text: String?,
        locationText: String? = nil,
        locationTitle: String? = nil,
        isCommittedLocation: Bool = false
    ) {
        currentText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        currentLocationText = locationText?.trimmingCharacters(in: .whitespacesAndNewlines)
        currentLocationTitle = locationTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        currentTextIsCommittedLocation = isCommittedLocation
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
        self.isLoading = isLoading
        updateDisplayState()
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
        backgroundFillView.addSubview(trailingButton)
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
            
            trailingButton.trailingAnchor.constraint(equalTo: backgroundFillView.trailingAnchor, constant: -12),
            trailingButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            trailingButton.widthAnchor.constraint(equalToConstant: 18),
            trailingButton.heightAnchor.constraint(equalToConstant: 18),
            
            urlField.topAnchor.constraint(equalTo: backgroundFillView.topAnchor),
            urlField.bottomAnchor.constraint(equalTo: backgroundFillView.bottomAnchor),
            
            displayLabel.topAnchor.constraint(equalTo: backgroundFillView.topAnchor),
            displayLabel.bottomAnchor.constraint(equalTo: backgroundFillView.bottomAnchor),
            
            progressView.leadingAnchor.constraint(equalTo: backgroundFillView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: backgroundFillView.trailingAnchor),
            progressView.bottomAnchor.constraint(equalTo: backgroundFillView.bottomAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
        ])
        
        urlFieldLeadingToIconConstraint = urlField.leadingAnchor.constraint(equalTo: leadingButton.trailingAnchor, constant: 8)
        urlFieldLeadingToBarConstraint = urlField.leadingAnchor.constraint(equalTo: backgroundFillView.leadingAnchor, constant: 12)
        urlFieldTrailingToButtonConstraint = urlField.trailingAnchor.constraint(equalTo: trailingButton.leadingAnchor, constant: -8)
        urlFieldTrailingToBarConstraint = urlField.trailingAnchor.constraint(equalTo: backgroundFillView.trailingAnchor, constant: -12)
        displayLabelLeadingToIconConstraint = displayLabel.leadingAnchor.constraint(equalTo: leadingButton.trailingAnchor, constant: 8)
        displayLabelLeadingToBarConstraint = displayLabel.leadingAnchor.constraint(equalTo: backgroundFillView.leadingAnchor, constant: 12)
        displayLabelTrailingToButtonConstraint = displayLabel.trailingAnchor.constraint(equalTo: trailingButton.leadingAnchor, constant: -8)
        displayLabelTrailingToBarConstraint = displayLabel.trailingAnchor.constraint(equalTo: backgroundFillView.trailingAnchor, constant: -12)
        urlFieldLeadingToBarConstraint.isActive = true
        urlFieldTrailingToBarConstraint.isActive = true
        displayLabelLeadingToBarConstraint.isActive = true
        displayLabelTrailingToBarConstraint.isActive = true
        
        trailingButton.addTarget(self, action: #selector(handleTrailingButtonTap), for: .touchUpInside)
        
        updateDisplayState()
    }
    
    private func updateDisplayState() {
        let hasText = !(currentText?.isEmpty ?? true)
        let isEditing = urlField.isFirstResponder
        let hasVisibleTypedText = !(urlField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let isShowingPlaceholder = isEditing ? !hasVisibleTypedText : !hasText
        let shouldShowCommittedIcon = currentTextIsCommittedLocation && !isEditing
        let shouldShowPlaceholderIcon = showsSearchIconWhenPlaceholder && !isEditing && isShowingPlaceholder
        let shouldShowTrailingButton = !isEditing && (hasText || isLoading)
        let shouldShowLeadingButton = !isEditing
        let displayText = displayAttributedText()
        
        if isEditing {
            displayLabel.isHidden = true
            urlField.isHidden = false
            urlField.textAlignment = .left
        } else {
            displayLabel.attributedText = displayText
            displayLabel.isHidden = displayText == nil
            urlField.isHidden = hasText
            urlField.textAlignment = .left
        }
        
        if shouldShowLeadingButton {
            leadingButton.isHidden = false
            if shouldShowPlaceholderIcon {
                leadingButton.tintColor = .secondaryLabel
                leadingButton.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
                leadingButton.menu = nil
                leadingButton.isUserInteractionEnabled = false
            } else {
                leadingButton.tintColor = shouldShowCommittedIcon ? .label : .secondaryLabel
                leadingButton.setImage(UIImage(systemName: "list.bullet.below.rectangle"), for: .normal)
                leadingButton.menu = shouldShowCommittedIcon ? addonsMenu : nil
                leadingButton.isUserInteractionEnabled = shouldShowCommittedIcon && addonsMenu != nil
            }
        } else {
            leadingButton.isHidden = true
            leadingButton.setImage(nil, for: .normal)
            leadingButton.menu = nil
            leadingButton.isUserInteractionEnabled = false
        }
        
        if shouldShowTrailingButton {
            trailingButton.isHidden = false
            trailingButton.setImage(UIImage(systemName: isLoading ? "xmark" : "arrow.clockwise"), for: .normal)
            trailingButton.isUserInteractionEnabled = true
        } else {
            trailingButton.isHidden = true
            trailingButton.isUserInteractionEnabled = false
        }
        
        urlFieldLeadingToIconConstraint.isActive = shouldShowLeadingButton
        urlFieldLeadingToBarConstraint.isActive = !shouldShowLeadingButton
        urlFieldTrailingToButtonConstraint.isActive = shouldShowTrailingButton
        urlFieldTrailingToBarConstraint.isActive = !shouldShowTrailingButton
        displayLabelLeadingToIconConstraint.isActive = shouldShowLeadingButton
        displayLabelLeadingToBarConstraint.isActive = !shouldShowLeadingButton
        displayLabelTrailingToButtonConstraint.isActive = shouldShowTrailingButton
        displayLabelTrailingToBarConstraint.isActive = !shouldShowTrailingButton
    }
    
    private func displayAttributedText() -> NSAttributedString? {
        guard let currentText, !currentText.isEmpty else {
            return nil
        }
        
        guard currentTextIsCommittedLocation,
              let host = committedLocationHost() else {
            return NSAttributedString(
                string: currentText,
                attributes: [.foregroundColor: UIColor.label]
            )
        }
        
        let attributedText = NSMutableAttributedString(
            string: host,
            attributes: [.foregroundColor: UIColor.label]
        )
        attributedText.append(
            NSAttributedString(
                string: " / ",
                attributes: [.foregroundColor: UIColor.secondaryLabel]
            )
        )
        if let title = currentLocationTitle,
           !title.isEmpty {
            attributedText.append(
                NSAttributedString(
                    string: title,
                    attributes: [.foregroundColor: UIColor.secondaryLabel]
                )
            )
        }
        return attributedText
    }
    
    private func committedLocationHost() -> String? {
        let sourceText = currentLocationText ?? currentText
        guard let sourceText,
              let host = URL(string: sourceText)?.host,
              !host.isEmpty else {
            return nil
        }
        return host
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
    
    @objc
    private func handleTrailingButtonTap() {
        delegate?.addressBarDidTapTrailingButton(self)
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
        
        guard let value = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return
        }
        
        DispatchQueue.main.async {
            guard textField.isFirstResponder,
                  let text = textField.text,
                  !text.isEmpty else { return }
            
            let start = textField.beginningOfDocument
            if let caretRange = textField.textRange(from: start, to: start) {
                textField.selectedTextRange = caretRange
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard textField.isFirstResponder,
                      let text = textField.text,
                      !text.isEmpty else { return }
                
                let start = textField.beginningOfDocument
                let end = textField.endOfDocument
                if let range = textField.textRange(from: start, to: end) {
                    textField.selectedTextRange = range
                }
            }
        }
    }
    
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        currentText = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        currentLocationText = nil
        currentLocationTitle = nil
        currentTextIsCommittedLocation = false
        updateDisplayState()
        delegate?.addressBarDidEndEditing(self)
    }
}

extension AddressBar: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view?.isDescendant(of: leadingButton) == true {
            return false
        }
        
        if touch.view?.isDescendant(of: trailingButton) == true {
            return false
        }
        
        if touch.view?.isDescendant(of: urlField) == true {
            return false
        }
        
        return true
    }
}
