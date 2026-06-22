//
//  SearchAutocompleteProviderCell.swift
//  Reynard
//
//  Created by Minh Ton on 22/6/26.
//

import UIKit

final class SearchAutocompleteProviderCell: UITableViewCell {
    private enum UX {
        static let verticalInset: CGFloat = 10
        static let labelSpacing: CGFloat = 3
        static let selectedProviderSpacing: CGFloat = 12
    }
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let selectedProviderLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureLabels()
        installLabels()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func display(provider: SearchCompletion.Provider) {
        titleLabel.text = "Search Autocomplete"
        subtitleLabel.text = "Choose the provider for search query autocomplete in the address bar"
        selectedProviderLabel.text = provider.name
    }
    
    private func configureLabels() {
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.textColor = .label
        titleLabel.adjustsFontForContentSizeCategory = true
        
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.adjustsFontForContentSizeCategory = true
        
        selectedProviderLabel.font = .preferredFont(forTextStyle: .body)
        selectedProviderLabel.textColor = .secondaryLabel
        selectedProviderLabel.textAlignment = .right
        selectedProviderLabel.adjustsFontForContentSizeCategory = true
        selectedProviderLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        selectedProviderLabel.setContentHuggingPriority(.required, for: .horizontal)
    }
    
    private func installLabels() {
        let textStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStackView.translatesAutoresizingMaskIntoConstraints = false
        textStackView.axis = .vertical
        textStackView.spacing = UX.labelSpacing
        
        selectedProviderLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(textStackView)
        contentView.addSubview(selectedProviderLabel)
        NSLayoutConstraint.activate([
            textStackView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            textStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: UX.verticalInset),
            textStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -UX.verticalInset),
            
            selectedProviderLabel.leadingAnchor.constraint(greaterThanOrEqualTo: textStackView.trailingAnchor, constant: UX.selectedProviderSpacing),
            selectedProviderLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            selectedProviderLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
}
