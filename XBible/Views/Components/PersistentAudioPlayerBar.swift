//
//  PersistentAudioPlayerBar.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/30/26.
//

import SwiftUI

struct PersistentAudioPlayerBar: View {
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0.35
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Left: Track details
                HStack(spacing: 10) {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(6)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("John 1:1")
                            .font(.headline)
                        Text("Audio Bible")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 200, alignment: .leading)
                
                // Center: Playback state controls
                VStack(spacing: 4) {
                    HStack(spacing: 20) {
                        Button(action: {}) {
                            Image(systemName: "backward.fill")
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { isPlaying.toggle() }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {}) {
                            Image(systemName: "forward.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Slider(value: $playbackProgress, in: 0...1)
                        .controlSize(.small)
                        .labelsHidden()
                }
                
                // Right: Utility and Volume controls
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2.fill")
                    Slider(value: .constant(0.7), in: 0...1)
                        .frame(width: 80)
                        .controlSize(.mini)
                }
                .frame(width: 200, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .frame(height: 60)
            .glassEffect()
        }
    }
}


