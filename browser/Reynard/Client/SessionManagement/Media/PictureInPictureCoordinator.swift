//
//  PictureInPictureCoordinator.swift
//  Reynard
//
//  Created by Minh Ton on 16/7/26.
//

import AVFoundation
import AVKit
import Foundation
import GeckoView

protocol PictureInPictureCoordinating: AnyObject {
    func selectedSessionDidChange()
    func navigationStarted(in session: GeckoSession)
}

@available(iOS 15.0, *)
protocol PictureInPictureCoordinatorDelegate: AnyObject {
    func pictureInPictureCoordinator(
        _ coordinator: PictureInPictureCoordinator,
        restore session: GeckoSession
    ) -> Bool
}

@available(iOS 15.0, *)
final class PictureInPictureCoordinator: NSObject, PictureInPictureCoordinating {
    private struct Eligibility {
        let session: GeckoSession
        let candidates: [PictureInPictureCandidate]
        let position: MediaSessionPositionState
        let supportsSeeking: Bool
    }
    
    private struct FrameObservation {
        var enqueueCounts: [ObjectIdentifier: UInt64]
        var advancingLayer: AVSampleBufferDisplayLayer? = nil
        var advancementCount = 0
    }
    
    private final class Presentation {
        let session: GeckoSession
        let displayLayer: AVSampleBufferDisplayLayer
        let contentSource: AVPictureInPictureController.ContentSource
        let controller: AVPictureInPictureController
        var invalidatedDuration: Double
        var invalidatedPlaybackState: SystemMediaSession.PlaybackState
        var pauseRequestID = 0
        var isSeeking = false
        var candidateCounters: [ObjectIdentifier: UInt64]
        var nonAdvancingSampleCount = 0
        
        init(
            session: GeckoSession,
            displayLayer: AVSampleBufferDisplayLayer,
            contentSource: AVPictureInPictureController.ContentSource,
            controller: AVPictureInPictureController,
            duration: Double,
            playbackState: SystemMediaSession.PlaybackState,
            candidateCounters: [ObjectIdentifier: UInt64]
        ) {
            self.session = session
            self.displayLayer = displayLayer
            self.contentSource = contentSource
            self.controller = controller
            invalidatedDuration = duration
            invalidatedPlaybackState = playbackState
            self.candidateCounters = candidateCounters
        }
    }
    
    private enum State {
        case idle
        case prepared(Presentation)
        case starting(Presentation)
        case active(Presentation)
        case stopping(Presentation, requestedByCoordinator: Bool)
        
        var presentation: Presentation? {
            switch self {
            case .idle:
                return nil
            case let .prepared(presentation),
                let .starting(presentation),
                let .active(presentation),
                let .stopping(presentation, _):
                return presentation
            }
        }
        
        var isIdle: Bool {
            if case .idle = self {
                return true
            }
            return false
        }
        
        var isPrepared: Bool {
            if case .prepared = self {
                return true
            }
            return false
        }
        
        var stopRequested: Bool {
            if case let .stopping(_, requestedByCoordinator) = self {
                return requestedByCoordinator
            }
            return false
        }
    }
    
    private weak var delegate: PictureInPictureCoordinatorDelegate?
    private let mediaSession: SystemMediaSession
    private let sessionManager: SessionManager
    private var state = State.idle
    private weak var observedSession: GeckoSession?
    private var awaitsLayerAfterForeground = false
    private var frameObservation: FrameObservation?
    private var pollingTimer: Timer?
    
    init?(
        delegate: PictureInPictureCoordinatorDelegate,
        mediaSession: SystemMediaSession,
        sessionManager: SessionManager
    ) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            return nil
        }
        self.delegate = delegate
        self.mediaSession = mediaSession
        self.sessionManager = sessionManager
        super.init()
        mediaSession.observer = self
        sessionManager.applicationStateObserver = self
        sessionManager.pictureInPictureHandler = self
    }
    
    func selectedSessionDidChange() {
        awaitsLayerAfterForeground = false
        if let presentation = state.presentation,
           mediaSession.selectedSnapshot?.session !== presentation.session {
            requestTeardown()
        }
        attachLayerObserverToSelectedSession()
        reevaluate()
    }
    
    func navigationStarted(in session: GeckoSession) {
        guard mediaSession.selectedSnapshot?.session === session ||
                state.presentation?.session === session else {
            return
        }
        awaitsLayerAfterForeground = false
        resetPolling()
        if state.presentation?.session === session {
            requestTeardown()
        }
    }
    
    private func attachLayerObserverToSelectedSession() {
        observedSession?.pictureInPictureDelegate = nil
        guard let session = mediaSession.selectedSnapshot?.session else {
            observedSession = nil
            return
        }
        observedSession = session
        session.pictureInPictureDelegate = self
    }
    
    private func mediaStateChanged() {
        let snapshot = mediaSession.selectedSnapshot
        if snapshot?.playbackState != .playing {
            awaitsLayerAfterForeground = false
        }
        if let presentation = state.presentation,
           snapshot?.session === presentation.session,
           snapshot?.playbackState == SystemMediaSession.PlaybackState.none {
            requestTeardown()
            return
        }
        synchronizePreparedPlaybackState()
        if case .prepared = state,
           snapshot?.playbackState != .playing {
            requestTeardown()
            return
        }
        reevaluate()
    }
    
    private func foregroundStateChanged() {
        guard sessionManager.isForeground else {
            switch state {
            case .idle:
                let snapshot = mediaSession.selectedSnapshot
                awaitsLayerAfterForeground =
                snapshot?.playbackState == .playing &&
                snapshot?.session.pictureInPictureCandidates.isEmpty == false
            case .prepared, .starting:
                awaitsLayerAfterForeground = true
            case .active, .stopping:
                awaitsLayerAfterForeground = false
            }
            resetPolling()
            return
        }
        reevaluate()
    }
    
    private func layerChanged() {
        let selectedSnapshot = mediaSession.selectedSnapshot
        if state.isIdle,
           sessionManager.isForeground,
           awaitsLayerAfterForeground,
           selectedSnapshot?.session.pictureInPictureCandidates.isEmpty != false {
            awaitsLayerAfterForeground = false
        }
        if let presentation = state.presentation,
           !state.isPrepared,
           !presentation.session.pictureInPictureCandidates.contains(where: {
               $0.displayLayer === presentation.displayLayer
           }) {
            requestTeardown()
            return
        }
        reevaluate()
    }
    
    private func reevaluate(sampleFrames: Bool = false) {
        guard sessionManager.isForeground else {
            return
        }
        switch state {
        case .idle:
            reevaluateIdle(sampleFrames: sampleFrames)
        case let .prepared(presentation):
            monitorPrepared(presentation, sampleFrames: sampleFrames)
        case .starting, .active, .stopping:
            break
        }
    }
    
    private func reevaluateIdle(sampleFrames: Bool) {
        guard let eligibility = eligibility() else {
            frameObservation = nil
            if awaitsLayerAfterForeground,
               mediaSession.selectedSnapshot?.playbackState == .playing {
                startPollingIfNeeded()
            } else {
                resetPolling()
            }
            return
        }
        awaitsLayerAfterForeground = false
        let enqueueCounts = candidateCounters(eligibility.candidates)
        guard var observation = frameObservation,
              candidateSetsMatch(observation.enqueueCounts, enqueueCounts) else {
            frameObservation = FrameObservation(
                enqueueCounts: enqueueCounts
            )
            startPollingIfNeeded()
            return
        }
        
        if sampleFrames {
            let advancing = eligibility.candidates.filter {
                $0.enqueueCount >
                (observation.enqueueCounts[
                    ObjectIdentifier($0.displayLayer)
                ] ?? 0)
            }
            observation.enqueueCounts = enqueueCounts
            if advancing.count == 1 {
                let candidate = advancing[0]
                if observation.advancingLayer === candidate.displayLayer {
                    observation.advancementCount += 1
                } else {
                    observation.advancingLayer = candidate.displayLayer
                    observation.advancementCount = 1
                }
                frameObservation = observation
                if observation.advancementCount >= 2 {
                    prepare(candidate, eligibility: eligibility)
                    return
                }
            } else {
                observation.advancingLayer = nil
                observation.advancementCount = 0
            }
            frameObservation = observation
        }
        startPollingIfNeeded()
    }
    
    private func eligibility() -> Eligibility? {
        guard let media = mediaSession.selectedSnapshot,
              media.playbackState == .playing,
              let position = media.positionState,
              position.duration.isFinite,
              position.duration > 0,
              position.position.isFinite,
              position.position >= 0,
              position.position <= position.duration,
              position.playbackRate.isFinite,
              position.playbackRate > 0 else {
            return nil
        }
        let candidates = media.session.pictureInPictureCandidates
        guard candidates.first?.isFullscreen == true else {
            return nil
        }
        return Eligibility(
            session: media.session,
            candidates: candidates,
            position: position,
            supportsSeeking: media.supportsSeeking
        )
    }
    
    private func startPollingIfNeeded() {
        guard pollingTimer == nil else {
            return
        }
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.reevaluate(sampleFrames: true)
        }
    }
    
    private func prepare(
        _ candidate: PictureInPictureCandidate,
        eligibility: Eligibility
    ) {
        frameObservation = nil
        let verifiedCandidates = eligibility.session.pictureInPictureCandidates
        guard synchronizeTimebase(
            of: candidate.displayLayer,
            with: eligibility.position
        ),
              let verified = verifiedCandidates.first(where: {
                  $0.displayLayer === candidate.displayLayer
              }),
              verified.enqueueCount >= candidate.enqueueCount else {
            reevaluate()
            return
        }
        
        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: candidate.displayLayer,
            playbackDelegate: self
        )
        let controller = AVPictureInPictureController(contentSource: source)
        controller.delegate = self
        controller.requiresLinearPlayback = !eligibility.supportsSeeking
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        
        state = .prepared(Presentation(
            session: eligibility.session,
            displayLayer: candidate.displayLayer,
            contentSource: source,
            controller: controller,
            duration: eligibility.position.duration,
            playbackState: .playing,
            candidateCounters: candidateCounters(verifiedCandidates)
        ))
        startPollingIfNeeded()
    }
    
    private func monitorPrepared(
        _ presentation: Presentation,
        sampleFrames: Bool
    ) {
        guard let eligibility = eligibility(),
              eligibility.session === presentation.session else {
            requestTeardown()
            return
        }
        let enqueueCounts = candidateCounters(eligibility.candidates)
        guard candidateSetsMatch(
            presentation.candidateCounters,
            enqueueCounts
        ) else {
            requestTeardown()
            return
        }
        guard sampleFrames else {
            startPollingIfNeeded()
            return
        }
        
        let advancing = eligibility.candidates.filter {
            $0.enqueueCount >
            (presentation.candidateCounters[ObjectIdentifier($0.displayLayer)] ?? 0)
        }
        presentation.candidateCounters = enqueueCounts
        if advancing.count == 1,
           advancing[0].displayLayer === presentation.displayLayer {
            presentation.nonAdvancingSampleCount = 0
        } else if advancing.isEmpty {
            presentation.nonAdvancingSampleCount += 1
            if presentation.nonAdvancingSampleCount >= 4 {
                requestTeardown()
                return
            }
        } else {
            requestTeardown()
            return
        }
        startPollingIfNeeded()
    }
    
    private func candidateCounters(
        _ candidates: [PictureInPictureCandidate]
    ) -> [ObjectIdentifier: UInt64] {
        return Dictionary(uniqueKeysWithValues: candidates.map {
            (ObjectIdentifier($0.displayLayer), $0.enqueueCount)
        })
    }
    
    private func candidateSetsMatch(
        _ first: [ObjectIdentifier: UInt64],
        _ second: [ObjectIdentifier: UInt64]
    ) -> Bool {
        return first.count == second.count &&
        second.keys.allSatisfy { first[$0] != nil }
    }
    
    private func willResignActive() {
        guard case let .prepared(presentation) = state,
              let eligibility = eligibility(),
              eligibility.session === presentation.session else {
            if case .prepared = state {
                requestTeardown()
            }
            return
        }
        let enqueueCounts = candidateCounters(eligibility.candidates)
        guard candidateSetsMatch(
            presentation.candidateCounters,
            enqueueCounts
        ) else {
            requestTeardown()
            return
        }
        
        let advancing = eligibility.candidates.filter {
            $0.enqueueCount >
            (presentation.candidateCounters[ObjectIdentifier($0.displayLayer)] ?? 0)
        }
        guard !advancing.contains(where: {
            $0.displayLayer !== presentation.displayLayer
        }) else {
            requestTeardown()
            return
        }
        let selectedAdvanced = advancing.contains {
            $0.displayLayer === presentation.displayLayer
        }
        guard presentation.nonAdvancingSampleCount < 4 else {
            requestTeardown()
            return
        }
        if selectedAdvanced {
            presentation.nonAdvancingSampleCount = 0
        }
        presentation.candidateCounters = enqueueCounts
    }
    
    private func synchronizePreparedPlaybackState() {
        guard let presentation = state.presentation,
              let snapshot = mediaSession.selectedSnapshot,
              snapshot.session === presentation.session,
              let position = snapshot.positionState else {
            return
        }
        _ = synchronizeTimebase(
            of: presentation.displayLayer,
            with: position,
            paused: snapshot.playbackState == .paused
        )
        let requiresLinearPlayback = !snapshot.supportsSeeking
        let seekingAvailabilityChanged =
        presentation.controller.requiresLinearPlayback != requiresLinearPlayback
        if seekingAvailabilityChanged {
            presentation.controller.requiresLinearPlayback = requiresLinearPlayback
        }
        if seekingAvailabilityChanged ||
            presentation.invalidatedDuration != position.duration ||
            presentation.invalidatedPlaybackState != snapshot.playbackState {
            presentation.invalidatedDuration = position.duration
            presentation.invalidatedPlaybackState = snapshot.playbackState
            presentation.controller.invalidatePlaybackState()
        }
    }
    
    private func synchronizeTimebase(
        of displayLayer: AVSampleBufferDisplayLayer,
        with position: MediaSessionPositionState,
        paused: Bool = false
    ) -> Bool {
        let rate = paused ? 0 : position.playbackRate
        return synchronizeTimebase(
            of: displayLayer,
            position: position.position,
            rate: rate
        )
    }
    
    private func synchronizeTimebase(
        of displayLayer: AVSampleBufferDisplayLayer,
        position: Double,
        rate: Double
    ) -> Bool {
        guard let timebase = displayLayer.controlTimebase else {
            return false
        }
        guard CMTimebaseSetTime(
            timebase,
            time: CMTime(seconds: position, preferredTimescale: 600)
        ) == noErr else {
            return false
        }
        return CMTimebaseSetRate(timebase, rate: rate) == noErr
    }
    
    private func resetPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        frameObservation = nil
    }
    
    private func requestTeardown() {
        switch state {
        case .idle:
            break
        case let .prepared(presentation):
            state = .idle
            release(presentation)
            sessionManager.pictureInPicturePresentationDidEnd(presentation.session)
            reevaluate()
        case let .starting(presentation), let .active(presentation):
            state = .stopping(presentation, requestedByCoordinator: true)
            resetPolling()
            presentation.controller.stopPictureInPicture()
        case .stopping:
            break
        }
    }
    
    private func terminalTeardown(for controller: AVPictureInPictureController) {
        guard let presentation = state.presentation,
              presentation.controller === controller else {
            return
        }
        if !sessionManager.isForeground {
            presentation.session.mediaSession.pause()
        }
        state = .idle
        release(presentation)
        sessionManager.pictureInPicturePresentationDidEnd(presentation.session)
        reevaluate()
    }
    
    private func release(_ presentation: Presentation) {
        resetPolling()
        presentation.controller.delegate = nil
    }
}

@available(iOS 15.0, *)
extension PictureInPictureCoordinator: SystemMediaSessionObserver {
    func systemMediaSessionStateDidChange(_ mediaSession: SystemMediaSession) {
        mediaStateChanged()
    }
}

@available(iOS 15.0, *)
extension PictureInPictureCoordinator: SessionManagerApplicationStateObserver {
    func sessionManagerDidChangeApplicationState(_ sessionManager: SessionManager) {
        foregroundStateChanged()
    }
    
    func sessionManagerWillResignActive(_ sessionManager: SessionManager) {
        willResignActive()
    }
}

@available(iOS 15.0, *)
extension PictureInPictureCoordinator: SessionManagerPictureInPictureHandler {
    func stopPresenting(_ session: GeckoSession) -> Bool {
        guard state.presentation?.session === session else {
            return false
        }
        requestTeardown()
        return true
    }
}

@available(iOS 15.0, *)
extension PictureInPictureCoordinator: PictureInPictureDelegate {
    func onLayerChanged(session: GeckoSession) {
        guard mediaSession.selectedSnapshot?.session === session else {
            return
        }
        layerChanged()
    }
}

@available(iOS 15.0, *)
extension PictureInPictureCoordinator: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        setPlaying playing: Bool
    ) {
        guard let presentation = state.presentation,
              presentation.controller === pictureInPictureController else {
            return
        }
        if playing {
            presentation.pauseRequestID += 1
            presentation.session.mediaSession.play()
        } else {
            presentation.pauseRequestID += 1
            let pauseRequestID = presentation.pauseRequestID
            DispatchQueue.main.async { [weak self, weak presentation] in
                guard let self,
                      let presentation,
                      state.presentation === presentation,
                      presentation.pauseRequestID == pauseRequestID,
                      !presentation.isSeeking else {
                    return
                }
                presentation.session.mediaSession.pause()
            }
        }
    }
    
    func pictureInPictureControllerTimeRangeForPlayback(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> CMTimeRange {
        guard let position = mediaSession.selectedSnapshot?.positionState,
              position.duration.isFinite,
              position.duration > 0 else {
            return .invalid
        }
        return CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: position.duration, preferredTimescale: 600)
        )
    }
    
    func pictureInPictureControllerIsPlaybackPaused(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> Bool {
        return mediaSession.selectedSnapshot?.playbackState != .playing
    }
    
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {}
    
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime,
        completion completionHandler: @escaping () -> Void
    ) {
        guard let presentation = state.presentation,
              presentation.controller === pictureInPictureController,
              let snapshot = mediaSession.selectedSnapshot,
              snapshot.session === presentation.session,
              snapshot.supportsSeeking,
              let position = snapshot.positionState,
              position.duration.isFinite,
              position.duration > 0,
              let timebase = presentation.displayLayer.controlTimebase else {
            completionHandler()
            return
        }
        let interval = CMTimeGetSeconds(skipInterval)
        let currentTime = CMTimeGetSeconds(CMTimebaseGetTime(timebase))
        let currentRate = CMTimebaseGetRate(timebase)
        guard interval.isFinite, currentTime.isFinite, currentRate.isFinite else {
            completionHandler()
            return
        }
        presentation.isSeeking = true
        presentation.pauseRequestID += 1
        let target = min(max(currentTime + interval, 0), position.duration)
        if snapshot.features.contains(.seekTo) {
            presentation.session.mediaSession.seekTo(time: target)
        } else if interval > 0 {
            presentation.session.mediaSession.seekForward(offset: interval)
        } else if interval < 0 {
            presentation.session.mediaSession.seekBackward(offset: -interval)
        }
        _ = synchronizeTimebase(
            of: presentation.displayLayer,
            position: target,
            rate: currentRate
        )
        completionHandler()
        DispatchQueue.main.async { [weak self, weak presentation] in
            guard let self,
                  let presentation,
                  state.presentation === presentation else {
                return
            }
            presentation.isSeeking = false
        }
    }
}

@available(iOS 15.0, *)
extension PictureInPictureCoordinator: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        guard case let .prepared(presentation) = state,
              presentation.controller === pictureInPictureController else {
            return
        }
        resetPolling()
        state = .starting(presentation)
        sessionManager.setPictureInPictureSession(presentation.session)
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        guard case let .starting(presentation) = state,
              presentation.controller === pictureInPictureController else {
            return
        }
        awaitsLayerAfterForeground = false
        state = .active(presentation)
    }
    
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        terminalTeardown(for: pictureInPictureController)
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        let presentation: Presentation
        switch state {
        case let .starting(current), let .active(current):
            presentation = current
        case .idle, .prepared, .stopping:
            return
        }
        guard presentation.controller === pictureInPictureController else {
            return
        }
        state = .stopping(presentation, requestedByCoordinator: false)
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        terminalTeardown(for: pictureInPictureController)
    }
    
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        guard !state.stopRequested,
              let presentation = state.presentation,
              presentation.controller === pictureInPictureController else {
            completionHandler(false)
            return
        }
        completionHandler(
            delegate?.pictureInPictureCoordinator(
                self,
                restore: presentation.session
            ) == true
        )
    }
}
