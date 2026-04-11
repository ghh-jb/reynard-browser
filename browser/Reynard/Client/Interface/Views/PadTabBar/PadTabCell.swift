//
//  PadTabCell.swift
//  Reynard
//
//  Created by Minh Ton on 5/3/26.
//

import UIKit

final class PadTabCell: UICollectionViewCell {
    static let reuseIdentifier = "PadTabCell"
    
    var onClose: (() -> Void)?
    
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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.layer.cornerRadius = 0
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(closeButton)
        contentView.addSubview(separatorView)
        
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
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
    
    func configure(title: String, selected: Bool) {
        titleLabel.text = title.isEmpty ? "Homepage" : title
        contentView.backgroundColor = selected ? .systemGray6 : .systemGray5
        titleLabel.textColor = selected ? .label : .secondaryLabel
        closeButton.isHidden = !selected
        separatorView.isHidden = selected
    }
    
    @objc private func closeTapped() {
        onClose?()
    }
}
