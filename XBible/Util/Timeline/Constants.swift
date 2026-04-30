//
//  Constat.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/29/26.
//

import SwiftUI

struct TimelineUtils {
    // MARK: - Constants
    static let offsetTop: CGFloat = 50
    static let rows: CGFloat = 24
    static let rowHeight: CGFloat = 30
    static let rowGap: CGFloat = 10
    
    static let scrollViewHeight: CGFloat = offsetTop + rows * (rowHeight + rowGap)
    
    /// Logic to calculate the Y position based on the row index
    static func rowToPx(row: CGFloat) -> CGFloat {
        return offsetTop + row * (rowHeight + rowGap)
    }
    
    static func xForYear(_ year: Int, startYear: Int, pixelsPerYear: CGFloat) -> CGFloat {
            return CGFloat(year - startYear) * pixelsPerYear
        }

    // MARK: - Helper Functions
    
    /// Maps a value from one range to another
//    static func mapRange(
//        current: Double,
//        from: ClosedRange<Double>,
//        to: ClosedRange<Double>
//    ) -> Double {
//        return to.lowerBound + ((to.upperBound - to.lowerBound) * (current - from.lowerBound)) / (from.upperBound - from.lowerBound)
//    }
    
    static func mapRange(current: CGFloat, fromMin: CGFloat, fromMax: CGFloat, toMin: CGFloat, toMax: CGFloat) -> CGFloat {
            return toMin + ((toMax - toMin) * (current - fromMin)) / (fromMax - fromMin)
        }
    
    /// Generates the label for dates (BC/AD and prophetic eras) in English
    static func calculateLabel(start: Int, end: Int) -> String {
        let absStart = abs(start)
        let absEnd = abs(end)
        let suffix = start < 0 ? " BC" : ""
        
        if start == end {
            return "\(absStart)\(suffix)"
        } else {
            return "\(absStart)\(suffix) - \(absEnd)\(end < 0 ? " BC" : "")"
        }
    }
}


