//
//  TimelineState.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/29/26.
//

import SwiftUI
import Combine
import XbibleEngine

/// Observes the timeline's scroll position and derives the currently-scrubbed
/// year (and period) from it. Kept independent of layout constants — all year
/// math is done against the live `periods` collection.
final class TimelineState: ObservableObject {

    // MARK: - Published state

    /// Raw horizontal scroll offset of the timeline's ScrollView.
    /// Positive = scrolled right (toward more recent years).
    @Published var horizontalOffset: CGFloat = 0

    /// Zoom factor (1.0 = base `pixelsPerYear`).
    @Published var zoomLevel: CGFloat = 1.0

    /// Base pixel-per-year at zoom 1.0. Must match the view's `basePixelsPerYear`.
    var basePixelsPerYear: CGFloat = 1.2

    /// Half of the ScrollView viewport width — required because the view uses
    /// `.safeAreaPadding(.horizontal, halfWidth)` so the first/last years can
    /// sit under the center scrubber.
    var halfWidth: CGFloat = 0

    /// Events grouped by period (source of truth for min/max year).
    var periods: [Period] = []

    // MARK: - Derived values

    var pixelsPerYear: CGFloat { basePixelsPerYear * zoomLevel }

    /// Earliest year in the dataset (falls back to -4100 when empty).
    var minYear: Int64 {
        periods.map(\.startYear).min() ?? -4100
    }

    /// Latest year in the dataset (falls back to 2100 when empty).
    var maxYear: Int64 {
        periods.map(\.endYear).max() ?? 2100
    }

    /// Total years spanned.
    var totalYears: Int64 { max(1, maxYear - minYear) }

    /// Year currently under the center scrubber, derived from horizontal scroll.
    /// Accounts for the "no year 0" convention (BC → AD jumps from -1 to +1).
    var centerYear: Int64 {
        guard pixelsPerYear > 0 else { return minYear }
        let rawYears = (horizontalOffset - halfWidth) / pixelsPerYear
        var year = minYear + Int64(rawYears)
        if year >= 0 { year += 1 }
        return min(max(year, minYear), maxYear)
    }

    /// Formatted center year, e.g. "100 BC" / "AD 200" / "0".
    var centerYearLabel: String {
        TimelineUtils.yearLabel(centerYear)
    }

    /// The period that contains `centerYear`.
    var currentPeriod: Period? {
        let y = centerYear
        return periods.first { y >= $0.startYear && y <= $0.endYear }
    }

    /// Nearest period entirely before `centerYear` (for prev navigation).
    var prevPeriod: Period? {
        let y = centerYear
        return periods
            .filter { $0.startYear < y - 2 }
            .max(by: { $0.startYear < $1.startYear })
    }

    /// Nearest period entirely after `centerYear` (for next navigation).
    var nextPeriod: Period? {
        let y = centerYear
        return periods
            .filter { $0.startYear > y + 2 }
            .min(by: { $0.startYear < $1.startYear })
    }

    /// 0…1 progress across the whole timeline (drives the bottom progress bar).
    var progress: CGFloat {
        guard totalYears > 0 else { return 0 }
        let raw = CGFloat(centerYear - minYear) / CGFloat(totalYears)
        return min(max(raw, 0), 1)
    }

    /// Convert a scroll offset to a year (useful if the view needs it directly).
    func year(fromHorizontalOffset offset: CGFloat) -> Int64 {
        guard pixelsPerYear > 0 else { return minYear }
        let rawYears = (offset - halfWidth) / pixelsPerYear
        var year = minYear + Int64(rawYears)
        if year >= 0 { year += 1 }
        return min(max(year, minYear), maxYear)
    }

    /// Horizontal offset needed to place `year` under the center scrubber.
    /// Use this to implement prev/next scrolling via `ScrollViewReader` (or by
    /// setting `horizontalOffset` and letting the view respond).
    func horizontalOffset(forYear year: Int64) -> CGFloat {
        var target = year
        if target > 0 { target -= 1 } // undo the BC→AD hop
        let years = CGFloat(target - minYear)
        return years * pixelsPerYear + halfWidth
    }
}
