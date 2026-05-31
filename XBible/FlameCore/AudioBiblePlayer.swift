import AVFoundation
import XbibleEngine
import Combine

@MainActor
public class AudioBiblePlayer: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private let rustEngine: AudioEngine
    private var syncTimer: Timer?
    
    // 🌟 Flag to prevent the timer loop from overriding user interactions
    private var isInteracting: Bool = false
    
    @Published var navigationTree: AudioNode?
    @Published var currentPlaybackState: PlaybackState?
    
    public var onStateUpdate: ((PlaybackState) -> Void)?
    
    public init(moduleFilePath: String, engine: AudioEngine) {
        self.rustEngine = engine
        
        do {
            let rawAudioBytes = try rustEngine.loadAudioModule(filePath: moduleFilePath)
            self.navigationTree = rustEngine.getNavigationTree()
            
            let audioData = Data(rawAudioBytes)
            self.audioPlayer = try AVAudioPlayer(data: audioData)
            self.audioPlayer?.isMeteringEnabled = true
            self.audioPlayer?.prepareToPlay()
            
            rustEngine.seekToTime(targetMs: 0)
            if let initialState = rustEngine.getPlaybackState() {
                self.currentPlaybackState = initialState
                DispatchQueue.main.async { [weak self] in
                    self?.onStateUpdate?(initialState)
                }
            }
            
            setupTimer()
        } catch {
            print("[AudioBiblePlayer] Failed to load secure .xba module sequence: \(error)")
        }
    }
    
    public func play() {
        guard let player = audioPlayer else { return }
        withInteractionLock {
            player.play()
            if !(rustEngine.getPlaybackState()?.isPlaying ?? false) {
                rustEngine.togglePlayback()
            }
        }
    }
    
    public func pause() {
        guard let player = audioPlayer else { return }
        withInteractionLock {
            player.pause()
            if rustEngine.getPlaybackState()?.isPlaying ?? true {
                rustEngine.togglePlayback()
            }
        }
    }
    
    public func stop() {
        guard let player = audioPlayer else { return }
        withInteractionLock {
            player.stop()
            player.currentTime = 0
            rustEngine.stop()
        }
    }
    
    public func skipForward() {
        guard let player = audioPlayer else { return }
        withInteractionLock {
            rustEngine.skipForward()
            if let targetMs = rustEngine.getPlaybackState()?.currentTimeMs {
                player.currentTime = TimeInterval(targetMs) / 1000.0
            }
        }
    }
    
    public func skipBackward() {
        guard let player = audioPlayer else { return }
        withInteractionLock {
            rustEngine.skipBackward()
            if let targetMs = rustEngine.getPlaybackState()?.currentTimeMs {
                player.currentTime = TimeInterval(targetMs) / 1000.0
            }
        }
    }
    
    public func seekTo(ms: Int64) {
        guard let player = audioPlayer else { return }
        withInteractionLock {
            player.currentTime = TimeInterval(ms) / 1000.0
            rustEngine.seekToTime(targetMs: ms)
        }
    }
    
    public var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    // 🌟 Helper method to wrap actions and safely pause background updates
    private func withInteractionLock(_ action: () -> Void) {
        isInteracting = true
        action()
        
        // Force an immediate UI sync state evaluation matching the new values
        executeTickSync()
        
        // Relinquish control back to the 30ms loop after a small safety window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isInteracting = false
        }
    }
    
    private func setupTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                // Only write automatically if the user isn't physically pressing buttons
                if !self.isInteracting {
                    self.executeTickSync()
                }
            }
        }
        
        if let timer = syncTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func executeTickSync() {
        guard let player = audioPlayer else { return }
        
        let timeMs = Int64(player.currentTime * 1000)
        
        let engineIsPlaying = rustEngine.getPlaybackState()?.isPlaying ?? false
        if player.isPlaying != engineIsPlaying {
            rustEngine.togglePlayback()
        }
        
        rustEngine.seekToTime(targetMs: timeMs)
        
        if let state = rustEngine.getPlaybackState() {
            self.currentPlaybackState = state
            onStateUpdate?(state)
        }
    }
    
    /// Pulls the live normalized decibel power level from the hardware player (returns 0.0 to 1.0)
    public func getLiveAudioLevel() -> CGFloat {
        guard let player = audioPlayer, player.isPlaying else { return 0.1 }
        
        player.updateMeters() // Refresh data channels
        
        // Grab average power (returns a decibel scale ranging from -160dB up to 0dB max)
        let power = player.averagePower(forChannel: 0)
        
        // Convert the logarithmic decibel scale into a clean linear 0.0 -> 1.0 range
        let minDb: Float = -60.0
        if power < minDb {
            return 0.1
        } else if power >= 0.0 {
            return 1.0
        } else {
            let index = (power - minDb) / abs(minDb)
            return CGFloat(index)
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}
