//
//  MarqueeTextView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/31/26.
//


import SwiftUI

struct MarqueeTextView: View {
    let text: String
        
        @State private var textWidth: CGFloat = 0
        @State private var offset: CGFloat = 0
        
        var body: some View {
            GeometryReader { geo in
                HStack(spacing: 30) { // Space between the main title and its trailing duplicate loop
                    Text(text)
                        .fixedSize(horizontal: true, vertical: false)
                        .background(
                            GeometryReader { textGeo in
                                Color.clear
                                    .onAppear {
                                        textWidth = textGeo.size.width
                                        startAnimation(containerWidth: geo.size.width)
                                    }
                            }
                        )
                    
                    // Only render the repeating twin string if the title is actually too long for the cell row
                    if textWidth > geo.size.width {
                        Text(text)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .offset(x: offset)
            }
            .frame(height: 18)
            .clipped()
        }
        
        private func startAnimation(containerWidth: CGFloat) {
            // Safe check: Only kick off processing if text width spills past visible allocation frame boundaries
            guard textWidth > containerWidth else { return }
            
            // Compute structural baseline distance speed vectors
            // Total movement range is equal to the text width + our custom HStack padding (30 points)
            let totalDistance = textWidth + 30
            let uniformSpeed = 10.0 // Adjusted points-per-second marker for a comfortable reading pace
            let calculatedDuration = Double(totalDistance / uniformSpeed)
            
            // Loop the state machine vectors infinitely
            withAnimation(.linear(duration: calculatedDuration).repeatForever(autoreverses: false)) {
                offset = -totalDistance
            }
        }
}
