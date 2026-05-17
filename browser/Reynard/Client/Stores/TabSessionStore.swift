//
//  TabSessionStore.swift
//  Reynard
//
//  Created by Minh Ton on 17/5/26.
//

import Foundation

final class TabSessionStore {
    static let shared = TabSessionStore()
    
    struct Snapshot {
        let currentURL: String?
        let backList: [String]
        let forwardList: [String]
        let ownsNav: Bool
        
        var canGoBack: Bool {
            !backList.isEmpty
        }
        
        var canGoForward: Bool {
            !forwardList.isEmpty
        }
    }
    
    private struct PersistedState: Codable {
        var currentURL: String?
        var backList: [String]
        var forwardList: [String]
        var ownsNav: Bool?
    }
    
    private let fileManager: FileManager
    private let directoryURL: URL
    private let stateQueue = DispatchQueue(label: "com.minh-ton.tab-session-store", qos: .userInitiated)
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        guard let applicationSupportDirectoryURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory is unavailable")
        }
        
        self.directoryURL = applicationSupportDirectoryURL
            .appendingPathComponent("AppData", isDirectory: true)
            .appendingPathComponent("TabSessions", isDirectory: true)
        
        stateQueue.sync {
            prepareStorageLocked()
        }
    }
    
    func loadSnapshot(for tabID: UUID) -> Snapshot {
        stateQueue.sync {
            let state = loadPersistedStateLocked(for: tabID)
            return Snapshot(
                currentURL: state.currentURL,
                backList: state.backList,
                forwardList: state.forwardList,
                ownsNav: state.ownsNav ?? false
            )
        }
    }
    
    func recordNavigation(to url: String, for tabID: UUID) -> Snapshot {
        stateQueue.sync {
            var state = loadPersistedStateLocked(for: tabID)
            guard state.currentURL != url else {
                return snapshot(from: state)
            }
            
            if let currentURL = state.currentURL,
               !currentURL.isEmpty {
                state.backList.append(currentURL)
            }
            
            state.currentURL = url
            state.forwardList.removeAll(keepingCapacity: false)
            savePersistedStateLocked(state, for: tabID)
            return snapshot(from: state)
        }
    }
    
    func setOwnsNav(_ ownsNav: Bool, for tabID: UUID) -> Snapshot {
        stateQueue.sync {
            var state = loadPersistedStateLocked(for: tabID)
            state.ownsNav = ownsNav
            savePersistedStateLocked(state, for: tabID)
            return snapshot(from: state)
        }
    }
    
    func previousURL(for tabID: UUID) -> String? {
        stateQueue.sync {
            var state = loadPersistedStateLocked(for: tabID)
            guard let targetURL = state.backList.popLast() else {
                return nil
            }
            
            if let currentURL = state.currentURL,
               !currentURL.isEmpty {
                state.forwardList.insert(currentURL, at: 0)
            }
            
            state.currentURL = targetURL
            savePersistedStateLocked(state, for: tabID)
            return targetURL
        }
    }
    
    func nextURL(for tabID: UUID) -> String? {
        stateQueue.sync {
            var state = loadPersistedStateLocked(for: tabID)
            guard !state.forwardList.isEmpty else {
                return nil
            }
            
            let targetURL = state.forwardList.removeFirst()
            if let currentURL = state.currentURL,
               !currentURL.isEmpty {
                state.backList.append(currentURL)
            }
            
            state.currentURL = targetURL
            savePersistedStateLocked(state, for: tabID)
            return targetURL
        }
    }
    
    func removeSession(for tabID: UUID) {
        stateQueue.async {
            let fileURL = self.fileURL(for: tabID)
            guard self.fileManager.fileExists(atPath: fileURL.path) else {
                return
            }
            
            try? self.fileManager.removeItem(at: fileURL)
        }
    }
    
    private func prepareStorageLocked() {
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
    
    private func loadPersistedStateLocked(for tabID: UUID) -> PersistedState {
        guard let data = try? Data(contentsOf: fileURL(for: tabID)),
              let decoded = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return PersistedState(currentURL: nil, backList: [], forwardList: [], ownsNav: nil)
        }
        
        return decoded
    }
    
    private func savePersistedStateLocked(_ state: PersistedState, for tabID: UUID) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }
        
        try? data.write(to: fileURL(for: tabID), options: .atomic)
    }
    
    private func snapshot(from state: PersistedState) -> Snapshot {
        Snapshot(
            currentURL: state.currentURL,
            backList: state.backList,
            forwardList: state.forwardList,
            ownsNav: state.ownsNav ?? false
        )
    }
    
    private func fileURL(for tabID: UUID) -> URL {
        directoryURL.appendingPathComponent(tabID.uuidString, isDirectory: false)
    }
}
