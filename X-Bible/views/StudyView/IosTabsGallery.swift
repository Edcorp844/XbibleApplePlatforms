//
//  IosTabsGallery.swift
//  X-Bible
//

import SwiftUI
import XbibleEngine

#if os(iOS)
struct TabsGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: StudyViewModel

    /// Called after the user selects a tab, before dismissal. Lets the
    /// caller trigger any load work that shouldn't happen inside the
    /// gallery itself.
    var onSelect: () -> Void

    @State private var showManageGroups = false

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    /// Single source of truth: the view model. No bindings, no
    /// snapshots. Every mutation on the VM publishes through
    /// `@EnvironmentObject` and re-renders this view — even when the
    /// gallery is presented as a sheet.
    private var visibleTabs: [TabInstance] { viewModel.visibleTabs }
    private var selectedTabId: UUID? { viewModel.selectedTabId }

    var body: some View {
        NavigationStack {
            ScrollView {
                if visibleTabs.isEmpty {
                    emptyGroupState
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(visibleTabs) { tab in
                            TabCardView(
                                tab: tab,
                                isSelected: selectedTabId == tab.id,
                                onClose: { viewModel.closeTab(id: tab.id) }
                            )
                            .onTapGesture {
                                viewModel.selectTab(id: tab.id)
                                onSelect()
                                dismiss()
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(viewModel.selctedTabGroup.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { topToolbar }
            .toolbar { bottomToolbar }
            .sheet(isPresented: $showManageGroups) {
                ManageTabGroupsView()
                    .environmentObject(viewModel)
            }
        }
    }

    // MARK: - Top toolbar

    @ToolbarContentBuilder
    private var topToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {} label: {
                Label("Search", systemImage: "magnifyingglass")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showManageGroups = true
                } label: {
                    Label("Manage Tab Groups", systemImage: "list.bullet")
                }
                Button {} label: {
                    Label("Select Tabs", systemImage: "checkmark.circle")
                }
            } label: {
                Label("Menu", systemImage: "ellipsis")
            }
        }
    }

    // MARK: - Bottom toolbar

    @ToolbarContentBuilder
    private var bottomToolbar: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            NewTabMenu()
        }

        ToolbarSpacer(.flexible, placement: .bottomBar)

        ToolbarItem(placement: .bottomBar) {
            groupSwitcher
        }

        ToolbarSpacer(.flexible, placement: .bottomBar)

        ToolbarItem(placement: .bottomBar) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .controlSize(.large)
        }
    }

    // MARK: - Group switcher

    private var groupSwitcher: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(viewModel.tabGroups) { group in
                        let isSelected = group.id == viewModel.selctedTabGroup.id

                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                viewModel.selectGroup(group)
                            }
                        } label: {
                            Text(group.name)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background {
                                    if isSelected {
                                        Capsule().fill(Color(uiColor: .secondarySystemBackground))
                                    }
                                }
                                .foregroundStyle(.primary)
                                .contentShape(Capsule())
                                .id(group.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
            }
            .background {
                Capsule().fill(Color.primary.opacity(0.06))
            }
            .clipShape(Capsule())
            .frame(maxWidth: 260)
            .onChange(of: viewModel.selctedTabGroup.id) { _, newId in
                withAnimation(.snappy) {
                    proxy.scrollTo(newId, anchor: .center)
                }
            }
        }
    }
    // MARK: - Empty state

    private var emptyGroupState: some View {
        ContentUnavailableView(
            "No Tabs in \(viewModel.selctedTabGroup.name)",
            systemImage: "square.on.square.dashed",
            description: Text("Tap + to add a tab to this group.")
        )
        .padding(.top, 80)
    }
}

// MARK: - Tab Card

private struct TabCardView: View {
    let tab: TabInstance
    let isSelected: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tab.selectedModule.isEmpty ? "—" : tab.selectedModule)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text(tab.selectedBook.isEmpty
                 ? "Empty Tab"
                 : "\(tab.selectedBook) \(tab.selectedChapter)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(previewText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(12)
        .frame(height: 140)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
        )
        .contentShape(Rectangle())
    }

    private var previewText: String {
        guard let firstSection = tab.sections.first,
              let firstVerse = firstSection.verses.first,
              !firstVerse.words.isEmpty else {
            return "Empty content layout"
        }
        return firstVerse.words.map { $0.text }.joined(separator: " ")
    }
}
#endif
