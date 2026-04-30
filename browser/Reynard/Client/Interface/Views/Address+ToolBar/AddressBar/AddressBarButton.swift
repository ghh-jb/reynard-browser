//
//  AddressBarButton.swift
//  Reynard
//
//  Created by Minh Ton on 29/4/26.
//

import UIKit

final class AddressBarButton: UIButton {
    var hitArea: CGFloat = 2
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAppearance()
    }
    
    private func configureAppearance() {
        imageView?.contentMode = .scaleAspectFit
        contentHorizontalAlignment = .fill
        contentVerticalAlignment = .fill
        contentEdgeInsets = .zero
        setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 14, weight: .regular), forImageIn: .normal)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard isUserInteractionEnabled, !isHidden, alpha > 0 else {
            return false
        }
        
        let bounds = self.bounds
        let widthIncrease  = bounds.width  * (hitArea - 1) / 2
        let heightIncrease = bounds.height * (hitArea - 1) / 2
        let hitFrame = bounds.insetBy(dx: -widthIncrease, dy: -heightIncrease)
        
        return hitFrame.contains(point)
    }
}
