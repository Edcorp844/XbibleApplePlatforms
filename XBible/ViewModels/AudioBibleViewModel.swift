//  AudioBibleViewModel.swift
//  XBible
//
import SwiftUI
import XbibleEngine
import Combine
import CoreImage

@MainActor
public class AudioBibleViewModel: ObservableObject {
    private let engine = AudioEngine()
    private var player: AudioBiblePlayer?
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()]) // Reusable cross-platform context
    
    // UI Layout States
    @Published public var availableModules: [AudioModuleInfo] = []
    @Published public var selectedModule: AudioModuleInfo?
    @Published public var playbackState: PlaybackState?
    @Published public var isLoading: Bool = false
    
    // Live UI Navigation Tree State
    @Published public var navigationTreeRoot: AudioNode?
    @Published public var selectedNodeId: String?
    
    // Unified UI Image handle + Extracted UI Gradient Colors
    #if os(macOS)
    @Published public var decodedArtwork: NSImage?
    #else
    @Published public var decodedArtwork: UIImage?
    #endif
    
    @Published public var backgroundGradientColors: [Color] = [.gray.opacity(0.2), .black] // Fallback UI colors
    
    public init() {
        refreshLibraryCatalog()
    }
    
    /// Scans the app local modules/audio path directory for compiled files
    public func refreshLibraryCatalog() {
        self.availableModules = engine.getAudioModules()
        if selectedModule == nil, let first = availableModules.first {
            selectModule(first)
        }
    }
    
    /// Loads a target .xba module without auto-starting playback
    public func selectModule(_ module: AudioModuleInfo) {
        self.selectedModule = module
        
        // Expose the raw UniFFI node directly to the layout layer
        self.navigationTreeRoot = self.engine.getNavigationTree()
        
        // Cross-Platform Image Conversion & Color Extraction
        if let data = module.artworkBytes {
            #if os(macOS)
            self.decodedArtwork = NSImage(data: data)
            #else
            self.decodedArtwork = UIImage(data: data)
            #endif
            
            // Extract UI Gradient Colors safely asynchronously or inline
            let extracted = extractGradientColors(from: data, count: 3)
            if !extracted.isEmpty {
                self.backgroundGradientColors = extracted
            }
        } else {
            self.decodedArtwork = nil
            self.backgroundGradientColors = [.gray.opacity(0.2), .black]
        }
        
        self.isLoading = true
        
        // Construct the full disk asset path using Rust data folders
        let basePath = engine.getAudioModulesPath()
        let fullPath = (basePath as NSString).appendingPathComponent(module.fileName)
        
        // Re-initialize player stack
        self.player = AudioBiblePlayer(moduleFilePath: fullPath, engine: self.engine)
        
        // Listen for 30 FPS sync bridge pushes
        self.player?.onStateUpdate = { [weak self] state in
            guard let self = self else { return }
            withAnimation(.easeInOut(duration: 0.12)) {
                self.playbackState = state
                self.isLoading = false
            }
        }
    }
    
    public func module_chapters() {
       
    }
    
    // --- CROSS-PLATFORM GRADIENT COLOR EXTRACTION CORE ENGINE ---
    
    /// Processes raw image payload bytes uniformly across macOS and iOS using native Core Image filters
    private func extractGradientColors(from imageData: Data, count: Int = 3) -> [Color] {
        // Instantiate a CIImage directly from the data stream (Works everywhere!)
        guard let ciImage = CIImage(data: imageData) else { return [] }
        
        let extent = ciImage.extent
        let tileHeight = extent.height / CGFloat(count)
        var extractedColors: [Color] = []
        
        for i in 0..<count {
            let cropRect = CGRect(
                x: extent.origin.x,
                y: extent.origin.y + (tileHeight * CGFloat(i)),
                width: extent.size.width,
                height: tileHeight
            )
            
            // Cross-platform Key-Value Coding (KVC) instantiation of the Area Average filter
            guard let filter = CIFilter(name: "CIAreaAverage") else { continue }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(cgRect: cropRect), forKey: kCIInputExtentKey)
            
            guard let outputImage = filter.outputImage else { continue }
            
            var bytes = [UInt8](repeating: 0, count: 4)
            ciContext.render(
                outputImage,
                toBitmap: &bytes,
                rowBytes: 4,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
            
            let color = Color(
                red: Double(bytes[0]) / 255.0,
                green: Double(bytes[1]) / 255.0,
                blue: Double(bytes[2]) / 255.0,
                opacity: Double(bytes[3]) / 255.0
            )
            
            extractedColors.append(color)
        }
        
        return extractedColors
    }
    
    // Audio Player Pass-Through Controls
    public func togglePlayback() {
        guard let activePlayer = player else { return }
        if activePlayer.isPlaying {
            activePlayer.pause()
        } else {
            activePlayer.play()
        }
        
        if let state = playbackState {
            playbackState = PlaybackState(
                currentTimeMs: state.currentTimeMs,
                activeAnchorIndex: state.activeAnchorIndex,
                activeText: state.activeText,
                isPlaying: activePlayer.isPlaying
            )
        }
    }
    
    public var isPlaying: Bool {
        player?.isPlaying ?? false
    }
}

//// MARK: - Swift UI Schema Compatibility Extensions
extension AudioNode: @retroactive Identifiable {
    // Maps the native unique ID property name to conform to Identifiable protocols
    public var id: String {
        return self.id
    }
    
    // Normalizes empty arrays to nil to properly control UI disclosure layout indicators
    public var childrenNodes: [AudioNode]? {
        // Since self.children is not an optional, check its emptiness directly
        guard !self.children.isEmpty else { return nil }
        return self.children
    }
}
