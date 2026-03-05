//
//  TabGridCell.swift
//  Reynard
//
//  Created by Minh Ton on 4/3/26.
//

import UIKit

final class TabGridCell: UICollectionViewCell {
    static let reuseIdentifier = "TabGridCell"
    
    var onClose: (() -> Void)?
    
    private let previewShadowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.18
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
        view.backgroundColor = .secondarySystemBackground
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
        button.backgroundColor = .tertiarySystemFill
        button.tintColor = .secondaryLabel
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
        contentView.addSubview(titleLabel)
        
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            previewShadowView.topAnchor.constraint(equalTo: cardView.topAnchor),
            previewShadowView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            previewShadowView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            previewShadowView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            
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
            
            titleLabel.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        previewImageView.image = nil
        onClose = nil
        contentView.alpha = 1
    }
    
    func configure(tab: BrowserTab) {
        titleLabel.text = tab.title.isEmpty ? "Homepage" : tab.title
        previewImageView.image = tab.thumbnail
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
