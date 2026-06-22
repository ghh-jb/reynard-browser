//
//  FavoriteCollectionViewCell.swift
//  Reynard
//
//  Created by Minh Ton on 21/6/26.
//

import UIKit

final class FavoriteCollectionViewCell: UICollectionViewCell {
    private enum UX {
        static let maximumIconSize: CGFloat = 74
        static let iconCornerRadius: CGFloat = 17
        static let titleHeight: CGFloat = 34
        static let titleFontSize: CGFloat = 12
        static let shadowOpacity: Float = 0.18
        static let shadowRadius: CGFloat = 8
        static let shadowOffset = CGSize(width: 0, height: 3)
    }
    
    static let reuseIdentifier = "FavoriteCollectionViewCell"
    
    private static let faviconStore = FaviconStore.shared
    private static let fallbackIconName = "reynard.globe"
    private static let titleFont = UIFontMetrics(forTextStyle: .caption1).scaledFont(
        for: .systemFont(ofSize: UX.titleFontSize, weight: .semibold)
    )
    
    private let shadowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.clipsToBounds = false
        view.layer.shadowOpacity = UX.shadowOpacity
        view.layer.shadowRadius = UX.shadowRadius
        view.layer.shadowOffset = UX.shadowOffset
        return view
    }()
    
    private let iconBackgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = UX.iconCornerRadius
        view.clipsToBounds = true
        return view
    }()
    
    private let iconView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.tintColor = .secondaryLabel
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = FavoriteCollectionViewCell.titleFont
        label.textAlignment = .center
        label.textColor = .label
        label.numberOfLines = 2
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private var representedURL: URL?
    private var faviconTask: Task<Void, Never>?
    private var shadowWidthConstraint: NSLayoutConstraint?
    private var shadowHeightConstraint: NSLayoutConstraint?
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        representedURL = nil
        faviconTask?.cancel()
        faviconTask = nil
        titleLabel.text = nil
        applyFallbackIcon()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateIconSize()
        updateShadowColor()
    }
    
    deinit {
        faviconTask?.cancel()
    }
    
    // MARK: - Public API
    
    func configure(favorite: BookmarkSnapshot) {
        representedURL = favorite.url
        titleLabel.text = favorite.title
        faviconTask?.cancel()
        faviconTask = nil
        
        if let namedImage = UIImage(named: Self.bundledIconName(for: favorite.url)) {
            applyIcon(namedImage, tintColor: nil)
            return
        }
        
        if let cachedImage = Self.faviconStore.cachedFavicon(for: favorite.url) {
            applyIcon(cachedImage, tintColor: nil)
            return
        }
        
        applyFallbackIcon()
        let expectedURL = favorite.url
        faviconTask = Task { [weak self] in
            guard let self else {
                return
            }
            
            let image = await Self.faviconStore.favicon(for: expectedURL)
            guard !Task.isCancelled else {
                return
            }
            
            await MainActor.run {
                guard self.representedURL == expectedURL else {
                    return
                }
                
                self.applyIcon(image ?? UIImage(named: Self.fallbackIconName), tintColor: image == nil ? .secondaryLabel : nil)
            }
        }
    }
    
    // MARK: - Configuration
    
    private func configureCell() {
        configureAppearance()
        configureHierarchy()
        configureConstraints()
        applyFallbackIcon()
    }
    
    private func configureAppearance() {
        backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false
    }
    
    private func configureHierarchy() {
        contentView.addSubview(shadowView)
        shadowView.addSubview(iconBackgroundView)
        iconBackgroundView.addSubview(iconView)
        contentView.addSubview(titleLabel)
    }
    
    private func configureConstraints() {
        let shadowWidthConstraint = shadowView.widthAnchor.constraint(equalToConstant: UX.maximumIconSize)
        let shadowHeightConstraint = shadowView.heightAnchor.constraint(equalToConstant: UX.maximumIconSize)
        self.shadowWidthConstraint = shadowWidthConstraint
        self.shadowHeightConstraint = shadowHeightConstraint
        
        NSLayoutConstraint.activate([
            shadowView.topAnchor.constraint(equalTo: contentView.topAnchor),
            shadowView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            shadowWidthConstraint,
            shadowHeightConstraint,
            
            iconBackgroundView.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            iconBackgroundView.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),
            iconBackgroundView.topAnchor.constraint(equalTo: shadowView.topAnchor),
            iconBackgroundView.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor),
            
            iconView.leadingAnchor.constraint(equalTo: iconBackgroundView.leadingAnchor),
            iconView.trailingAnchor.constraint(equalTo: iconBackgroundView.trailingAnchor),
            iconView.topAnchor.constraint(equalTo: iconBackgroundView.topAnchor),
            iconView.bottomAnchor.constraint(equalTo: iconBackgroundView.bottomAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: shadowView.bottomAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: UX.titleHeight),
        ])
    }
    
    // MARK: - Icon Loading
    
    private func applyIcon(_ image: UIImage?, tintColor: UIColor?) {
        iconView.image = image
        iconView.tintColor = tintColor
    }
    
    private func applyFallbackIcon() {
        applyIcon(UIImage(named: Self.fallbackIconName), tintColor: .secondaryLabel)
    }
    
    private static func bundledIconName(for url: URL) -> String {
        var value = url.absoluteString
        
        if let schemeRange = value.range(of: "://") {
            value.removeSubrange(value.startIndex..<schemeRange.upperBound)
        }
        
        if value.hasPrefix("www.") {
            value.removeFirst(4)
        }
        
        while value.hasSuffix("/") {
            value.removeLast()
        }
        
        return value
    }
    
    // MARK: - Layout
    
    private func updateIconSize() {
        let iconSize = min(bounds.width, UX.maximumIconSize)
        if abs((shadowWidthConstraint?.constant ?? 0) - iconSize) > 0.5 {
            shadowWidthConstraint?.constant = iconSize
        }
        if abs((shadowHeightConstraint?.constant ?? 0) - iconSize) > 0.5 {
            shadowHeightConstraint?.constant = iconSize
        }
        iconBackgroundView.layer.cornerRadius = cornerRadius(for: iconSize)
    }
    
    private func updateShadowColor() {
        let iconSize = min(bounds.width, UX.maximumIconSize)
        shadowView.layer.shadowColor = traitCollection.userInterfaceStyle == .dark
        ? UIColor.white.cgColor
        : UIColor.black.cgColor
        shadowView.layer.shadowPath = UIBezierPath(
            roundedRect: CGRect(origin: .zero, size: CGSize(width: iconSize, height: iconSize)),
            cornerRadius: cornerRadius(for: iconSize)
        ).cgPath
    }
    
    private func cornerRadius(for iconSize: CGFloat) -> CGFloat {
        return iconSize / UX.maximumIconSize * UX.iconCornerRadius
    }
}
