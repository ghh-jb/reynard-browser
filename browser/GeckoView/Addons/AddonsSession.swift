//
//  AddonsSession.swift
//  Reynard
//
//  Created by Minh Ton on 28/4/26.
//

import Foundation

public extension GeckoSession {
    func setAddonTabActive(_ active: Bool) {
        dispatcher.dispatch(type: "GeckoView:WebExtension:SetTabActive", message: ["active": active])
    }
}
