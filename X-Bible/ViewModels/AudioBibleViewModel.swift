////
//  AudioBibleViewModel.swift
//  XBible
//
//  Created by Zoe Brooklyn on 6/12/26.
//

import SwiftUI
import Combine
import XbibleEngine


@MainActor
public class AudioBibleViewModel: ObservableObject {
    
    // ───── UI State (Published - Throttled) ─────
    @Published public var selectedModule: AudioModuleInfo? = nil
    @Published public var selectedNodeId: String? = nil
    @Published public var selectedNodeTitle: String? = nil
    @Published public var isPlaying: Bool = false
    @Published public var currentActiveTitle: String = ""
    @Published public var isLoading: Bool = false
    
    #if os(macOS)
    @Published public var decodedArtwork: NSImage? = nil
    #else
    @Published public var decodedArtwork: UIImage? = nil
    #endif
    
    @Published public var backgroundGradientColors: [Color] = [Color.black]
    
    // ───── Internal Fast State ─────
    // Marked @protected or nonisolated via plain state properties
    // to keep background execution channels perfectly unblocked
    private var internalPlaybackState: PlaybackState?
    private var lastUIUpdateTime = Date()
    
    // ───── Private Cache ─────
    private var flattenedChaptersCache: [AudioNode] = []
    private let engine: AudioEngine
    private var player: AudioBiblePlayer?
    
    public init(engine: AudioEngine) {
        self.engine = engine
    }
    
    public var availableModules: [AudioModuleInfo] {
        engine.getAudioModules()
    }
    
    public var currentActiveSubtitle: String {
        guard let idx = flattenedChaptersCache.firstIndex(where: { $0.id == selectedNodeId }) else {
            return ""
        }
        return "Chapter \(idx + 1) of \(flattenedChaptersCache.count)"
    }
    
    // MARK: - Module Selection
    public func selectModule(_ module: AudioModuleInfo) {
        flattenedChaptersCache = []
        selectedNodeId = nil
        selectedNodeTitle = nil
        isLoading = true
        self.selectedModule = module
        
        currentActiveTitle = module.metadata?.displayTitle ?? module.fileName
        
        if let data = module.artwork.imageBytes() {
            #if os(macOS)
            decodedArtwork = NSImage(data: data)
            #else
            decodedArtwork = UIImage(data: data)
            #endif
            
            let colors = module.artwork.extractColors(count: 4)
            if !colors.isEmpty {
                backgroundGradientColors = colors.map { c in
                    Color(red: c.red, green: c.green, blue: c.blue, opacity: c.alpha)
                }
            }
        }
        
        let basePath = engine.getAudioModulesPath()
        let fullPath = (basePath as NSString).appendingPathComponent(module.fileName)
        
        let newPlayer = AudioBiblePlayer(moduleFilePath: fullPath, engine: engine)
        self.player = newPlayer
        
        loadAndCacheNavigationTree()
        setupStateListener()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self, self.player != nil else { return }
            self.player?.play()
            self.isPlaying = true
            self.isLoading = false
        }
    }
    
    private func setupStateListener() {
        player?.onStateUpdate = { [weak self] state in
                guard let self = self else { return }
                
                // 🚀 THE FIX: Safely route the update to the MainActor via an async dispatch.
                // This stops the background worker thread from mutating properties owned by the MainActor.
                DispatchQueue.main.async {
                    self.internalPlaybackState = state
                    
                    let now = Date()
                    if now.timeIntervalSince(self.lastUIUpdateTime) > 0.08 { // ~12 updates per second max
                        self.lastUIUpdateTime = now
                        self.applyStateToUI(state)
                    }
                }
            }
    }
    
    private func applyStateToUI(_ state: PlaybackState) {
        if self.isPlaying != state.isPlaying {
            self.isPlaying = state.isPlaying
        }
        
        self.syncActiveChapter(at: state.currentTimeMs)
    }
    
    // MARK: - User Controls (Immediate Response)
    public func togglePlayback() {
        guard let player = self.player else { return }
        if self.isPlaying {
            player.pause()
            self.isPlaying = false
        } else {
            player.play()
            self.isPlaying = true
        }
        forceSynchronousStateUpdate()
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
        forceSynchronousStateUpdate()
    }
    
    public func setRepeatMode(mode: RepeatMode) {
        engine.setRepeatMode(mode: mode)
        forceSynchronousStateUpdate()
    }
    
    public var currentTimeMs: Int64 {
        return internalPlaybackState?.currentTimeMs ?? 0
    }
    
    public var currentRepeatMode: RepeatMode {
        return internalPlaybackState?.repeatMode ?? .off
    }
    
    public func seekToChapter(id: String) {
        engine.seekToChapter(chapterId: id)
        if let targetMs = engine.getPlaybackState()?.currentTimeMs {
            player?.seekTo(ms: targetMs)
        }
        forceSynchronousStateUpdate()
    }
    
    public var activeText: String {
        return internalPlaybackState?.activeText ?? ""
    }
    
    // MARK: - Internal Helpers
    private func forceSynchronousStateUpdate() {
        guard let state = engine.getPlaybackState() else { return }
        internalPlaybackState = state
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
        }
    }
    
    public var cachedChaptersList: [AudioNode] {
        flattenedChaptersCache
    }
    
    public var liveAudioVolume: CGFloat {
        return player?.getLiveAudioLevel() ?? 0.1
    }
    
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
// MARK: - Extensions
extension AudioNode {
    public var stableId: String {
        let start = self.startMs ?? 0
        let end = self.endMs ?? 0
        return "\(self.title)-\(start)-\(end)"
    }
}
