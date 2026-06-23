//
//  GeckoStorageController.swift
//  Reynard
//
//  Created by Minh Ton on 23/6/26.
//

import Foundation

public enum GeckoStorageClearFlags {
    public static let cookies: Int64 = 1 << 0
    public static let networkCache: Int64 = 1 << 1
    public static let imageCache: Int64 = 1 << 2
    public static let domStorages: Int64 = 1 << 4
    public static let authSessions: Int64 = 1 << 5
    public static let allCaches: Int64 = networkCache | imageCache
}

public enum GeckoStorageController {
    public static func clearData(flags: Int64) async throws {
        _ = try await GeckoEventDispatcherWrapper.runtimeInstance.query(
            type: "GeckoView:ClearData",
            message: ["flags": flags]
        )
    }
    
    public static func clearTranslationModelCache() async {
        _ = try? await GeckoEventDispatcherWrapper.runtimeInstance.query(
            type: "GeckoView:Translations:ManageModel",
            message: [
                "operation": "delete",
                "operationLevel": "cache",
            ]
        )
    }
}
