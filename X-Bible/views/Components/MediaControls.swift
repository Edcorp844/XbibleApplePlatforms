//
//  AudioControls.swift
//  XBible
//
//  Created by Zoe Brooklyn on 6/1/26.
//

import SwiftUI
import XbibleEngine

struct MediaControls: View {
    @ObservedObject var viewModel: AudioBibleViewModel
    init(viewModel: AudioBibleViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View{
        HStack(spacing: 0) {
            Button(action: {}) { Text("1 x").font(.footnote).bold() }.disabled(viewModel.selectedModule == nil)
            
            Spacer()
            
            //BACKWARD SKIP 15S: Redirected to viewModel wrapper pipeline directly
            Button(action: {
                viewModel.skipBackward()
            }) {
                Image(systemName: "gobackward.15").font(.title2).bold()
            }.disabled(viewModel.selectedModule == nil)
            
            Spacer()
            
            Button(action: {
                viewModel.togglePlayback()
            }) {
                Image(systemName: (viewModel.playbackState?.isPlaying ?? false) ? "pause.fill" : "play.fill")
                    .font(.title).bold()
            }.disabled(viewModel.selectedModule == nil)
            
            Spacer()
            Button(action: {
                viewModel.skipForward()
            }) {
                Image(systemName: "goforward.30").font(.title2).bold()
            }.disabled(viewModel.selectedModule == nil)
            
            Spacer()
            
            // DYNAMIC REPEAT MODE CYCLE CONTROL: Updated properties syntax to match safe internal mappings
            let currentRepeat = viewModel.playbackState?.repeatMode ?? .off
            Button(action: {
                let nextMode: RepeatMode
                switch currentRepeat {
                case .off: nextMode = .one
                case .one: nextMode = .all
                case .all: nextMode = .off
                }
                viewModel.setRepeatMode(mode: nextMode)
            }) {
                Image(systemName: currentRepeat == .one ? "repeat.1" : "repeat")
                    .font(.title3)
                    .foregroundStyle(currentRepeat == .off ? .white.opacity(0.4) : .cyan)
            }.disabled(viewModel.selectedModule == nil)
        }
        .foregroundStyle(.white.opacity(0.8))
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
    }
}
