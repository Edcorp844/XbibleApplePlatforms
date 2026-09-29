//
//  BookAndGlassesIcon.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/23/26.
//

import SwiftUI

/// A pure SwiftUI vector shape matching your exact book and glasses icon style,
/// implemented using precise Bézier curves and the even-odd fill rule.
struct BookAndGlassesIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let scaleX = rect.width / 800.0
        let scaleY = rect.height / 800.0
        
        let pt: (CGFloat, CGFloat) -> CGPoint = { x, y in
            CGPoint(x: x * scaleX, y: y * scaleY)
        }
        
        // MARK: - 1. Glasses Frame & Lenses
        path.move(to: pt(400, 150))
        path.addCurve(to: pt(715, 130), control1: pt(520, 145), control2: pt(640, 130))
        path.addCurve(to: pt(745, 157), control1: pt(735, 130), control2: pt(745, 142))
        path.addCurve(to: pt(715, 182), control1: pt(745, 172), control2: pt(735, 182))
        path.addLine(to: pt(655, 182))
        path.addCurve(to: pt(540, 325), control1: pt(655, 240), control2: pt(630, 315))
        path.addCurve(to: pt(440, 260), control1: pt(485, 331), control2: pt(450, 300))
        path.addCurve(to: pt(360, 260), control1: pt(428, 215), control2: pt(372, 215))
        path.addCurve(to: pt(260, 325), control1: pt(350, 300), control2: pt(315, 331))
        path.addCurve(to: pt(145, 182), control1: pt(170, 315), control2: pt(145, 240))
        path.addLine(to: pt(85, 182))
        path.addCurve(to: pt(55, 157), control1: pt(65, 182), control2: pt(55, 172))
        path.addCurve(to: pt(85, 130), control1: pt(55, 142), control2: pt(65, 130))
        path.addCurve(to: pt(400, 150), control1: pt(160, 130), control2: pt(280, 145))
        path.closeSubpath()
        
        // Left Lens Cutout
        path.move(to: pt(170, 195))
        path.addCurve(to: pt(345, 195), control1: pt(230, 200), control2: pt(290, 200))
        path.addCurve(to: pt(260, 285), control1: pt(345, 240), control2: pt(325, 285))
        path.addCurve(to: pt(170, 195), control1: pt(195, 285), control2: pt(170, 240))
        path.closeSubpath()
        
        // Right Lens Cutout
        path.move(to: pt(630, 195))
        path.addCurve(to: pt(455, 195), control1: pt(570, 200), control2: pt(510, 200))
        path.addCurve(to: pt(540, 285), control1: pt(455, 240), control2: pt(475, 285))
        path.addCurve(to: pt(630, 195), control1: pt(605, 285), control2: pt(630, 240))
        path.closeSubpath()
        
        // MARK: - 2. Book Body & Cutout
        let bookRect = CGRect(x: 90 * scaleX, y: 410 * scaleY, width: 620 * scaleX, height: 280 * scaleY)
        path.addRoundedRect(in: bookRect, cornerSize: CGSize(width: 56 * scaleX, height: 56 * scaleY))
        
        // Inner Page Split & Bookmark Loop
        path.move(to: pt(654, 466))
        path.addLine(to: pt(420, 466))
        path.addArc(center: pt(420, 550), radius: 84 * scaleX, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        path.addLine(to: pt(654, 634))
        path.addLine(to: pt(654, 578))
        path.addLine(to: pt(420, 578))
        path.addArc(center: pt(420, 550), radius: 28 * scaleX, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: false)
        path.addLine(to: pt(654, 522))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Preview & Usage
struct BookAndGlassesIcon_Previews: PreviewProvider {
    static var previews: some View {
        BookAndGlassesIcon()
            .fill(Color.primary, style: FillStyle(eoFill: true))
            .frame(width: 64, height: 64)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
