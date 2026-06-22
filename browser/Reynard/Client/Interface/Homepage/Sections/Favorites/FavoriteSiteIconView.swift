//
//  FavoriteSiteIconView.swift
//  Reynard
//
//  Created by Minh Ton on 22/6/26.
//

import UIKit

final class FavoriteSiteIconView: UIView {
    private static let faviconStore = FaviconStore.shared
    private static let fallbackIconName = "reynard.globe"
    
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.tintColor = .secondaryLabel
        return view
    }()
    
    private var representedURL: URL?
    private var faviconTask: Task<Void, Never>?
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        faviconTask?.cancel()
    }
    
    // MARK: - Public API
    
    func configure(bookmark: BookmarkSnapshot) {
        representedURL = bookmark.url
        faviconTask?.cancel()
        faviconTask = nil
        
        if let namedImage = UIImage(named: Self.bundledIconName(for: bookmark.url)) {
            applyIcon(namedImage, tintColor: nil)
            return
        }
        
        if let cachedImage = Self.faviconStore.cachedFavicon(for: bookmark.url) {
            applyIcon(cachedImage, tintColor: nil)
            return
        }
        
        applyFallbackIcon()
        let expectedURL = bookmark.url
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
                
                let fallbackImage = UIImage(named: Self.fallbackIconName)
                self.applyIcon(
                    image ?? fallbackImage,
                    tintColor: image == nil ? .secondaryLabel : nil
                )
            }
        }
    }
    
    func reset() {
        representedURL = nil
        faviconTask?.cancel()
        faviconTask = nil
        applyFallbackIcon()
    }
    
    // MARK: - Configuration
    
    private func configureView() {
        backgroundColor = .clear
        addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        applyFallbackIcon()
    }
    
    // MARK: - Icon Loading
    
    private func applyIcon(_ image: UIImage?, tintColor: UIColor?) {
        imageView.image = image
        imageView.tintColor = tintColor
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
}
