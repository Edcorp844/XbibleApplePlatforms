//
//  TimelineBackgroundGrid.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/29/26.
//
import SwiftUI

struct TimelineBackgroundGrid: View {
    let startYear: Int
    let pixelsPerYear: CGFloat
    
    let timelineStartYear = -4100
    let timelineEndYear = 2100
    
    var body: some View {
        let years = Array(stride(from: timelineStartYear, to: timelineEndYear, by: 100))
        
        ZStack(alignment: .topLeading) {
            ForEach(years, id: \.self) { year in
                let xPos = CGFloat(year - timelineStartYear) * pixelsPerYear
                
                // Vertical Grid Line
                Rectangle()
                    .fill(.foreground.opacity(0.4)) 
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .offset(x: xPos)
            }
        }
    }
}
