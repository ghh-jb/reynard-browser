//
//  FaviconStore.swift
//  Reynard
//
//  Created by Minh Ton on 23/4/26.
//

import CryptoKit
import Foundation
import UIKit

final class FaviconStore {
    static let shared = FaviconStore()
    
    private enum Constants {
        static let expirationDays = 30
        static let manifestFileName = "FaviconStore"
        static let imageFilePrefix = "img-"
        static let persistDelay: TimeInterval = 10
        static let maxHTMLBytes = 768 * 1024
        static let maxImageBytes = 2 * 1024 * 1024
        static let maxRedirectDepth = 3
    }
    
    private struct StorageURLs {
        let directoryURL: URL
        let manifestFileURL: URL
    }
    
    private struct PersistedState: Codable {
        let associations: [SiteAssociation]
        let images: [CachedImage]
    }
    
    private struct SiteAssociation: Codable {
        let scopeKey: String
        let imageKey: String
        let iconURL: String
        var updatedAt: Date
    }
    
    private struct CachedImage: Codable {
        let imageKey: String
        let sourceURLs: [String]
        var updatedAt: Date
    }
    
    private struct HTMLDocument {
        let html: String
        let url: URL
    }
    
    private struct IconCandidate {
        let url: URL
        let score: Int
    }
    
    private struct RemoteImage {
        let image: UIImage
        let data: Data
        let url: URL
    }
    
    private let fileManager: FileManager
    private let storage: StorageURLs
    private let stateQueue = DispatchQueue(label: "me.minh-ton.reynard.favicon-store", qos: .utility)
    
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        return URLSession(configuration: configuration)
    }()
    
    private lazy var linkTagExpression = try! NSRegularExpression(
        pattern: "(?is)<link\\b[^>]*>",
        options: []
    )
    private lazy var metaTagExpression = try! NSRegularExpression(
        pattern: "(?is)<meta\\b[^>]*>",
        options: []
    )
    private lazy var attributeExpression = try! NSRegularExpression(
        pattern: "(?is)([A-Za-z_:][-A-Za-z0-9_:.]*)\\s*=\\s*(\"([^\"]*)\"|'([^']*)'|([^\\s>]+))",
        options: []
    )
    
    private var associationsByScopeKey: [String: SiteAssociation] = [:]
    private var imagesByKey: [String: CachedImage] = [:]
    private var imageKeysBySourceURL: [String: String] = [:]
    private var activeRequests: [String: Task<UIImage?, Never>] = [:]
    private var pendingPersistWorkItem: DispatchWorkItem?
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        let documentsDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directoryURL = documentsDirectoryURL
            .appendingPathComponent("AppData", isDirectory: true)
            .appendingPathComponent("Favicons", isDirectory: true)
        
        self.storage = StorageURLs(
            directoryURL: directoryURL,
            manifestFileURL: directoryURL.appendingPathComponent(Constants.manifestFileName, isDirectory: false)
        )
        
        stateQueue.sync {
            prepareStorageLocked()
            loadPersistedStateLocked()
            pruneExpiredEntriesLocked(now: Date())
        }
    }
    
    func cachedImage(for pageURL: URL) -> UIImage? {
        stateQueue.sync {
            cachedImageLocked(for: pageURL, now: Date())
        }
    }
    
    func resolveFavicon(for pageURL: URL) async -> UIImage? {
        guard supportsFaviconLookup(for: pageURL) else {
            return nil
        }
        
        if let cachedImage = cachedImage(for: pageURL) {
            return cachedImage
        }
        
        let requestKey = requestScopeKey(for: pageURL)
        if let activeRequest = stateQueue.sync(execute: { activeRequests[requestKey] }) {
            return await activeRequest.value
        }
        
        let task = Task<UIImage?, Never>(priority: .utility) { [weak self] in
            guard let self else {
                return nil
            }
            
            let image = await self.fetchAndCacheFavicon(for: pageURL)
            self.stateQueue.async {
                self.activeRequests[requestKey] = nil
            }
            return image
        }
        
        stateQueue.sync {
            activeRequests[requestKey] = task
        }
        return await task.value
    }
    
    private func prepareStorageLocked() {
        try? fileManager.createDirectory(at: storage.directoryURL, withIntermediateDirectories: true)
        
        guard !fileManager.fileExists(atPath: storage.manifestFileURL.path) else {
            return
        }
        
        let emptyState = PersistedState(associations: [], images: [])
        guard let data = try? JSONEncoder().encode(emptyState) else {
            return
        }
        
        try? data.write(to: storage.manifestFileURL, options: .atomic)
    }
    
    private func loadPersistedStateLocked() {
        guard let data = try? Data(contentsOf: storage.manifestFileURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            associationsByScopeKey = [:]
            imagesByKey = [:]
            imageKeysBySourceURL = [:]
            return
        }
        
        associationsByScopeKey = state.associations.reduce(into: [:]) { result, association in
            result[association.scopeKey] = association
        }
        imagesByKey = state.images.reduce(into: [:]) { result, image in
            result[image.imageKey] = image
        }
        imageKeysBySourceURL = state.images.reduce(into: [:]) { result, image in
            image.sourceURLs.forEach { result[$0] = image.imageKey }
        }
    }
    
    private func persistStateLocked() {
        let state = PersistedState(
            associations: Array(associationsByScopeKey.values),
            images: Array(imagesByKey.values)
        )
        
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }
        
        try? data.write(to: storage.manifestFileURL, options: .atomic)
    }
    
    private func schedulePersistLocked() {
        pendingPersistWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.persistStateLocked()
        }
        pendingPersistWorkItem = workItem
        stateQueue.asyncAfter(deadline: .now() + Constants.persistDelay, execute: workItem)
    }
    
    private func cachedImageLocked(for pageURL: URL, now: Date) -> UIImage? {
        pruneExpiredEntriesLocked(now: now)
        
        guard let association = lookupAssociationLocked(for: pageURL),
              let image = loadImageLocked(for: association.imageKey) else {
            return nil
        }
        
        associationsByScopeKey[association.scopeKey]?.updatedAt = now
        imagesByKey[association.imageKey]?.updatedAt = now
        schedulePersistLocked()
        return image
    }
    
    private func fetchAndCacheFavicon(for pageURL: URL) async -> UIImage? {
        var candidates: [URL] = []
        
        if let document = await fetchHTMLDocument(for: pageURL, redirectDepth: 0) {
            candidates.append(contentsOf: iconURLs(in: document.html, baseURL: document.url))
        }
        
        if let fallbackURL = fallbackFaviconURL(for: pageURL) {
            candidates.append(fallbackURL)
        }
        
        var seenCandidateURLs = Set<String>()
        for candidateURL in candidates {
            guard !Task.isCancelled else {
                return nil
            }
            
            let normalizedCandidateURL = candidateURL.absoluteString.lowercased()
            guard seenCandidateURLs.insert(normalizedCandidateURL).inserted else {
                continue
            }
            
            if let cachedImage = associateExistingIconIfPresent(candidateURL, with: pageURL) {
                return cachedImage
            }
            
            guard let remoteImage = await fetchRemoteImage(from: candidateURL) else {
                continue
            }
            
            stateQueue.sync {
                storeLocked(remoteImage: remoteImage, for: pageURL, now: Date())
            }
            return remoteImage.image
        }
        
        return nil
    }
    
    private func associateExistingIconIfPresent(_ iconURL: URL, with pageURL: URL) -> UIImage? {
        stateQueue.sync {
            let now = Date()
            pruneExpiredEntriesLocked(now: now)
            
            guard let imageKey = imageKeysBySourceURL[iconURL.absoluteString],
                  let image = loadImageLocked(for: imageKey) else {
                return nil
            }
            
            let scopeKey = scopeKey(for: pageURL, iconURL: iconURL)
            associationsByScopeKey[scopeKey] = SiteAssociation(
                scopeKey: scopeKey,
                imageKey: imageKey,
                iconURL: iconURL.absoluteString,
                updatedAt: now
            )
            imagesByKey[imageKey]?.updatedAt = now
            schedulePersistLocked()
            return image
        }
    }
    
    private func storeLocked(remoteImage: RemoteImage, for pageURL: URL, now: Date) {
        let imageKey = Self.sha256(remoteImage.data)
        let imageURL = imageFileURL(for: imageKey)
        
        if !fileManager.fileExists(atPath: imageURL.path) {
            try? remoteImage.data.write(to: imageURL, options: .atomic)
        }
        
        let scopeKey = scopeKey(for: pageURL, iconURL: remoteImage.url)
        imagesByKey[imageKey] = CachedImage(
            imageKey: imageKey,
            sourceURLs: mergedSourceURLs(for: imageKey, adding: remoteImage.url.absoluteString),
            updatedAt: now
        )
        imagesByKey[imageKey]?.sourceURLs.forEach {
            imageKeysBySourceURL[$0] = imageKey
        }
        associationsByScopeKey[scopeKey] = SiteAssociation(
            scopeKey: scopeKey,
            imageKey: imageKey,
            iconURL: remoteImage.url.absoluteString,
            updatedAt: now
        )
        schedulePersistLocked()
    }
    
    private func pruneExpiredEntriesLocked(now: Date) {
        let expiredScopeKeys = associationsByScopeKey.compactMap { entry in
            isExpired(entry.value.updatedAt, comparedTo: now) ? entry.key : nil
        }
        for scopeKey in expiredScopeKeys {
            associationsByScopeKey.removeValue(forKey: scopeKey)
        }
        
        let expiredImageKeys = imagesByKey.compactMap { entry in
            isExpired(entry.value.updatedAt, comparedTo: now) ? entry.key : nil
        }
        for imageKey in expiredImageKeys {
            removeImageLocked(imageKey)
        }
        
        removeUnreferencedImagesLocked()
    }
    
    private func removeUnreferencedImagesLocked() {
        let referencedImageKeys = Set(associationsByScopeKey.values.map(\.imageKey))
        let unreferencedImageKeys = imagesByKey.keys.filter { !referencedImageKeys.contains($0) }
        for imageKey in unreferencedImageKeys {
            removeImageLocked(imageKey)
        }
    }
    
    private func removeImageLocked(_ imageKey: String) {
        if let image = imagesByKey.removeValue(forKey: imageKey) {
            image.sourceURLs.forEach {
                imageKeysBySourceURL.removeValue(forKey: $0)
            }
        }
        
        let imageURL = imageFileURL(for: imageKey)
        if fileManager.fileExists(atPath: imageURL.path) {
            try? fileManager.removeItem(at: imageURL)
        }
        
        let scopeKeys = associationsByScopeKey.compactMap { entry in
            entry.value.imageKey == imageKey ? entry.key : nil
        }
        for scopeKey in scopeKeys {
            associationsByScopeKey.removeValue(forKey: scopeKey)
        }
    }
    
    private func lookupAssociationLocked(for pageURL: URL) -> SiteAssociation? {
        for lookupKey in lookupKeys(for: pageURL) {
            if let association = associationsByScopeKey[lookupKey] {
                return association
            }
        }
        return nil
    }
    
    private func loadImageLocked(for imageKey: String) -> UIImage? {
        let imageURL = imageFileURL(for: imageKey)
        guard let data = try? Data(contentsOf: imageURL),
              let image = UIImage(data: data) else {
            removeImageLocked(imageKey)
            return nil
        }
        return image
    }
    
    private func mergedSourceURLs(for imageKey: String, adding sourceURL: String) -> [String] {
        let existingSourceURLs = imagesByKey[imageKey]?.sourceURLs ?? []
        return Array(Set(existingSourceURLs + [sourceURL])).sorted()
    }
    
    private func imageFileURL(for imageKey: String) -> URL {
        storage.directoryURL.appendingPathComponent(Constants.imageFilePrefix + imageKey, isDirectory: false)
    }
    
    private func supportsFaviconLookup(for pageURL: URL) -> Bool {
        guard let scheme = pageURL.scheme?.lowercased(),
              let host = pageURL.host,
              !host.isEmpty else {
            return false
        }
        
        return scheme == "http" || scheme == "https"
    }
    
    private func requestScopeKey(for pageURL: URL) -> String {
        lookupKeys(for: pageURL).first ?? pageURL.absoluteString.lowercased()
    }
    
    private func lookupKeys(for pageURL: URL) -> [String] {
        guard let scheme = pageURL.scheme?.lowercased(),
              let host = pageURL.host?.lowercased() else {
            return []
        }
        
        let base = scheme + "://" + host
        let pathComponents = normalizedPathComponents(for: pageURL.path)
        guard !pathComponents.isEmpty else {
            return [base]
        }
        
        var keys: [String] = []
        for count in stride(from: pathComponents.count, through: 1, by: -1) {
            keys.append(base + "/" + pathComponents.prefix(count).joined(separator: "/"))
        }
        keys.append(base)
        return keys
    }
    
    private func scopeKey(for pageURL: URL, iconURL: URL) -> String {
        guard let scheme = pageURL.scheme?.lowercased(),
              let host = pageURL.host?.lowercased() else {
            return pageURL.absoluteString
        }
        
        let base = scheme + "://" + host
        guard iconURL.host?.lowercased() == host else {
            return base
        }
        
        let pagePathComponents = normalizedPathComponents(for: pageURL.path)
        let iconPathComponents = normalizedDirectoryComponents(for: iconURL.path)
        
        var sharedComponents: [String] = []
        for (pageComponent, iconComponent) in zip(pagePathComponents, iconPathComponents) {
            guard pageComponent == iconComponent else {
                break
            }
            sharedComponents.append(pageComponent)
        }
        
        guard !sharedComponents.isEmpty else {
            return base
        }
        return base + "/" + sharedComponents.joined(separator: "/")
    }
    
    private func normalizedPathComponents(for path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }
    
    private func normalizedDirectoryComponents(for path: String) -> [String] {
        var components = normalizedPathComponents(for: path)
        if !path.hasSuffix("/"), !components.isEmpty {
            components.removeLast()
        }
        return components
    }
    
    private func fallbackFaviconURL(for pageURL: URL) -> URL? {
        guard var components = URLComponents(url: pageURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        components.path = "/favicon.ico"
        components.query = nil
        components.fragment = nil
        return components.url
    }
    
    private func fetchHTMLDocument(for pageURL: URL, redirectDepth: Int) async -> HTMLDocument? {
        var request = URLRequest(url: pageURL)
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        if let userAgent = UAOverride.shared.userAgent(for: pageURL.absoluteString) {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        
        guard let (data, response) = await data(for: request),
              data.count <= Constants.maxHTMLBytes else {
            return nil
        }
        
        let mimeType = (response.mimeType ?? "").lowercased()
        guard mimeType.isEmpty || mimeType.contains("html") || mimeType.contains("xml") else {
            return nil
        }
        
        let html = string(from: data, response: response)
        guard !html.isEmpty else {
            return nil
        }
        
        let finalURL = response.url ?? pageURL
        if redirectDepth < Constants.maxRedirectDepth,
           let redirectURL = metaRefreshRedirectURL(in: html, baseURL: finalURL),
           redirectURL != finalURL {
            return await fetchHTMLDocument(for: redirectURL, redirectDepth: redirectDepth + 1)
        }
        
        return HTMLDocument(html: html, url: finalURL)
    }
    
    private func fetchRemoteImage(from url: URL) async -> RemoteImage? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        if let userAgent = UAOverride.shared.userAgent(for: url.absoluteString) {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        
        guard let (data, response) = await data(for: request),
              data.count <= Constants.maxImageBytes,
              let image = UIImage(data: data) else {
            return nil
        }
        
        return RemoteImage(image: image, data: data, url: response.url ?? url)
    }
    
    private func data(for request: URLRequest) async -> (Data, URLResponse)? {
        await withCheckedContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                guard error == nil,
                      let data,
                      let response else {
                    continuation.resume(returning: nil)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
    
    private func iconURLs(in html: String, baseURL: URL) -> [URL] {
        let nsHTML = html as NSString
        let matches = linkTagExpression.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        var candidates: [URL] = []
        
        for match in matches {
            let tag = nsHTML.substring(with: match.range)
            let attributes = attributes(in: tag)
            let rel = attributes["rel"]?.lowercased() ?? ""
            let href = attributes["href"] ?? ""
            
            guard !href.isEmpty,
                  rel.contains("icon"),
                  !rel.contains("mask-icon"),
                  let url = URL(string: decodeHTMLEntities(in: href), relativeTo: baseURL)?.absoluteURL else {
                continue
            }
            
            candidates.append(url)
        }
        
        return candidates
    }
    
    private func attributes(in tag: String) -> [String: String] {
        let nsTag = tag as NSString
        let matches = attributeExpression.matches(in: tag, range: NSRange(location: 0, length: nsTag.length))
        var result: [String: String] = [:]
        
        for match in matches {
            guard match.numberOfRanges >= 6 else {
                continue
            }
            
            let name = nsTag.substring(with: match.range(at: 1)).lowercased()
            let value: String
            if match.range(at: 3).location != NSNotFound {
                value = nsTag.substring(with: match.range(at: 3))
            } else if match.range(at: 4).location != NSNotFound {
                value = nsTag.substring(with: match.range(at: 4))
            } else if match.range(at: 5).location != NSNotFound {
                value = nsTag.substring(with: match.range(at: 5))
            } else {
                value = ""
            }
            
            result[name] = value
        }
        
        return result
    }
    
    private func metaRefreshRedirectURL(in html: String, baseURL: URL) -> URL? {
        let nsHTML = html as NSString
        let matches = metaTagExpression.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        
        for match in matches {
            let tag = nsHTML.substring(with: match.range)
            let attributes = attributes(in: tag)
            let httpEquiv = attributes["http-equiv"]?.lowercased() ?? ""
            guard httpEquiv == "refresh",
                  let content = attributes["content"] else {
                continue
            }
            
            let parts = content.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else {
                continue
            }
            
            let redirectPart = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard redirectPart.lowercased().hasPrefix("url=") else {
                continue
            }
            
            let value = redirectPart.dropFirst(4).trimmingCharacters(in: .whitespacesAndNewlines)
            let unquotedValue = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if let redirectURL = URL(string: decodeHTMLEntities(in: unquotedValue), relativeTo: baseURL)?.absoluteURL {
                return redirectURL
            }
        }
        
        return nil
    }
    
    private func string(from data: Data, response: URLResponse) -> String {
        if let encodingName = response.textEncodingName,
           let encoding = String.Encoding(ianaCharsetName: encodingName),
           let string = String(data: data, encoding: encoding) {
            return string
        }
        
        if let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        if let string = String(data: data, encoding: .isoLatin1) {
            return string
        }
        
        return ""
    }
    
    private func decodeHTMLEntities(in string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
    
    private func isExpired(_ date: Date, comparedTo now: Date) -> Bool {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.startOfDay(for: now)
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) >= Constants.expirationDays
    }
    
    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private extension String.Encoding {
    init?(ianaCharsetName: String) {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(ianaCharsetName as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else {
            return nil
        }
        
        self.init(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
    }
}
