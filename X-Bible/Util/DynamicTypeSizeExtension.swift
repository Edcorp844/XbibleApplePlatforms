//
//  DynamicTypeScale.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/23/26.
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension DynamicTypeSize {

    /// The point size the OS would use for a plain `Text` with `.font(.body)`
    /// at this Dynamic Type level.
    ///
    /// On iOS this is derived from `UIFontMetrics`, so it exactly matches
    /// Apple's curve. `17` at default `.large`, `~13` at `.xSmall`,
    /// `~53` at `.accessibility5`.
    ///
    /// On macOS the discrete case values below approximate Apple's
    /// published multipliers on top of the 13pt macOS body size.
    var systemBodyPointSize: CGFloat {
        #if os(iOS)
        return UIFont.preferredFont(forTextStyle: .body).pointSize
        #elseif os(macOS)
        let base: CGFloat = 13
        switch self {
        case .xSmall:         return base * 0.82
        case .small:          return base * 0.88
        case .medium:         return base * 0.94
        case .large:          return base * 1.00
        case .xLarge:         return base * 1.12
        case .xxLarge:        return base * 1.23
        case .xxxLarge:       return base * 1.35
        case .accessibility1: return base * 1.64
        case .accessibility2: return base * 1.95
        case .accessibility3: return base * 2.35
        case .accessibility4: return base * 2.76
        case .accessibility5: return base * 3.12
        @unknown default:     return base
        }
        #else
        return 17
        #endif
    }
}
