//
//  TimelineState.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/29/26.
//


import SwiftUI
import Combine

class TimelineState: ObservableObject {
    // Tracks the current scroll position
    @Published var scrollOffset: CGPoint = .zero
    
    // Zoom level if you decide to add pinch-to-zoom later
    @Published var zoomLevel: CGFloat = 1.0
    
    /// Maps the current vertical scroll position back to a Bible Year
    /// This is useful for showing a "floating" year indicator as you scroll.
    func calculateYear(from yOffset: CGFloat) -> String {
        // Reverse math: (Y - offsetTop) / (rowHeight + gap)
        let row = (yOffset - TimelineUtils.offsetTop) / (TimelineUtils.rowHeight + TimelineUtils.rowGap)
        
        // This is a rough estimation based on a 4000 BC start
        // with 200 years per row. Adjust to match your JSON data.
        let year = 4000 - Int(row * 200)
        
        if year > 0 {
            return "\(year) BC"
        } else if year < 0 {
            return "\(abs(year)) AD"
        } else {
            return "1 AD"
        }
    }
}
