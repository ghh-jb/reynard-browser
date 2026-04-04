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
    
    struct Snapshot {
        let tabs: [TabSnapshot]
        let selectedTabID: UUID?
    }
    
    struct TabSnapshot {
        let id: UUID
        let title: String
        let url: String?
        let thumbnail: UIImage?
    }
    
    private struct StorageURLs {
        let directoryURL: URL
        let manifestFileURL: URL
        let thumbCacheDirectoryURL: URL
    }
    
    private struct PersistedState: Codable {
        let selectedTabID: UUID?
        let tabs: [PersistedTab]
    }
    
    private struct PersistedTab: Codable {
        let id: UUID
        let title: String
        let url: String?
    }
    
    private let fileManager: FileManager
    private let storage: StorageURLs
    private let stateQueue = DispatchQueue(label: "me.minh-ton.reynard.tab-management-store", qos: .userInitiated)
    private var persistedState = PersistedState(selectedTabID: nil, tabs: [])
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        guard let documentsDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Documents directory is unavailable")
        }
        
        let directoryURL = documentsDirectoryURL
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
                tabs: persistedState.tabs.map {
                    TabSnapshot(
                        id: $0.id,
                        title: $0.title,
                        url: $0.url,
                        thumbnail: loadThumbnailLocked(for: $0.id)
                    )
                },
                selectedTabID: persistedState.selectedTabID
            )
        }
    }
    
    func saveTabs(_ tabs: [Tab], selectedTabID: UUID?) {
        let persistedTabs = tabs.map {
            PersistedTab(id: $0.id, title: $0.title, url: $0.url)
        }
        
        stateQueue.async {
            self.persistedState = PersistedState(selectedTabID: selectedTabID, tabs: persistedTabs)
            self.savePersistedStateLocked()
            self.pruneThumbCacheLocked(validTabIDs: Set(persistedTabs.map(\.id)))
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
        
        let emptyState = PersistedState(selectedTabID: nil, tabs: [])
        guard let data = try? JSONEncoder().encode(emptyState) else {
            return
        }
        
        try? data.write(to: storage.manifestFileURL, options: .atomic)
    }
    
    private func loadPersistedStateLocked() {
        guard let data = try? Data(contentsOf: storage.manifestFileURL) else {
            persistedState = PersistedState(selectedTabID: nil, tabs: [])
            return
        }
        
        if let decoded = try? JSONDecoder().decode(PersistedState.self, from: data) {
            persistedState = decoded
            return
        }
        
        persistedState = PersistedState(selectedTabID: nil, tabs: [])
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
