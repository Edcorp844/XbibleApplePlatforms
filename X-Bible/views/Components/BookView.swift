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

    // MARK: - Safe color (defends against NaN / out-of-range signatureColor values
    // that crash Core Graphics via argb32_shade when used in a LinearGradient)

    private var safeColor: Color {
        let h = module.signatureColor.hue
        let s = module.signatureColor.saturation
        let b = module.signatureColor.brightness

        return Color(
            hue: h.isFinite ? min(max(h, 0), 1) : 0,
            saturation: s.isFinite ? min(max(s, 0), 1) : 0.5,
            brightness: b.isFinite ? min(max(b, 0), 1) : 0.5
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // --- THE PHYSICAL BOOK ---
            ZStack {
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 4,
                    bottomTrailingRadius: 6,
                    topTrailingRadius: 6
                )
                .fill(safeColor)

                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 4,
                    bottomTrailingRadius: 6,
                    topTrailingRadius: 6
                )
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.35), location: 0),    // Left Edge Shadow
                            .init(color: .white.opacity(0.15), location: 0.05), // Spine Crease Highlight
                            .init(color: .clear, location: 0.12)                // Flat Cover
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
            .drawingGroup()   // Renders via Metal, bypassing the CPU argb32_shade path
            .shadow(color: .black.opacity(0.3), radius: 8, x: 5, y: 10)
            .scaleEffect(1.0)
        }
        .padding(10)
    }
}
