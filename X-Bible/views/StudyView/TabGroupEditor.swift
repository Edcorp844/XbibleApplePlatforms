//
//  TabGroupEditor.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/28/26.
//


//
//  TabGroupEditor.swift
//  X-Bible
//

#if os(iOS)

import SwiftUI

struct TabGroupEditor: View {
    @Environment(\.dismiss) private var dismiss

    /// Nil → create mode. Non-nil → rename/edit mode.
    let existing: TabGroup?

    /// Passes (name, persistence). Caller routes to createGroup or
    /// renameGroup + setGroupPersistence.
    let onSave: (String, TabGroupPersistence) -> Void

    @State private var name: String = ""
    @State private var persistence: TabGroupPersistence = .persistent

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Group Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                }

                Section {
                    Picker("Persistence", selection: $persistence) {
                        ForEach(TabGroupPersistence.allCases) { option in
                            Label(option.displayName, systemImage: option.icon)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Storage")
                } footer: {
                    Text(persistence.description)
                }
            }
            .navigationTitle(existing == nil ? "New Group" : "Rename Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespaces), persistence)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let existing {
                    name = existing.name
                    persistence = existing.persistence
                }
            }
        }
    }
}
#endif
