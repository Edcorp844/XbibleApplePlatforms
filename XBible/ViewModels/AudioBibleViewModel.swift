//  AudioBibleViewModel.swift
//  XBible
//

import SwiftUI
import Combine
import XbibleEngine

public class AudioBibleViewModel: ObservableObject {
    // --- PUBLISHED UI STATES ---
    @Published public var navigationTreeRoot: AudioNode? = nil
    @Published public var selectedNodeId: String? = nil
    @Published public var playbackState: PlaybackState? = nil
    @Published public var isLoading: Bool = false
    @Published public var selectedModule: AudioModuleInfo? = nil
    @Published public var decodedArtwork: NSImage? = nil // Use UIImage if targeting iOS/UIKit instead of macOS
    @Published public var backgroundGradientColors: [Color] = [Color.black]
    
    // --- PRIVATE IMMUTABLE MEMORY CACHE ---
    private var flattenedChaptersCache: [AudioNode] = []
    private let engine: AudioEngine
    private var player: AudioBiblePlayer?
    
    public init(engine: AudioEngine) {
        self.engine = engine
    }
    
    /// Fetches all currently registered local audio modules from the core engine
    public var availableModules: [AudioModuleInfo] {
        return engine.getAudioModules()
    }
    
    public func selectModule(_ module: AudioModuleInfo) {
        // 1. Flush past cache matrices immediately to prevent structural cross-contamination
        self.navigationTreeRoot = nil
        self.flattenedChaptersCache = []
        self.selectedNodeId = nil
        self.isLoading = true
        self.selectedModule = module
        
        let basePath = engine.getAudioModulesPath()
        let fullPath = (basePath as NSString).appendingPathComponent(module.fileName)
        
        // 2. Setup Cross-Platform Artwork Previews
        let artwork = module.artwork
        if let data = artwork.imageBytes() {
#if os(macOS)
            self.decodedArtwork = NSImage(data: data)
#else
            self.decodedArtwork = UIImage(data: data)
#endif
            
            let extractedRustColors = artwork.extractColors(count: 4)
            if !extractedRustColors.isEmpty {
                self.backgroundGradientColors = extractedRustColors.map { rustColor in
                    Color(red: rustColor.red, green: rustColor.green, blue: rustColor.blue, opacity: rustColor.alpha)
                }
            }
        }
        
        // 3. Initialize Audio Player Target Framework Lifecycle
        self.player = AudioBiblePlayer(moduleFilePath: fullPath, engine: self.engine)
        
        // 4. Decoupled Audio Clock Pipeline Interceptor
        self.player?.onStateUpdate = { [weak self] state in
            guard let self = self else { return }
            
            // Isolate layout updates to the main execution thread safely
            DispatchQueue.main.async {
                self.playbackState = state
                self.isLoading = false
                
                // FIRST LOAD CACHE: Pull the heavy structural layout maps EXACTLY ONCE
                if self.navigationTreeRoot == nil {
                    self.loadAndCacheNavigationTree()
                }
                
                // LIGHTWEIGHT CLOCK WATCHER: Track active milestones using scalar primitives
                self.syncActiveChapter(at: state.currentTimeMs)
            }
        }
        
        // KICKOFF AUDIO: Explicitly engage audio pipelines right upon module initialization
        self.player?.play()
    }
    
    // =========================================================================
    // CORE AUDIO TRANSPORT METHOD INTERFACES (Correctly routed through Player)
    // =========================================================================
    
    /// Public bridge allowing UI views to manage transport operations without accessing internal properties
    public func togglePlayback() {
        guard let player = self.player else { return }
        
        if self.playbackState?.isPlaying == true {
            player.pause()
        } else {
            player.play()
        }
        forceSynchronousStateUpdate()
    }
    
    /// Completely stops audio playback and terminates the player session active contexts
    public func stopPlayback() {
        // Route through player wrapper to halt AVAudioPlayer hardware
        player?.stop()
        forceSynchronousStateUpdate()
    }
    
    /// Advances current playback position forward by 30 seconds
    public func skipForward() {
        // Route through player wrapper so hardware timeline jumps too
        player?.skipForward()
        forceSynchronousStateUpdate()
    }
    
    /// Regresses current playback position backward by 15 seconds
    public func skipBackward() {
        // Route through player wrapper so hardware timeline jumps too
        player?.skipBackward()
        forceSynchronousStateUpdate()
    }
    
    /// Seeks the media timeline straight to a designated millisecond timestamp
    public func seekToTime(ms: Int64) {
        //Fixed: Passing raw ms digits directly to avoid the UniFFI constructor layout crash
        guard let player = self.player else { return }
        player.seekTo(ms: ms)
        forceSynchronousStateUpdate()
    }
    
    /// Rotates or assigns the target looping mode down onto the core pipeline
    public func setRepeatMode(mode: RepeatMode) {
        engine.setRepeatMode(mode: mode)
        forceSynchronousStateUpdate()
    }
    
    /// Explicitly jump to a specified structural chapter container
    public func seekToChapter(id: String) {
        engine.seekToChapter(chapterId: id)
        
        // Fixed: Pulling exact position from engine state, routing safely via raw ms
        if let targetMs = engine.getPlaybackState()?.currentTimeMs {
            player?.seekTo(ms: targetMs)
        }
        forceSynchronousStateUpdate()
    }
    
    // =========================================================================
    // INTERNAL UTILITIES
    // =========================================================================
    
    /// Replaces the missing refresh method: Queries Rust directly to enforce
    /// immediate UI rendering without waiting for the next automated player clock poll.
    private func forceSynchronousStateUpdate() {
        if let immediateState = engine.getPlaybackState() {
            self.playbackState = immediateState
            self.syncActiveChapter(at: immediateState.currentTimeMs)
        }
    }
    
    private func loadAndCacheNavigationTree() {
        guard let liveTree = self.engine.getNavigationTree() else { return }
        self.navigationTreeRoot = liveTree
        
        // Flatten nested layout tree tiers directly into a localized Swift heap cache
        self.flattenedChaptersCache = liveTree.children.flatMap { $0.children }
        
        // Point track marker to the primary row item context if null
        if self.selectedNodeId == nil {
            self.selectedNodeId = self.flattenedChaptersCache.first?.id
        }
    }
    
    private func syncActiveChapter(at timeMs: Int64) {
        // Run light matching logic on the Rust thread to extract the active leaf string ID
        guard let activeLeafId = engine.findActiveNodeId(timeMs: timeMs) else { return }
        
        // Match the leaf string against our stable local Swift cache array
        if let matchingChapter = flattenedChaptersCache.first(where: { chapter in
            chapter.id == activeLeafId || chapter.children.contains(where: { $0.id == activeLeafId })
        }) {
            // ZERO-FLICKER RENDERING GUARD: Only publish change ticks if the ID values shift.
            if self.selectedNodeId != matchingChapter.id {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.selectedNodeId = matchingChapter.id
                }
            }
        }
    }
    
    // --- SAFE LOOKUP TOOLS EXPOSED TO THE VIEWS ---
    public var cachedChaptersList: [AudioNode] {
        return flattenedChaptersCache
    }
    
    public func getChapterIndex(for chapterId: String) -> Int {
        if let idx = flattenedChaptersCache.firstIndex(where: { $0.id == chapterId }) {
            return idx + 1
        }
        return 1
    }
}

// MARK: - SwiftUI Schema Compatibility Extensions
extension AudioNode {
    // Unique loop-free property mapping that isolates structural identifiers completely away from UniFFI
    public var stableId: String {
        let start = self.startMs ?? 0
        let end = self.endMs ?? 0
        return "\(self.title)-\(start)-\(end)"
    }
    
    public var childrenNodes: [AudioNode]? {
        guard !self.children.isEmpty else { return nil }
        return self.children
    }
}
