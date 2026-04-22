//
//  PhysicalBookView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/21/26.
//

import SwiftUI
import XbibleEngine

struct PhysicalBookView: View {
    let module: XbibleEngine.SwordModule
    @EnvironmentObject var wrapper: SwordEngineWrapper
    @ObservedObject var viewModel: StoreViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // --- THE PHYSICAL BOOK ---
            ZStack {
                // Book Cover Base - Uses the new persistent random color
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 4,
                    bottomTrailingRadius: 12,
                    topTrailingRadius: 12
                )
                .fill(generatePersistentColor(for: "\(module.name)\(module.description)"))
                
                // Rust-style Gradients (Crease, Shine, and Depth)
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 4,
                    bottomTrailingRadius: 12,
                    topTrailingRadius: 12
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
            .frame(width: 150, height: 210) // Slightly adjusted for better shelf ratio
            .shadow(color: .black.opacity(0.3), radius: 8, x: 5, y: 10)
            .scaleEffect( 1.0)

            // --- BOTTOM INFO BAR ---
            HStack(spacing: 8) {
                VStack(alignment: .leading){
                    Text(module.name)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    Text(module.description)
                        .lineLimit(1)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                installButton
            }
            .frame(width: 150)
            .offset(y:  4)
        }
        .padding(10)
    }
    
    
    private var installButton: some View {
        let status = viewModel.installationStates[module.name] ?? .idle
        
        return Group {
            switch status {
            case .idle:
                Button {
                    viewModel.install(module: module, wrapper: wrapper)
                } label: {
                    Text("Get")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .overlay(Capsule().stroke(Color.accentColor, lineWidth: 1.2))

            case .installed:
                Button {
                    // Open logic here
                } label: {
                    Text("Open")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .overlay(Capsule().stroke(Color.secondary.opacity(0.5), lineWidth: 1.2))

            case .pending:
                // Just showing progress, not a button
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 24, height: 24)

            case .installing(let details):
                // Just showing progress, not a button
                ZStack {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: details.progress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(details.progress * 100))")
                        .font(.system(size: 7, weight: .bold))
                }
                .frame(width: 24, height: 24)

            case .cancelled:
                Text("Cancelled")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(height: 24)
            }
        }
        .frame(minWidth: 50)
    }
    
    
    
    /// Generates a deterministic color based on the module name.
    /// This ensures the color is "random" but persistent for each specific book.
    func generatePersistentColor(for input: String) -> Color {
        let hash = input.hashValue
        // Generate a hue between 0 and 1 based on the hash
        let hue = Double(abs(hash % 1000)) / 1000.0
        // We keep saturation and brightness high for a "rich" library look
        return Color(hue: hue, saturation: 0.5, brightness: 0.45)
    }
}

