//
//  TabManagementStore.swift
//  Reynard
//
//  Created by Minh Ton on 4/4/26.
//

import Foundation
import UIKit

final class TabManagementStore {
    static let shared = TabManagementStore()
    
    enum LastTabOverview: String, Codable {
        case regular
        case `private`
    }
    
    struct Snapshot {
        let regularTabs: [TabSnapshot]
        let privateTabs: [TabSnapshot]
        let selectedRegularTabID: UUID?
        let selectedPrivateTabID: UUID?
        let selectedTabMode: TabMode
        let lastTabOverview: LastTabOverview
    }
    
    struct TabSnapshot {
        let id: UUID
        let title: String
        let url: String?
        let thumbnail: UIImage?
        let isPrivate: Bool
    }
    
    private struct StorageURLs {
        let directoryURL: URL
        let manifestFileURL: URL
        let thumbCacheDirectoryURL: URL
    }
    
    private struct PersistedState: Codable {
        let regularTabs: [PersistedTab]
        let privateTabs: [PersistedTab]
        let selectedRegularTabID: UUID?
        let selectedPrivateTabID: UUID?
        let selectedTabMode: TabMode
        let lastTabOverview: LastTabOverview
    }
    
    private struct PersistedTab: Codable {
        let id: UUID
        let title: String
        let url: String?
    }
    
    private let fileManager: FileManager
    private let storage: StorageURLs
    private let stateQueue = DispatchQueue(label: "com.minh-ton.tab-management-store", qos: .userInitiated)
    private var persistedState = PersistedState(
        regularTabs: [],
        privateTabs: [],
        selectedRegularTabID: nil,
        selectedPrivateTabID: nil,
        selectedTabMode: .regular,
        lastTabOverview: .regular
    )
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        guard let applicationSupportDirectoryURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory is unavailable")
        }
        
        let directoryURL = applicationSupportDirectoryURL
            .appendingPathComponent("AppData", isDirectory: true)
            .appendingPathComponent("TabManagement", isDirectory: true)
        let manifestFileURL = directoryURL.appendingPathComponent("TabManagementStore", isDirectory: false)
        let thumbCacheDirectoryURL = directoryURL.appendingPathComponent("ThumbCache", isDirectory: true)
        self.storage = StorageURLs(
            directoryURL: directoryURL,
            manifestFileURL: manifestFileURL,
            thumbCacheDirectoryURL: thumbCacheDirectoryURL
        )
        
        stateQueue.sync {
            prepareStorageLocked()
            loadPersistedStateLocked()
        }
    }
    
    func loadSnapshot() -> Snapshot {
        stateQueue.sync {
            Snapshot(
                regularTabs: persistedState.regularTabs.map { tabSnapshot(from: $0, isPrivate: false) },
                privateTabs: persistedState.privateTabs.map { tabSnapshot(from: $0, isPrivate: true) },
                selectedRegularTabID: persistedState.selectedRegularTabID,
                selectedPrivateTabID: persistedState.selectedPrivateTabID,
                selectedTabMode: persistedState.selectedTabMode,
                lastTabOverview: persistedState.lastTabOverview
            )
        }
    }
    
    func saveTabs(
        regularTabs: [Tab],
        privateTabs: [Tab],
        selectedRegularTabID: UUID?,
        selectedPrivateTabID: UUID?,
        selectedTabMode: TabMode
    ) {
        let persistedRegularTabs = regularTabs.map {
            PersistedTab(id: $0.id, title: $0.title, url: $0.url)
        }
        let persistedPrivateTabs = privateTabs.map {
            PersistedTab(id: $0.id, title: $0.title, url: $0.url)
        }
        
        stateQueue.async {
            self.persistedState = PersistedState(
                regularTabs: persistedRegularTabs,
                privateTabs: persistedPrivateTabs,
                selectedRegularTabID: selectedRegularTabID,
                selectedPrivateTabID: selectedPrivateTabID,
                selectedTabMode: selectedTabMode,
                lastTabOverview: self.persistedState.lastTabOverview
            )
            self.savePersistedStateLocked()
            self.pruneThumbCacheLocked(validTabIDs: Set((persistedRegularTabs + persistedPrivateTabs).map(\.id)))
        }
    }
    
    func saveLastTabOverview(_ lastTabOverview: LastTabOverview) {
        stateQueue.async {
            self.persistedState = PersistedState(
                regularTabs: self.persistedState.regularTabs,
                privateTabs: self.persistedState.privateTabs,
                selectedRegularTabID: self.persistedState.selectedRegularTabID,
                selectedPrivateTabID: self.persistedState.selectedPrivateTabID,
                selectedTabMode: self.persistedState.selectedTabMode,
                lastTabOverview: lastTabOverview
            )
            self.savePersistedStateLocked()
        }
    }
    
    func saveThumbnail(_ image: UIImage?, for tabID: UUID) {
        stateQueue.async {
            let fileURL = self.thumbnailFileURL(for: tabID)
            
            guard let image else {
                if self.fileManager.fileExists(atPath: fileURL.path) {
                    try? self.fileManager.removeItem(at: fileURL)
                }
                return
            }
            
            guard let data = image.pngData() else {
                return
            }
            
            try? data.write(to: fileURL, options: .atomic)
        }
    }
    
    private func prepareStorageLocked() {
        try? fileManager.createDirectory(at: storage.directoryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: storage.thumbCacheDirectoryURL, withIntermediateDirectories: true)
        
        guard !fileManager.fileExists(atPath: storage.manifestFileURL.path) else {
            return
        }
        
        let emptyState = PersistedState(
            regularTabs: [],
            privateTabs: [],
            selectedRegularTabID: nil,
            selectedPrivateTabID: nil,
            selectedTabMode: .regular,
            lastTabOverview: .regular
        )
        guard let data = try? JSONEncoder().encode(emptyState) else {
            return
        }
        
        try? data.write(to: storage.manifestFileURL, options: .atomic)
    }
    
    private func loadPersistedStateLocked() {
        guard let data = try? Data(contentsOf: storage.manifestFileURL) else {
            persistedState = PersistedState(
                regularTabs: [],
                privateTabs: [],
                selectedRegularTabID: nil,
                selectedPrivateTabID: nil,
                selectedTabMode: .regular,
                lastTabOverview: .regular
            )
            return
        }
        
        if let decoded = try? JSONDecoder().decode(PersistedState.self, from: data) {
            persistedState = decoded
            return
        }
        
        persistedState = PersistedState(
            regularTabs: [],
            privateTabs: [],
            selectedRegularTabID: nil,
            selectedPrivateTabID: nil,
            selectedTabMode: .regular,
            lastTabOverview: .regular
        )
        savePersistedStateLocked()
    }
    
    private func savePersistedStateLocked() {
        guard let data = try? JSONEncoder().encode(persistedState) else {
            return
        }
        
        try? data.write(to: storage.manifestFileURL, options: .atomic)
    }
    
    private func loadThumbnailLocked(for tabID: UUID) -> UIImage? {
        guard let data = try? Data(contentsOf: thumbnailFileURL(for: tabID)) else {
            return nil
        }
        
        return UIImage(data: data)
    }
    
    private func tabSnapshot(from persistedTab: PersistedTab, isPrivate: Bool) -> TabSnapshot {
        TabSnapshot(
            id: persistedTab.id,
            title: persistedTab.title,
            url: persistedTab.url,
            thumbnail: loadThumbnailLocked(for: persistedTab.id),
            isPrivate: isPrivate
        )
    }
    
    private func pruneThumbCacheLocked(validTabIDs: Set<UUID>) {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: storage.thumbCacheDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        
        for fileURL in fileURLs where !validTabIDs.contains(UUID(uuidString: fileURL.deletingPathExtension().lastPathComponent) ?? UUID()) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    private func thumbnailFileURL(for tabID: UUID) -> URL {
        storage.thumbCacheDirectoryURL
            .appendingPathComponent(tabID.uuidString, isDirectory: false)
            .appendingPathExtension("png")
    }
}
