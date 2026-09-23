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
                            // Automatically select the first available style in the family
                            if let firstFont = InstalledFonts.fontNames(in: newFamily).first {
                                config.fontPostScriptName = firstFont
                            }
                        }
                    )) {
                        Text("Select Family").tag("")
                        ForEach(InstalledFonts.nonEmptyFamilies, id: \.self) { family in
                            Text(family).tag(family)
                        }
                    }

                    if !config.fontFamilyName.isEmpty {
                        Picker("Variant", selection: $config.fontPostScriptName) {
                            Text("Select Style").tag("")
                            ForEach(InstalledFonts.fontNames(in: config.fontFamilyName), id: \.self) { postScriptName in
                                Text(postScriptName).tag(postScriptName)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Size: \(Int(config.fontSize)) pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $config.fontSize, in: 10...36, step: 1)
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

                //Toggle("Justify Text", isOn: $config.justify)
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
                Button(role: .destructive, action: {
                    textConfigVM.resetToDefaults()
                }) {
                    Text("Reset to Defaults")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 340, height: 480)
    }
}
