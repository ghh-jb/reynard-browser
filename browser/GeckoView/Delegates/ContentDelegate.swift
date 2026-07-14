//
//  ContentDelegate.swift
//  Reynard
//
//  Created by Minh Ton on 22/2/26.
//

import Foundation

// MARK: - Content Models

public struct ContextElement {
    public enum ElementType {
        case none
        case image
        case video
        case audio
    }
    
    public let baseUri: String?
    public let linkUri: String?
    public let title: String?
    public let altText: String?
    public let type: ElementType
    public let srcUri: String?
    public let textContent: String?
}

public enum SlowScriptResponse {
    case halt
    case resume
}

public struct ExternalResponseInfo {
    public let url: String
    public let localFilePath: String
    public let filename: String?
    public let mimeType: String?
    public let contentLength: Int64?
}

public struct SavePdfInfo {
    public let url: String
    public let filename: String?
    public let originalUrl: String?
}

// MARK: - Content Delegate

public protocol ContentDelegate {
    func onTitleChange(session: GeckoSession, title: String)
    func onPreviewImage(session: GeckoSession, previewImageUrl: String)
    func onFocusRequest(session: GeckoSession)
    func onCloseRequest(session: GeckoSession)
    func onFullScreen(session: GeckoSession, fullScreen: Bool)
    func onMetaViewportFitChange(session: GeckoSession, viewportFit: String)
    func onProductUrl(session: GeckoSession)
    func onContextMenu(session: GeckoSession, screenX: Int, screenY: Int, element: ContextElement)
    func onCrash(session: GeckoSession)
    func onKill(session: GeckoSession)
    func onFirstComposite(session: GeckoSession)
    func onFirstContentfulPaint(session: GeckoSession)
    func onPaintStatusReset(session: GeckoSession)
    func onWebAppManifest(session: GeckoSession, manifest: Any)
    func onSlowScript(session: GeckoSession, scriptFileName: String) async -> SlowScriptResponse
    func onShowDynamicToolbar(session: GeckoSession)
    func onCookieBannerDetected(session: GeckoSession)
    func onCookieBannerHandled(session: GeckoSession)
    func onExternalResponse(session: GeckoSession, response: ExternalResponseInfo) async -> Bool
    func onExternalResponseProgress(session: GeckoSession, localFilePath: String, bytesReceived: Int64) -> Bool
    func onExternalResponseComplete(session: GeckoSession, localFilePath: String, succeeded: Bool)
    func onSavePdf(session: GeckoSession, request: SavePdfInfo)
}

extension ContentDelegate {
    public func onTitleChange(session: GeckoSession, title: String) {}
    public func onPreviewImage(session: GeckoSession, previewImageUrl: String) {}
    public func onFocusRequest(session: GeckoSession) {}
    public func onCloseRequest(session: GeckoSession) {}
    public func onFullScreen(session: GeckoSession, fullScreen: Bool) {}
    public func onMetaViewportFitChange(session: GeckoSession, viewportFit: String) {}
    public func onProductUrl(session: GeckoSession) {}
    public func onContextMenu(session: GeckoSession, screenX: Int, screenY: Int, element: ContextElement) {}
    public func onCrash(session: GeckoSession) {}
    public func onKill(session: GeckoSession) {}
    public func onFirstComposite(session: GeckoSession) {}
    public func onFirstContentfulPaint(session: GeckoSession) {}
    public func onPaintStatusReset(session: GeckoSession) {}
    public func onWebAppManifest(session: GeckoSession, manifest: Any) {}
    public func onSlowScript(session: GeckoSession, scriptFileName: String) async -> SlowScriptResponse { .halt }
    public func onShowDynamicToolbar(session: GeckoSession) {}
    public func onCookieBannerDetected(session: GeckoSession) {}
    public func onCookieBannerHandled(session: GeckoSession) {}
    public func onExternalResponse(session: GeckoSession, response: ExternalResponseInfo) async -> Bool { false }
    public func onExternalResponseProgress(session: GeckoSession, localFilePath: String, bytesReceived: Int64) -> Bool { false }
    public func onExternalResponseComplete(session: GeckoSession, localFilePath: String, succeeded: Bool) {}
    public func onSavePdf(session: GeckoSession, request: SavePdfInfo) {}
}

// MARK: - Content Events

enum ContentEvents: String, CaseIterable {
    case contentCrash = "GeckoView:ContentCrash"
    case contentKill = "GeckoView:ContentKill"
    case contextMenu = "GeckoView:ContextMenu"
    case domMetaViewportFit = "GeckoView:DOMMetaViewportFit"
    case pageTitleChanged = "GeckoView:PageTitleChanged"
    case domWindowClose = "GeckoView:DOMWindowClose"
    case externalResponse = "GeckoView:ExternalResponse"
    case externalResponseProgress = "GeckoView:ExternalResponseProgress"
    case externalResponseComplete = "GeckoView:ExternalResponseComplete"
    case focusRequest = "GeckoView:FocusRequest"
    case fullscreenEnter = "GeckoView:FullScreenEnter"
    case fullscreenExit = "GeckoView:FullScreenExit"
    case webAppManifest = "GeckoView:WebAppManifest"
    case firstContentfulPaint = "GeckoView:FirstContentfulPaint"
    case paintStatusReset = "GeckoView:PaintStatusReset"
    case previewImage = "GeckoView:PreviewImage"
    case cookieBannerEventDetected = "GeckoView:CookieBannerEvent:Detected"
    case cookieBannerEventHandled = "GeckoView:CookieBannerEvent:Handled"
    case savePdf = "GeckoView:SavePdf"
    case onProductUrl = "GeckoView:OnProductUrl"
}

// MARK: - Content Handler

func newContentHandler(_ session: GeckoSession) -> GeckoSessionHandler {
    GeckoSessionHandler(
        moduleName: "GeckoViewContent",
        events: ContentEvents.allCases.map(\.rawValue),
        session: session
    ) { @MainActor session, delegate, type, message in
        guard let event = ContentEvents(rawValue: type) else {
            throw GeckoHandlerError("unknown message \(type)")
        }
        
        let delegate = delegate as? ContentDelegate
        switch event {
        case .contentCrash:
            delegate?.onCrash(session: session)
            return nil
            
        case .contentKill:
            delegate?.onKill(session: session)
            return nil
            
        case .contextMenu:
            func parseElementType(_ value: String) -> ContextElement.ElementType {
                switch value {
                case "HTMLImageElement":
                    return .image
                case "HTMLVideoElement":
                    return .video
                case "HTMLAudioElement":
                    return .audio
                default:
                    return .none
                }
            }
            
            let contextElement = ContextElement(
                baseUri: message?["baseUri"] as? String,
                linkUri: (message?["linkUri"] as? String) ?? (message?["uri"] as? String),
                title: message?["title"] as? String,
                altText: message?["alt"] as? String,
                type: parseElementType(message?["elementType"] as? String ?? ""),
                srcUri: message?["elementSrc"] as? String,
                textContent: message?["textContent"] as? String
            )
            
            delegate?.onContextMenu(
                session: session,
                screenX: message?["screenX"] as? Int ?? 0,
                screenY: message?["screenY"] as? Int ?? 0,
                element: contextElement
            )
            return nil
            
        case .domMetaViewportFit:
            delegate?.onMetaViewportFitChange(
                session: session,
                viewportFit: message?["viewportfit"] as? String ?? ""
            )
            return nil
            
        case .pageTitleChanged:
            delegate?.onTitleChange(session: session, title: message?["title"] as? String ?? "")
            return nil
            
        case .domWindowClose:
            delegate?.onCloseRequest(session: session)
            return nil
            
        case .externalResponse:
            guard let url = message?["url"] as? String,
                  let localFilePath = message?["localFilePath"] as? String else {
                return false
            }
            return await delegate?.onExternalResponse(
                session: session,
                response: ExternalResponseInfo(
                    url: url,
                    localFilePath: localFilePath,
                    filename: message?["filename"] as? String,
                    mimeType: message?["mimeType"] as? String,
                    contentLength: PayloadValue.int64(message?["contentLength"])
                )
            ) ?? false
            
        case .externalResponseProgress:
            guard let localFilePath = message?["localFilePath"] as? String else {
                return false
            }
            return delegate?.onExternalResponseProgress(
                session: session,
                localFilePath: localFilePath,
                bytesReceived: PayloadValue.int64(message?["bytesReceived"]) ?? 0
            ) ?? false
            
        case .externalResponseComplete:
            guard let localFilePath = message?["localFilePath"] as? String else {
                return nil
            }
            delegate?.onExternalResponseComplete(
                session: session,
                localFilePath: localFilePath,
                succeeded: message?["succeeded"] as? Bool ?? false
            )
            return nil
            
        case .focusRequest:
            delegate?.onFocusRequest(session: session)
            return nil
            
        case .fullscreenEnter:
            delegate?.onFullScreen(session: session, fullScreen: true)
            return nil
            
        case .fullscreenExit:
            delegate?.onFullScreen(session: session, fullScreen: false)
            return nil
            
        case .webAppManifest:
            if let manifest = message?["manifest"] {
                delegate?.onWebAppManifest(session: session, manifest: manifest as Any)
            }
            return nil
            
        case .firstContentfulPaint:
            delegate?.onFirstContentfulPaint(session: session)
            return nil
            
        case .paintStatusReset:
            delegate?.onPaintStatusReset(session: session)
            return nil
            
        case .previewImage:
            delegate?.onPreviewImage(
                session: session,
                previewImageUrl: message?["previewImageUrl"] as? String ?? ""
            )
            return nil
            
        case .cookieBannerEventDetected:
            delegate?.onCookieBannerDetected(session: session)
            return nil
            
        case .cookieBannerEventHandled:
            delegate?.onCookieBannerHandled(session: session)
            return nil
            
        case .savePdf:
            delegate?.onSavePdf(
                session: session,
                request: SavePdfInfo(
                    url: message?["url"] as? String ?? "",
                    filename: message?["filename"] as? String,
                    originalUrl: message?["originalUrl"] as? String
                )
            )
            return nil
            
        case .onProductUrl:
            delegate?.onProductUrl(session: session)
            return nil
        }
    }
}

// MARK: - Process Hang Handler

enum ProcessHangEvents: String, CaseIterable {
    case hangReport = "GeckoView:HangReport"
}

func newProcessHangHandler(_ session: GeckoSession) -> GeckoSessionHandler {
    GeckoSessionHandler(
        moduleName: "GeckoViewProcessHangMonitor",
        events: ProcessHangEvents.allCases.map(\.rawValue),
        session: session
    ) { @MainActor session, delegate, type, message in
        guard let event = ProcessHangEvents(rawValue: type) else {
            throw GeckoHandlerError("unknown message \(type)")
        }
        
        let delegate = delegate as? ContentDelegate
        switch event {
        case .hangReport:
            let reportID = PayloadValue.int(message?["hangId"]) ?? 0
            
            let response = await delegate?.onSlowScript(
                session: session,
                scriptFileName: message?["scriptFileName"] as? String ?? ""
            )
            
            switch response {
            case .resume:
                session.dispatcher.dispatch(
                    type: "GeckoView:HangReportWait",
                    message: ["hangId": reportID]
                )
            default:
                session.dispatcher.dispatch(
                    type: "GeckoView:HangReportStop",
                    message: ["hangId": reportID]
                )
            }
            return nil
        }
    }
}
