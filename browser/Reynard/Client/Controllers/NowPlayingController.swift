//
//  NowPlayingController.swift
//  Reynard
//
//  Created by Minh Ton on 9/4/26.
//

import Foundation
import GeckoView
import MediaPlayer

// Bridges Gecko media session events to the system Now Playing center and
// handles remote control commands from the Lock Screen and Control Center.
final class NowPlayingController: MediaSessionDelegate {
    private weak var session: GeckoSession?
    private let nowPlaying = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var artworkTask: URLSessionDataTask?
    private var isActive = false
    private var commandTokens: [Any] = []
    
    init(session: GeckoSession) {
        self.session = session
        registerCommands()
    }
    
    deinit {
        unregisterCommands()
    }
    
    func onActivated(session: GeckoSession) {
        isActive = true
    }
    
    func onDeactivated(session: GeckoSession) {
        guard isActive else { return }
        isActive = false
        nowPlaying.nowPlayingInfo = nil
        artworkTask?.cancel()
        artworkTask = nil
    }
    
    func onMetadata(session: GeckoSession, metadata: MediaSessionMetadata) {
        var info = nowPlaying.nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle]  = metadata.title  ?? ""
        info[MPMediaItemPropertyArtist] = metadata.artist ?? ""
        info[MPMediaItemPropertyAlbumTitle] = metadata.album ?? ""
        nowPlaying.nowPlayingInfo = info
        
        artworkTask?.cancel()
        artworkTask = nil
        
        if let rawUrl = metadata.artworkUrl, let url = URL(string: rawUrl) {
            let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self, let data, let image = UIImage(data: data) else { return }
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                DispatchQueue.main.async {
                    var updated = self.nowPlaying.nowPlayingInfo ?? [:]
                    updated[MPMediaItemPropertyArtwork] = artwork
                    self.nowPlaying.nowPlayingInfo = updated
                }
            }
            task.resume()
            artworkTask = task
        }
    }
    
    func onPlaybackPlaying(session: GeckoSession) {
        var info = nowPlaying.nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        nowPlaying.nowPlayingInfo = info
    }
    
    func onPlaybackPaused(session: GeckoSession) {
        var info = nowPlaying.nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        nowPlaying.nowPlayingInfo = info
    }
    
    func onPlaybackNone(session: GeckoSession) {
        nowPlaying.nowPlayingInfo = nil
    }
    
    func onPositionState(session: GeckoSession, state: MediaSessionPositionState) {
        var info = nowPlaying.nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyPlaybackDuration] = state.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = state.position
        info[MPNowPlayingInfoPropertyPlaybackRate] = state.playbackRate
        nowPlaying.nowPlayingInfo = info
    }
    
    func onFeatures(session: GeckoSession, features: MediaSessionFeatures) {
        commandCenter.nextTrackCommand.isEnabled     = features.contains(.nextTrack)
        commandCenter.previousTrackCommand.isEnabled = features.contains(.prevTrack)
        commandCenter.skipForwardCommand.isEnabled   = features.contains(.seekForward)
        commandCenter.skipBackwardCommand.isEnabled  = features.contains(.seekBackward)
        commandCenter.changePlaybackPositionCommand.isEnabled = features.contains(.seekTo)
    }
    
    private func registerCommands() {
        var tokens: [Any] = []
        tokens.append(commandCenter.playCommand.addTarget { [weak self] _ in
            self?.session?.mediaSession.play()
            return .success
        })
        tokens.append(commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.session?.mediaSession.pause()
            return .success
        })
        tokens.append(commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.session?.mediaSession.stop()
            return .success
        })
        tokens.append(commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.session?.mediaSession.nextTrack()
            return .success
        })
        tokens.append(commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.session?.mediaSession.previousTrack()
            return .success
        })
        tokens.append(commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.session?.mediaSession.seekForward()
            return .success
        })
        tokens.append(commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.session?.mediaSession.seekBackward()
            return .success
        })
        tokens.append(commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.session?.mediaSession.seekTo(time: posEvent.positionTime)
            return .success
        })
        commandTokens = tokens
    }
    
    private func unregisterCommands() {
        let commands: [MPRemoteCommand] = [
            commandCenter.playCommand,
            commandCenter.pauseCommand,
            commandCenter.stopCommand,
            commandCenter.nextTrackCommand,
            commandCenter.previousTrackCommand,
            commandCenter.skipForwardCommand,
            commandCenter.skipBackwardCommand,
            commandCenter.changePlaybackPositionCommand,
        ]
        zip(commands, commandTokens).forEach { command, token in
            command.removeTarget(token)
        }
        commandTokens.removeAll()
    }
}
