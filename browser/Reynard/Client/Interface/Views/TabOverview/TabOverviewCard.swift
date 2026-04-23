//
//  TabOverviewCard.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import UIKit

final class TabOverviewCard: UICollectionViewCell {
    static let reuseIdentifier = "TabOverviewCard"
    
    private static let fallbackFavicon = UIImage(systemName: "globe")
    
    var onClose: (() -> Void)?
    
    private let previewShadowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.layer.shadowColor = UITraitCollection.current.userInterfaceStyle == .dark ? UIColor.white.cgColor : UIColor.black.cgColor
        view.layer.shadowOpacity = 0.12
        view.layer.shadowRadius = 8
        view.layer.shadowOffset = CGSize(width: 0, height: 3)
        view.layer.masksToBounds = false
        return view
    }()
    
    private let cardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    private let previewContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.layer.masksToBounds = true
        return view
    }()
    
    private let previewImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .clear
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 12, weight: .medium),
            forImageIn: .normal
        )
        button.backgroundColor = .systemGray.withAlphaComponent(0.6)
        button.tintColor = .white
        button.layer.cornerRadius = 12
        button.layer.cornerCurve = .continuous
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }()
    
    private let faviconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .secondaryLabel
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let titleContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 4
        return stackView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        clipsToBounds = false
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = false
        
        contentView.addSubview(cardView)
        cardView.addSubview(previewShadowView)
        cardView.addSubview(previewContainerView)
        previewContainerView.addSubview(previewImageView)
        previewContainerView.addSubview(closeButton)
        contentView.addSubview(titleContainerView)
        titleContainerView.addSubview(titleStackView)
        titleStackView.addArrangedSubview(faviconImageView)
        titleStackView.addArrangedSubview(titleLabel)
        
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            previewShadowView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 1),
            previewShadowView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 1),
            previewShadowView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -1),
            previewShadowView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -1),
            
            previewContainerView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 1),
            previewContainerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 1),
            previewContainerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -1),
            previewContainerView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -1),
            
            previewImageView.topAnchor.constraint(equalTo: previewContainerView.topAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: previewContainerView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: previewContainerView.trailingAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: previewContainerView.bottomAnchor),
            
            closeButton.topAnchor.constraint(equalTo: previewImageView.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: previewImageView.trailingAnchor, constant: -10),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),
            
            titleContainerView.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 4),
            titleContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            titleContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            titleContainerView.heightAnchor.constraint(equalToConstant: 18),
            titleContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            titleStackView.centerXAnchor.constraint(equalTo: titleContainerView.centerXAnchor),
            titleStackView.leadingAnchor.constraint(greaterThanOrEqualTo: titleContainerView.leadingAnchor),
            titleStackView.trailingAnchor.constraint(lessThanOrEqualTo: titleContainerView.trailingAnchor),
            titleStackView.centerYAnchor.constraint(equalTo: titleContainerView.centerYAnchor),
            
            faviconImageView.widthAnchor.constraint(equalToConstant: 16),
            faviconImageView.heightAnchor.constraint(equalToConstant: 16),
            
            titleLabel.widthAnchor.constraint(lessThanOrEqualTo: titleContainerView.widthAnchor, constant: -24),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        previewImageView.image = nil
        faviconImageView.image = Self.fallbackFavicon
        onClose = nil
        contentView.alpha = 1
        previewShadowView.layer.shadowColor = UITraitCollection.current.userInterfaceStyle == .dark ? UIColor.white.cgColor : UIColor.black.cgColor
    }
    
    func configure(tab: Tab) {
        titleLabel.text = tab.title.isEmpty ? "Homepage" : tab.title
        previewImageView.image = tab.thumbnail
        faviconImageView.image = tab.favicon ?? Self.fallbackFavicon
    }
    
    var currentPreviewImage: UIImage? {
        previewImageView.image
    }
    
    func previewFrame(in targetView: UIView) -> CGRect {
        cardView.convert(cardView.bounds, to: targetView)
    }
    
    func previewSnapshotView() -> UIView? {
        cardView.snapshotView(afterScreenUpdates: false)
    }
    
    func setTransitionHidden(_ hidden: Bool) {
        contentView.alpha = hidden ? 0 : 1
    }
    
    @objc private func closeTapped() {
        onClose?()
    }
}
