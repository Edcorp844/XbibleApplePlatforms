//
//  BookView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/22/26.
//

import SwiftUI
import XbibleEngine

struct BookView: View {
    let module: SwordModule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // --- THE PHYSICAL BOOK ---
            ZStack {
                // Book Cover Base - Uses the new persistent random color
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 4,
                    bottomTrailingRadius: 6,
                    topTrailingRadius: 6
                )
                .fill(generatePersistentColor(for: "\(module.name)\(module.description)"))
                
                // Rust-style Gradients (Crease, Shine, and Depth)
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 4,
                    bottomTrailingRadius: 6,
                    topTrailingRadius: 6
                )
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.35), location: 0),   // Left Edge Shadow
                            .init(color: .white.opacity(0.15), location: 0.05), // Spine Crease Highlight
                            .init(color: .clear, location: 0.12)              // Flat Cover
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                
                // Spine Border Highlight
                HStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 3)
                    Spacer()
                }

                // Cover Content (Title & Version)
                VStack(spacing: 0) {
                    Text(module.description)
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                        .lineLimit(8)
                        .minimumScaleFactor(0.7)
                    
                    Spacer()
                    
                    Text("Version \(module.version)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 24)
            }
            .frame(width: 150, height: 210)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 5, y: 10)
            .scaleEffect( 1.0)
        }
        .padding(10)
    }
    
    
    func generatePersistentColor(for input: String) -> Color {
        let hash = input.hashValue
        let hue = Double(abs(hash % 1000)) / 1000.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.45)
    }
}
