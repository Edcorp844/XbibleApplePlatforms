//
//  ManageTabGroupsView.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/28/26.
//


//
//  ManageTabGroupsView.swift
//  X-Bible
//

#if os(iOS)
import SwiftUI

struct ManageTabGroupsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: StudyViewModel

    /// Presented when the user taps "New Group" or "Rename".
    @State private var editingGroup: TabGroup? = nil
    @State private var showEditor = false

    /// Delete confirmation.
    @State private var groupPendingDeletion: TabGroup? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.tabGroups) { group in
                        row(for: group)
                    }
                    .onMove(perform: moveGroups)
                } header: {
                    Text("Groups")
                } footer: {
                    Text("Drag to reorder. Swipe a row to delete.")
                }

                Section {
                    Button {
                        editingGroup = nil
                        showEditor = true
                    } label: {
                        Label("New Group", systemImage: "plus.circle.fill")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active)) // always show grab handles
            .navigationTitle("Manage Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showEditor) {
                TabGroupEditor(existing: editingGroup) { name, persistence in
                    if let editingGroup {
                        viewModel.renameGroup(editingGroup.id, name: name)
                        viewModel.setGroupPersistence(editingGroup.id, persistence)
                    } else {
                        viewModel.createGroup(name: name, persistence: persistence)
                    }
                    self.editingGroup = nil
                }
            }
            .alert(
                "Delete Group?",
                isPresented: $showDeleteConfirm,
                presenting: groupPendingDeletion
            ) { group in
                Button("Delete", role: .destructive) {
                    viewModel.deleteGroup(group.id, closeContainedTabs: true)
                    groupPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    groupPendingDeletion = nil
                }
            } message: { group in
                Text("\"\(group.name)\" and its \(group.tabCount) tab\(group.tabCount == 1 ? "" : "s") will be permanently closed.")
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for group: TabGroup) -> some View {
        HStack(spacing: 12) {
            Image(systemName: group.isTemporary ? "clock.arrow.circlepath" : "folder")
                .foregroundStyle(group.isTemporary ? .secondary : .primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.body)

                Text("\(group.tabCount) tab\(group.tabCount == 1 ? "" : "s") · \(group.persistence.displayName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if group.id == viewModel.selctedTabGroup.id {
                Image(systemName: "checkmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectGroup(group)
        }
        .contextMenu {
            Button {
                editingGroup = group
                showEditor = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                viewModel.toggleGroupPersistence(group.id)
            } label: {
                if group.isPersistent {
                    Label("Make Temporary", systemImage: "clock.arrow.circlepath")
                } else {
                    Label("Make Persistent", systemImage: "externaldrive.fill")
                }
            }

            Divider()

            Button(role: .destructive) {
                groupPendingDeletion = group
                showDeleteConfirm = true
            } label: {
                Label("Delete Group", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                groupPendingDeletion = group
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                editingGroup = group
                showEditor = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    // MARK: - Reorder

    private func moveGroups(from source: IndexSet, to destination: Int) {
        viewModel.tabGroups.move(fromOffsets: source, toOffset: destination)
        viewModel.persistGroupsOrdering()   // see VM method below
    }
}

#endif

