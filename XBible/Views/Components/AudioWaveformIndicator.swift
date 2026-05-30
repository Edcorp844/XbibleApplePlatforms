//
//  AudioWaveformIndicator.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/31/26.
//


import SwiftUI

struct AudioWaveformIndicator: View {
    // Driven by a high-frequency timeline update loop that skips standard layout checks
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.15, paused: false)) { timeline in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white)
                        .frame(width: 3, height: getHeight(for: index, at: timeline.date))
                        .animation(.easeInOut(duration: 0.15), value: timeline.date)
                }
            }
            .frame(width: 24, height: 14, alignment: .leading)
        }
    }
    
    // Mathematical wave function generates deterministic layout vectors smoothly over time
    private func getHeight(for index: Int, at date: Date) -> CGFloat {
        let time = date.timeIntervalSince1970
        let base = sin(time * 8.0 + Double(index) * 2.5) // Oscillate values using sine calculations
        let absoluteValue = abs(base) // Keep digits absolute
        
        // Return heights safely bound between 4pt and 14pt
        return 4.0 + CGFloat(absoluteValue * 10.0)
    }
}
