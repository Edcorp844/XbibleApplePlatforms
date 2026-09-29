//
//  FontSettingsContent.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/23/26.
//

import SwiftUI
import SwiftData

struct FontSettingsContent: View {
    @EnvironmentObject private var textConfigVM: TextConfigViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var config = textConfigVM.config

        Form {
            // MARK: - Font Selection Section
            Section("Font Style") {
                Toggle("Use System Font", isOn: $config.useSystemFont)

                if config.useSystemFont {
                    Picker("Design", selection: $config.systemDesign) {
                        ForEach(Font.Design.allCases) { design in
                            Text(design.displayName).tag(design)
                        }
                    }
                    .pickerStyle(.segmented)
                } else {
                    Picker("Family", selection: Binding(
                        get: { config.fontFamilyName },
                        set: { newFamily in
                            config.fontFamilyName = newFamily
                            // Auto-select the first available style in the family.
                            if let firstFont = InstalledFonts.fontNames(in: newFamily).first {
                                config.fontPostScriptName = firstFont
                            } else {
                                config.fontPostScriptName = ""
                            }
                        }
                    )) {
                        Text("Select Family").tag("")
                        // Cached static — no per-render font-DB walk.
                        ForEach(InstalledFonts.nonEmptyFamilies, id: \.self) { family in
                            Text(family).tag(family)
                        }
                    }

                    if !config.fontFamilyName.isEmpty {
                        Picker("Variant", selection: $config.fontPostScriptName) {
                            Text("Select Style").tag("")
                            ForEach(InstalledFonts.fontNames(in: config.fontFamilyName),
                                    id: \.self) { postScriptName in
                                Text(postScriptName).tag(postScriptName)
                            }
                        }
                    }
                }

                // ── Live preview, using the exact same font path as WordView.
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("In the beginning was the Word")
                        .font(config.resolvedFont(for: dynamicTypeSize))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)

                // ── Size slider (percent-based).
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(sizeLabel)
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $config.fontSizePercent, in: -50...200, step: 5)
                }
            }

            // MARK: - Layout Section
            Section("Layout") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Line Spacing: \(String(format: "%.1f", config.lineSpacing))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $config.lineSpacing, in: 1.0...3.0, step: 0.1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Word Spacing: \(String(format: "%.1f", config.wordSpacing))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $config.wordSpacing, in: 0.0...10.0, step: 0.5)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Verse Spacing: \(String(format: "%.1f", config.verseSpacing))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $config.verseSpacing, in: 1.0...3.0, step: 0.05)
                }
            }

            // MARK: - Display Toggles Section
            Section("Display Options") {
                Toggle("Show Strong's Numbers", isOn: $config.showStrongs)
                Toggle("Show Lemma", isOn: $config.showLemma)
                Toggle("Show Morphology", isOn: $config.showMorph)
                Toggle("Show Verse Notes", isOn: $config.showVerseNotes)
                Toggle("Show Word Notes", isOn: $config.showWordNotes)
                Toggle("Words of Christ in Red", isOn: $config.showRedWords)

                Picker("Added Words Style", selection: $config.addedWordsStyle) {
                    ForEach(AddedWordsStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
            }

            // MARK: - Reset Action
            Section {
                Button(role: .destructive) {
                    textConfigVM.resetToDefaults()
                } label: {
                    Text("Reset to Defaults")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    private var sizeLabel: String {
        let pct = Int(textConfigVM.config.fontSizePercent)
        if pct == 0 { return "System" }
        return pct > 0 ? "+\(pct)%" : "\(pct)%"
    }
}
