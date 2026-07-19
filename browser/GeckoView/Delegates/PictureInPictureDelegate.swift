//
//  PictureInPictureDelegate.swift
//  Reynard
//
//  Created by Minh Ton on 17/7/26.
//

import AVFoundation

public struct PictureInPictureCandidate {
    public let displayLayer: AVSampleBufferDisplayLayer
    public let enqueueCount: UInt64
    public let isFullscreen: Bool
}

public protocol PictureInPictureDelegate: AnyObject {
    func onLayerChanged(session: GeckoSession)
}

public extension PictureInPictureDelegate {
    func onLayerChanged(session: GeckoSession) {}
}

final class PictureInPictureHandler: GeckoSessionHandlerCommon {
    let moduleName: String? = nil
    let events = ["GeckoView:PictureInPicture:LayerChanged"]
    let enabled = true
    
    private weak var session: GeckoSession?
    weak var delegate: PictureInPictureDelegate?
    
    var candidates: [PictureInPictureCandidate] {
        guard let candidates = session?.window?.pictureInPictureCandidates() else {
            return []
        }
        return (0..<candidates.count).map {
            guard let candidate = candidates.candidate(at: $0) else {
                preconditionFailure("missing picture in picture candidate")
            }
            return PictureInPictureCandidate(
                displayLayer: candidate.displayLayer,
                enqueueCount: candidate.enqueueCount,
                isFullscreen: candidate.fullscreen
            )
        }
    }
    
    init(session: GeckoSession) {
        self.session = session
    }
    
    @MainActor
    func handleMessage(type: String, message: [String: Any?]?) async throws -> Any? {
        guard events.contains(type) else {
            throw GeckoHandlerError("unknown message \(type)")
        }
        guard let session else {
            throw GeckoHandlerError("session has been destroyed")
        }
        delegate?.onLayerChanged(session: session)
        return nil
    }
}

func newPictureInPictureHandler(_ session: GeckoSession) -> PictureInPictureHandler {
    return PictureInPictureHandler(session: session)
}
