//
//  AudioMinipPayer.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 6/12/26.
//
import SwiftUI
import XbibleEngine

struct AudioMinipPayer: View {
    @ObservedObject var viewModel: AudioBibleViewModel
    @State private var localScrubProgress: Double? = nil
    
    init(viewModel: AudioBibleViewModel) {
        self.viewModel = viewModel
    }
    var body: some View {
        HStack(spacing: 12) {
            
            HStack{
                if let artwork = viewModel.decodedArtwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    
                } else {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                }
                
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.selectedModule?.metadata?.displayTitle ?? "Audio Chapter").bold()
                    Text(viewModel.currentActiveTitle)
                }
                .font(.footnote)
                .lineLimit(1)
            }
            
            
            Spacer(minLength: 0)
            
            Group{
                Button(action: {
                    viewModel.togglePlayback()
                }) {
                    Image(systemName: viewModel.playbackState?.isPlaying == true ? "pause.fill" : "play.fill")
                    
                }
                
                Button(action: {
                    viewModel.skipForward()
                }) {
                    Image(systemName: "goforward.30")
                }
            }
            .font(.title2)
            .foregroundStyle(.primary, .primary)
            .buttonStyle(.plain)
            .disabled(viewModel.selectedModule == nil)
        }
        .padding(.horizontal, 15)
    }
    
}
    

