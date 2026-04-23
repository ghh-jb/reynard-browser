//
//  PadTabCell.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import UIKit

final class PadTabCell: UICollectionViewCell {
    static let reuseIdentifier = "PadTabCell"
    
    private static let fallbackFavicon = UIImage(systemName: "globe")
    
    var onClose: (() -> Void)?
    
    private let faviconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .secondaryLabel
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.textAlignment = .center
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "x.square.fill"), for: .normal)
        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 14, weight: .regular),
            forImageIn: .normal
        )
        button.tintColor = .secondaryLabel
        button.isHidden = true
        return button
    }()
    
    private let separatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .separator
        return view
    }()
    
    private let titleStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 6
        return stackView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.layer.cornerRadius = 0
        
        contentView.addSubview(titleStackView)
        titleStackView.addArrangedSubview(faviconImageView)
        titleStackView.addArrangedSubview(titleLabel)
        contentView.addSubview(closeButton)
        contentView.addSubview(separatorView)
        
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            titleStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleStackView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 10),
            titleStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -34),
            
            faviconImageView.widthAnchor.constraint(equalToConstant: 16),
            faviconImageView.heightAnchor.constraint(equalToConstant: 16),
            
            titleLabel.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, constant: -58),
            
            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            closeButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 22),
            closeButton.heightAnchor.constraint(equalToConstant: 22),
            
            separatorView.topAnchor.constraint(equalTo: contentView.topAnchor),
            separatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separatorView.widthAnchor.constraint(equalToConstant: 2 / UIScreen.main.scale),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        faviconImageView.image = Self.fallbackFavicon
        onClose = nil
    }
    
    func configure(tab: Tab, selected: Bool) {
        titleLabel.text = tab.title.isEmpty ? "Homepage" : tab.title
        faviconImageView.image = tab.favicon ?? Self.fallbackFavicon
        contentView.backgroundColor = selected ? .systemGray6 : .systemGray5
        titleLabel.textColor = selected ? .label : .secondaryLabel
        faviconImageView.tintColor = selected ? .label : .secondaryLabel
        closeButton.isHidden = !selected
        separatorView.isHidden = selected
    }
    
    @objc private func closeTapped() {
        onClose?()
    }
}
