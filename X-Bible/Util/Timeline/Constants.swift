import SwiftUI

enum TimelineUtils {
    static func yearLabel(_ year: Int64) -> String {
        if year < 0 { return "\(-year) BC" }
        if year == 0 { return "0" }
        return "\(year) AD"
    }

    static func rangeLabel(start: Int64, end: Int64) -> String {
        start == end
            ? yearLabel(start)
            : "\(yearLabel(start)) – \(yearLabel(end))"
    }

    static func calculateLabel(start: Int, end: Int) -> String {
        rangeLabel(start: Int64(start), end: Int64(end))
    }

    static func color(from hex: String, fallback: Color = .accentColor) -> Color {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            return fallback
        }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8)  & 0xFF) / 255
        let b = Double( value        & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }
}
