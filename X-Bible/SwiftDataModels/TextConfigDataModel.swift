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

    /// Human-readable name for pickers and menus.
    var displayName: String {
        switch self {
        case .default:    return "Default"
        case .serif:      return "Serif"
        case .rounded:    return "Rounded"
        case .monospaced: return "Monospaced"
        @unknown default: return "Unknown"
        }
    }

    /// Stable string used for persistence — decoupled from `displayName`
    /// so you can rename the UI label without invalidating saved configs.
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

// MARK: - Installed Fonts

/// Auto-discovers every font family and style available on the device.
/// No hard-coded font names — the list comes from the OS.
enum InstalledFonts {

    /// Every font family available on the system, sorted alphabetically.
    static var familyNames: [String] {
        #if os(iOS)
        return UIFont.familyNames.sorted()
        #elseif os(macOS)
        return NSFontManager.shared.availableFontFamilies.sorted()
        #else
        return []
        #endif
    }

    /// Every PostScript name within a given family.
    /// These are the values accepted by `Font.custom(_:size:)`.
    static func fontNames(in family: String) -> [String] {
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

    /// Families that actually contain at least one font — filters out empty entries.
    static var nonEmptyFamilies: [String] {
        familyNames.filter { !fontNames(in: $0).isEmpty }
    }

    /// A flat, deduplicated list of every PostScript name on the system.
    static var allFontNames: [String] {
        Array(Set(nonEmptyFamilies.flatMap { fontNames(in: $0) })).sorted()
    }
}

// MARK: - TextConfig

@Model
final class TextConfig {

    // Font
    var fontSize: Double
    var useSystemFont: Bool
    var systemDesignKey: String       // Font.Design.storageKey
    var fontFamilyName: String        // e.g. "Avenir"
    var fontPostScriptName: String    // e.g. "Avenir-Book"

    // Layout
    var lineSpacing: Double
    var wordSpacing: Double
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
        fontSize: Double = 18.0,
        useSystemFont: Bool = true,
        systemDesign: Font.Design = .default,
        fontFamilyName: String = "",
        fontPostScriptName: String = "",
        lineSpacing: Double = 1.5,
        wordSpacing: Double = 8.0,
        justify: Bool = false,
        showRedWords: Bool = true,
        showStrongs: Bool = true,
        showLemma: Bool = true,
        showMorph: Bool = true,
        showVerseNotes: Bool = true,
        showWordNotes: Bool = true,
        addedWordsStyle: AddedWordsStyle = .brackets
    ) {
        self.fontSize = fontSize
        self.useSystemFont = useSystemFont
        self.systemDesignKey = systemDesign.storageKey
        self.fontFamilyName = fontFamilyName
        self.fontPostScriptName = fontPostScriptName
        self.lineSpacing = lineSpacing
        self.wordSpacing = wordSpacing
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

    /// The `Font` the reading view should render with.
    /// Uses `Font.system` for the system-font axis, `Font.custom` for installed fonts.
    var resolvedFont: Font {
        if useSystemFont {
            return .system(size: fontSize, design: systemDesign)
        } else {
            // Fall back to system if the stored name is empty or invalid.
            guard !fontPostScriptName.isEmpty,
                  InstalledFonts.allFontNames.contains(fontPostScriptName)
            else {
                return .system(size: fontSize, design: systemDesign)
            }
            return .custom(fontPostScriptName, size: fontSize)
        }
    }
}
