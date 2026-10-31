//
//  AudioBibleViewModel.swift
//  XBible
//
//  Created by Zoe Brooklyn on 6/12/26.
//

import SwiftUI
import Combine
import XbibleEngine
import AVFoundation
import MediaPlayer

@MainActor
public final class AudioBibleViewModel: ObservableObject {

    // MARK: - Published UI State

    @Published public var selectedModule: AudioModuleInfo? = nil
    @Published public var selectedNodeId: String? = nil
    @Published public var selectedNodeTitle: String? = nil
    @Published public var isPlaying: Bool = false
    @Published public var currentActiveTitle: String = ""
    @Published public var isLoading: Bool = false

    // 🚀 FIX: These need to be @Published so the UI updates during playback
    @Published public var currentTimeMs: Int64 = 0
    @Published public var activeText: String = ""

    #if os(macOS)
    @Published public var decodedArtwork: NSImage? = nil
    #else
    @Published public var decodedArtwork: UIImage? = nil
    #endif

    @Published public var backgroundGradientColors: [Color] = [.black]

    // MARK: - Private State

    private var internalPlaybackState: PlaybackState?
    private var lastUIUpdateTime = Date()
    private var flattenedChaptersCache: [AudioNode] = []
    private var isAudioSessionConfigured = false

    private let engine: AudioEngine
    private var player: AudioBiblePlayer?

    // MARK: - Init

    public init(engine: AudioEngine) {
        self.engine = engine
        configureAudioSession()
    }

    // MARK: - Public Computed

    public var availableModules: [AudioModuleInfo] {
        engine.getAudioModules()
    }

    public var currentActiveSubtitle: String {
        guard let idx = flattenedChaptersCache.firstIndex(where: { $0.id == selectedNodeId }) else {
            return ""
        }
        return "Chapter \(idx + 1) of \(flattenedChaptersCache.count)"
    }

    // Removed `currentTimeMs` and `activeText` computed properties here, they are now @Published above.

    public var currentRepeatMode: RepeatMode {
        internalPlaybackState?.repeatMode ?? .off
    }

    public var cachedChaptersList: [AudioNode] {
        flattenedChaptersCache
    }

    public var liveAudioVolume: CGFloat {
        player?.getLiveAudioLevel() ?? 0.1
    }

    // MARK: - Audio Session & Now Playing

    private func configureAudioSession() {
        #if os(iOS)
        guard !isAudioSessionConfigured else { return }

        Task.detached(priority: .userInitiated) {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .spokenAudio, options: [])
                try session.setActive(true)

                await MainActor.run {
                    self.isAudioSessionConfigured = true
                    UIApplication.shared.beginReceivingRemoteControlEvents()
                    self.setupRemoteTransportControls()
                }
            } catch {
                print("❌ Failed to configure audio session: \(error)")
            }
        }
        #endif
    }

    private func setupRemoteTransportControls() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            self?.isPlaying = true
            self?.updateNowPlayingInfo()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            self?.isPlaying = false
            self?.updateNowPlayingInfo()
            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayback()
            return .success
        }

        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipForward()
            return .success
        }

        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipBackward()
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentActiveTitle,
            MPMediaItemPropertyArtist: selectedModule?.metadata?.displayTitle ?? "X-Bible Audio",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        #if os(iOS)
        if let artwork = decodedArtwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        }
        #endif

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Module Selection

    public func selectModule(_ module: AudioModuleInfo) {
        configureAudioSession()

        flattenedChaptersCache = []
        selectedNodeId = nil
        selectedNodeTitle = nil
        isLoading = true
        selectedModule = module
        currentActiveTitle = module.metadata?.displayTitle ?? module.fileName
        currentTimeMs = 0
        activeText = ""

        // Artwork + gradient
        if let data = module.artwork.imageBytes() {
            #if os(macOS)
            decodedArtwork = NSImage(data: data)
            #else
            decodedArtwork = UIImage(data: data)
            #endif

            let colors = module.artwork.extractColors(count: 4)
            if !colors.isEmpty {
                backgroundGradientColors = colors.map {
                    Color(red: $0.red, green: $0.green, blue: $0.blue, opacity: $0.alpha)
                }
            }
        }

        // --- 🚀 ROBUST PATH RESOLUTION ---
        let basePath = engine.getAudioModulesPath()
        let directPath = (basePath as NSString).appendingPathComponent(module.fileName)
        
        var finalURL: URL? = nil
        
        // 1. Check if the direct path works (older flat files)
        if FileManager.default.fileExists(atPath: directPath) {
            finalURL = URL(fileURLWithPath: directPath)
        } else {
            // 2. If not, recursively search the nested folder structure
            let baseURL = URL(fileURLWithPath: basePath)
            if let enumerator = FileManager.default.enumerator(at: baseURL, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    if fileURL.lastPathComponent == module.fileName {
                        finalURL = fileURL
                        break
                    }
                }
            }
        }
        
        guard let resolvedURL = finalURL else {
            print("❌ CRITICAL ERROR: Could not find \(module.fileName) anywhere in \(basePath).")
            isLoading = false
            return
        }
        
        print("🎵 Found module at path: \(resolvedURL.path)")

        // Create player
        let newPlayer = AudioBiblePlayer(moduleFilePath: resolvedURL.path, engine: engine)
        player = newPlayer

        loadAndCacheNavigationTree()
        setupStateListener()
        updateNowPlayingInfo()

        // Play sequence
        Task {
            // Small delay to let the session settle
            try? await Task.sleep(for: .milliseconds(50))
            
            #if os(iOS)
            // Ensure session is active on MainActor right before playing
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("❌ Failed to re-activate audio session: \(error)")
            }
            #endif
            
            player?.play()
            isPlaying = true
            isLoading = false
            updateNowPlayingInfo()
        }
    }

    // MARK: - State Listener

    private func setupStateListener() {
        player?.onStateUpdate = { [weak self] state in
            guard let self else { return }

            // Wrap in Task to prevent "Publishing changes from within view updates" crashes
            Task { @MainActor in
                self.internalPlaybackState = state

                let now = Date()
                if now.timeIntervalSince(self.lastUIUpdateTime) > 0.08 {
                    self.lastUIUpdateTime = now
                    self.applyStateToUI(state)
                }
            }
        }
    }

    private func applyStateToUI(_ state: PlaybackState) {
        // 🚀 FIX: Publish the time and text so the views redraw
        self.currentTimeMs = state.currentTimeMs
        self.activeText = state.activeText

        if isPlaying != state.isPlaying {
            isPlaying = state.isPlaying
            updateNowPlayingInfo()
        }
        syncActiveChapter(at: state.currentTimeMs)
    }

    // MARK: - Playback Controls

    public func togglePlayback() {
        guard let player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        forceSynchronousStateUpdate()
        updateNowPlayingInfo()
    }

    public func skipForward() {
        player?.skipForward()
        forceSynchronousStateUpdate()
    }

    public func skipBackward() {
        player?.skipBackward()
        forceSynchronousStateUpdate()
    }

    public func seekToTime(ms: Int64) {
        player?.seekTo(ms: ms)
        forceSynchronousStateUpdate()
    }

    public func stopPlayback() {
        player?.stop()
        selectedModule = nil
        isPlaying = false
        currentTimeMs = 0
        activeText = ""
        forceSynchronousStateUpdate()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    public func setRepeatMode(mode: RepeatMode) {
        engine.setRepeatMode(mode: mode)
        forceSynchronousStateUpdate()
    }

    public func seekToChapter(id: String) {
        engine.seekToChapter(chapterId: id)
        if let targetMs = engine.getPlaybackState()?.currentTimeMs {
            player?.seekTo(ms: targetMs)
        }
        forceSynchronousStateUpdate()
    }

    // MARK: - Internal Helpers

    private func forceSynchronousStateUpdate() {
        guard let state = engine.getPlaybackState() else { return }
        internalPlaybackState = state
        
        // 🚀 FIX: Publish these immediately when seeking/skipping so the UI jumps
        self.currentTimeMs = state.currentTimeMs
        self.activeText = state.activeText
        
        applyStateToUI(state)
    }

    private func loadAndCacheNavigationTree() {
        guard let tree = engine.getNavigationTree() else { return }
        flattenedChaptersCache = tree.children.flatMap { $0.children }

        if selectedNodeId == nil, let first = flattenedChaptersCache.first {
            selectedNodeId = first.id
            selectedNodeTitle = first.title
            currentActiveTitle = first.title
        }
    }

    private func syncActiveChapter(at timeMs: Int64) {
        guard let activeId = engine.findActiveNodeId(timeMs: timeMs),
              let matching = flattenedChaptersCache.first(where: {
                  $0.id == activeId || $0.children.contains(where: { $0.id == activeId })
              }) else { return }

        if selectedNodeId != matching.id {
            selectedNodeId = matching.id
            selectedNodeTitle = matching.title
        }

        if currentActiveTitle != matching.title {
            withAnimation(.easeOut(duration: 0.18)) {
                currentActiveTitle = matching.title
            }
            updateNowPlayingInfo()
        }
    }

    // MARK: - Utilities

    public func getChapterIndex(for chapterId: String) -> Int {
        if let idx = flattenedChaptersCache.firstIndex(where: { $0.id == chapterId }) {
            return idx + 1
        }
        return 1
    }

    public func formatTime(ms: Int64) -> String {
        let totalSeconds = max(0, ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AudioNode Helper

extension AudioNode {
    public var stableId: String {
        let start = startMs ?? 0
        let end = endMs ?? 0
        return "\(title)-\(start)-\(end)"
    }
}
