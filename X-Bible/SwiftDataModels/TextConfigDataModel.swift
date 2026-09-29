//
//  TextConfig.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/23/26.
//

import SwiftData
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Added Words Style

enum AddedWordsStyle: String, Codable, CaseIterable, Identifiable {
    case brackets  = "Brackets"
    case italic    = "Italic"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

// MARK: - Font.Design helpers

extension Font.Design: @retroactive CaseIterable, @retroactive Identifiable {

    public static var allCases: [Font.Design] {
        [.default, .serif, .rounded, .monospaced]
    }

    public var id: String { storageKey }

    var displayName: String {
        switch self {
        case .default:    return "Default"
        case .serif:      return "Serif"
        case .rounded:    return "Rounded"
        case .monospaced: return "Monospaced"
        @unknown default: return "Unknown"
        }
    }

    var storageKey: String {
        switch self {
        case .default:    return "default"
        case .serif:      return "serif"
        case .rounded:    return "rounded"
        case .monospaced: return "monospaced"
        @unknown default: return "default"
        }
    }

    init(storageKey: String) {
        self = Font.Design.allCases.first { $0.storageKey == storageKey } ?? .default
    }
}

// MARK: - Installed Fonts (cached)

/// Auto-discovers every font family and style available on the device.
/// The full enumeration is **expensive** — it walks the OS font database —
/// so we compute it lazily once and cache both the family list and the
/// PostScript-name set for the lifetime of the process.
enum InstalledFonts {

    // MARK: Cached storage

    /// Every non-empty family, sorted. Computed once, lazily.
    static let nonEmptyFamilies: [String] = {
        let all: [String]
        #if os(iOS)
        all = UIFont.familyNames
        #elseif os(macOS)
        all = NSFontManager.shared.availableFontFamilies
        #else
        all = []
        #endif
        return all
            .filter { !fontNamesUncached(in: $0).isEmpty }
            .sorted()
    }()

    /// Set of every PostScript name on the device. `O(1)` membership test.
    private static let installedPostScriptNames: Set<String> = {
        Set(nonEmptyFamilies.flatMap { fontNamesUncached(in: $0) })
    }()

    /// Cached, sorted list of every PostScript name.
    static let allFontNames: [String] = {
        installedPostScriptNames.sorted()
    }()

    // MARK: Public API

    /// Fast membership test. Use this instead of `allFontNames.contains(_:)`.
    @inline(__always)
    static func isInstalled(_ postScriptName: String) -> Bool {
        installedPostScriptNames.contains(postScriptName)
    }

    /// PostScript names within a given family. Cached per family.
    /// These are the values accepted by `Font.custom(_:size:)`.
    static func fontNames(in family: String) -> [String] {
        fontNamesCache[family] ?? {
            let names = fontNamesUncached(in: family)
            fontNamesCache[family] = names
            return names
        }()
    }

    private static var fontNamesCache: [String: [String]] = [:]

    // MARK: Uncached primitives

    private static func fontNamesUncached(in family: String) -> [String] {
        #if os(iOS)
        return UIFont.fontNames(forFamilyName: family).sorted()
        #elseif os(macOS)
        return (NSFontManager.shared.availableMembers(ofFontFamily: family) ?? [])
            .compactMap { $0.first as? String }
            .sorted()
        #else
        return []
        #endif
    }

    /// Kept for callers that want raw family names (e.g. pickers that
    /// filter themselves). Prefer `nonEmptyFamilies` in hot paths.
    static var familyNames: [String] {
        #if os(iOS)
        return UIFont.familyNames.sorted()
        #elseif os(macOS)
        return NSFontManager.shared.availableFontFamilies.sorted()
        #else
        return []
        #endif
    }
}

// MARK: - TextConfig

@Model
final class TextConfig {

    // Font
    /// Percentage offset relative to the OS's current `.body` point size.
    /// `0` = exactly system size. `+50` = 50% larger. `-25` = 25% smaller.
    /// See `scaledPointSize(for:)` for how this composes.
    var fontSizePercent: Double

    var useSystemFont: Bool
    var systemDesignKey: String       // Font.Design.storageKey
    var fontFamilyName: String        // e.g. "Avenir"
    var fontPostScriptName: String    // e.g. "Avenir-Book"

    // Layout
    var lineSpacing: Double
    var wordSpacing: Double
    var verseSpacing: Double
    var justify: Bool

    // Display toggles
    var showRedWords: Bool
    var showStrongs: Bool
    var showLemma: Bool
    var showMorph: Bool
    var showVerseNotes: Bool
    var showWordNotes: Bool

    // Added-words rendering
    var addedWordsStyleRaw: String

    init(
        fontSizePercent: Double = 0,
        useSystemFont: Bool = true,
        systemDesign: Font.Design = .default,
        fontFamilyName: String = "",
        fontPostScriptName: String = "",
        lineSpacing: Double = 1.5,
        wordSpacing: Double = 1.5,
        verseSpacing: Double = 1.5,
        justify: Bool = false,
        showRedWords: Bool = true,
        showStrongs: Bool = true,
        showLemma: Bool = true,
        showMorph: Bool = true,
        showVerseNotes: Bool = true,
        showWordNotes: Bool = true,
        addedWordsStyle: AddedWordsStyle = .brackets
    ) {
        self.fontSizePercent = fontSizePercent
        self.useSystemFont = useSystemFont
        self.systemDesignKey = systemDesign.storageKey
        self.fontFamilyName = fontFamilyName
        self.fontPostScriptName = fontPostScriptName
        self.lineSpacing = lineSpacing
        self.wordSpacing = wordSpacing
        self.verseSpacing = verseSpacing
        self.justify = justify
        self.showRedWords = showRedWords
        self.showStrongs = showStrongs
        self.showLemma = showLemma
        self.showMorph = showMorph
        self.showVerseNotes = showVerseNotes
        self.showWordNotes = showWordNotes
        self.addedWordsStyleRaw = addedWordsStyle.rawValue
    }

    // MARK: - Computed accessors

    var systemDesign: Font.Design {
        get { Font.Design(storageKey: systemDesignKey) }
        set { systemDesignKey = newValue.storageKey }
    }

    var addedWordsStyle: AddedWordsStyle {
        get { AddedWordsStyle(rawValue: addedWordsStyleRaw) ?? .brackets }
        set { addedWordsStyleRaw = newValue.rawValue }
    }

    // MARK: - Resolved font

    /// The point size the reader should render at, given the current
    /// Dynamic Type level. Composes:
    ///
    ///     systemBody × (1 + fontSizePercent/100)
    ///
    /// Clamped to `11...120` so the layout stays usable at the extremes.
    @inline(__always)
    func scaledPointSize(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let systemBody = dynamicTypeSize.systemBodyPointSize
        let multiplier = 1.0 + (fontSizePercent / 100.0)
        let raw = systemBody * multiplier
        return min(max(raw, 11), 120)
    }

    /// The `Font` the reading view should render with, given the current
    /// Dynamic Type size. Uses `Font.system` on the system-font axis,
    /// `Font.custom` for installed custom fonts.
    @inline(__always)
    func resolvedFont(for dynamicTypeSize: DynamicTypeSize) -> Font {
        let size = scaledPointSize(for: dynamicTypeSize)

        if useSystemFont {
            return .system(size: size, design: systemDesign)
        }

        guard !fontPostScriptName.isEmpty,
              InstalledFonts.isInstalled(fontPostScriptName)
        else {
            return .system(size: size, design: systemDesign)
        }
        return .custom(fontPostScriptName, size: size)
    }
}
