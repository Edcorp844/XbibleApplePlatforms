import AVFoundation
import XbibleEngine
import Combine

@MainActor
public class AudioBiblePlayer: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private let rustEngine: AudioEngine
    private var syncTimer: Timer?
    
    // Properties published straight to SwiftUI front-end views
    @Published var navigationTree: AudioNode?
    @Published var currentPlaybackState: PlaybackState?

    public var onStateUpdate: ((PlaybackState) -> Void)?

    /// Initializes the player by passing the path of the .xba module to the Rust engine
    public init(moduleFilePath: String, engine: AudioEngine) {
        self.rustEngine = engine
        
        do {
            // 1. Tell Rust to open the container, parse the tree structure JSON, decrypt, and get data bytes
            let rawAudioBytes = try rustEngine.loadAudioModule(filePath: moduleFilePath)
            
            // 2. Extract and hold onto the structural hierarchy map for navigation UI layouts
            self.navigationTree = rustEngine.getNavigationTree()
            
            // 3. Initialize the audio player from memory bytes
            let audioData = Data(rawAudioBytes)
            self.audioPlayer = try AVAudioPlayer(data: audioData)
            self.audioPlayer?.prepareToPlay()
            
            // 4. Query the engine for baseline starting frame state (0ms) using the synchronized helper
            if let initialState = rustEngine.updatePlaybackSync(currentTimeMs: 0, isPlaying: false) {
                self.currentPlaybackState = initialState
                DispatchQueue.main.async { [weak self] in
                    self?.onStateUpdate?(initialState)
                }
            }
            
            // 5. Kick off the UI synchronization timer loop
            setupTimer()
        } catch {
            print("[AudioBiblePlayer] Failed to load secure .xba module sequence: \(error)")
        }
    }
    
    public func play() {
        audioPlayer?.play()
    }
    
    public func pause() {
        audioPlayer?.pause()
    }
    
    public var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    /// Allow the UI navigation menu taps to hop straight to timestamps anywhere inside the track file!
    public func seekTo(node: AudioNode) {
        guard let player = audioPlayer, let startMs = node.startMs else { return }
        player.currentTime = TimeInterval(startMs) / 1000.0
        tickSync()
    }
    
    private func setupTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.tickSync()
            }
        }
        
        if let timer = syncTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func tickSync() {
        guard let player = audioPlayer else { return }
        
        let timeMs = Int64(player.currentTime * 1000)
        let playing = player.isPlaying
        
        if let state = rustEngine.updatePlaybackSync(currentTimeMs: timeMs, isPlaying: playing) {
            self.currentPlaybackState = state
            onStateUpdate?(state)
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}
