//
//  AudioControls.swift
//  XBible
//
//  Created by Zoe Brooklyn on 6/1/26.
//

import SwiftUI
import XbibleEngine

@MainActor
struct MediaControls: View {
    @ObservedObject var viewModel: AudioBibleViewModel
    
    init(viewModel: AudioBibleViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 1. Playback Speed Button
            Button(action: {
                // Future implementation
            }) {
                Text("1 x")
                    .font(.footnote)
                    .bold()
            }
            .disabled(viewModel.selectedModule == nil)
            
            Spacer()
            
            Group{
                // 2. BACKWARD SKIP 15S
                Button(action: {
                    viewModel.skipBackward()
                }) {
                    Image(systemName: "gobackward.15")
                }
                .disabled(viewModel.selectedModule == nil)
                
                Spacer()
                
                // 3. PLAY / PAUSE TRANSPORT CONTROL
                Button(action: {
                    viewModel.togglePlayback()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }
                .disabled(viewModel.selectedModule == nil)
                
                Spacer()
                
                // 4. FORWARD SKIP 30S
                Button(action: {
                    viewModel.skipForward()
                }) {
                    Image(systemName: "goforward.30")
                }
                .disabled(viewModel.selectedModule == nil)
            }
            .font(.largeTitle)
            .bold()
            
            Spacer()
            
            // 5. DYNAMIC REPEAT MODE CYCLE CONTROL
            Button(action: {
                let nextMode: RepeatMode
                // 🚀 Reads directly from the safe exposed view model property
                switch viewModel.currentRepeatMode {
                case .off: nextMode = .one
                case .one: nextMode = .all
                case .all: nextMode = .off
                }
                viewModel.setRepeatMode(mode: nextMode)
            }) {
                Image(systemName: viewModel.currentRepeatMode == .one ? "repeat.1" : "repeat")
                    .font(.title3)
                    .foregroundStyle(viewModel.currentRepeatMode == .off ? .white.opacity(0.4) : .cyan)
            }
            .disabled(viewModel.selectedModule == nil)
        }
        .foregroundStyle(.white.opacity(0.8))
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
    }
}
