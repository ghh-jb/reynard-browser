//
//  AddressBarView.swift
//  Reynard
//
//  Created by Minh Ton on 4/3/26.
//

import UIKit

protocol AddressBarViewDelegate: AnyObject {
    func addressBarDidSubmit(_ searchTerm: String)
    func addressBarDidBeginEditing(_ addressBar: AddressBarView)
    func addressBarDidEndEditing(_ addressBar: AddressBarView)
}

final class AddressBarView: UIView {
    private weak var delegate: AddressBarViewDelegate?
    private var shadowEnabled = true
    
    private let backgroundFillView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()
    
    private let iconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .secondaryLabel
        imageView.contentMode = .scaleAspectFit
        return imageView
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
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 2)
        clipsToBounds = false
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(delegate: AddressBarViewDelegate) {
        self.delegate = delegate
        urlField.delegate = self
    }
    
    func setText(_ text: String?) {
        urlField.text = text
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
    
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        urlField.becomeFirstResponder()
        return super.becomeFirstResponder()
    }
    
    @discardableResult
    override func resignFirstResponder() -> Bool {
        urlField.resignFirstResponder()
        return super.resignFirstResponder()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = shadowEnabled ? UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath : nil
    }
    
    private func setupView() {
        addSubview(backgroundFillView)
        backgroundFillView.addSubview(iconView)
        backgroundFillView.addSubview(urlField)
        backgroundFillView.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            backgroundFillView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundFillView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundFillView.topAnchor.constraint(equalTo: topAnchor),
            backgroundFillView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            iconView.leadingAnchor.constraint(equalTo: backgroundFillView.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            
            urlField.topAnchor.constraint(equalTo: backgroundFillView.topAnchor),
            urlField.bottomAnchor.constraint(equalTo: backgroundFillView.bottomAnchor),
            urlField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            urlField.trailingAnchor.constraint(equalTo: backgroundFillView.trailingAnchor, constant: -12),
            
            progressView.leadingAnchor.constraint(equalTo: backgroundFillView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: backgroundFillView.trailingAnchor),
            progressView.bottomAnchor.constraint(equalTo: backgroundFillView.bottomAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
        ])
    }
}

extension AddressBarView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let searchText = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !searchText.isEmpty else {
            return false
        }
        
        delegate?.addressBarDidSubmit(searchText)
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
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
        delegate?.addressBarDidEndEditing(self)
    }
}
