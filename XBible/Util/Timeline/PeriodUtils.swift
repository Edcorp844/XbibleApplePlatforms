//
//  PeriodUtils.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/29/26.
//

import Foundation

struct PeriodUtils {
    /// Translates the logic for "X years ago" or "Duration: Y years"
    static func formatDuration(start: Int, end: Int) -> String {
        let duration = abs(start - end)
        if duration == 0 { return "Specific Year" }
        
        return "\(duration) years"
    }
    
    /// Logic to determine if an event falls within a specific Bible Era
    static func isEventInEra(event: TimelineEvent, section: TimelineSection) -> Bool {
        return event.start >= section.startYear && event.end <= section.endYear
    }
}
