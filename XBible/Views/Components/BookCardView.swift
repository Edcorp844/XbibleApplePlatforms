//
//  BookCardView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/23/26.
//

import SwiftUI
import XbibleEngine

struct BookCardView: View {
    let module: XbibleEngine.SwordModule
    let status: InstallationStatus
    let showActionButton : Bool
    let action: () -> Void
    let categoryName: String?
    let menuAction: (() -> Void)?
    
    init(module: XbibleEngine.SwordModule, status: InstallationStatus, showActionButton: Bool, action: @escaping () -> Void, categoryName: String? = nil, menuAction: (() -> Void)? = nil) {
        self.module = module
        self.status = status
        self.action = action
        self.categoryName = categoryName
        self.menuAction = menuAction
        self.showActionButton = showActionButton
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Physical Book Cover
            BookView(module: module)
            
            // Bottom Info Bar
            HStack(spacing: 8) {
                VStack(alignment: .leading) {
                    Text(module.name)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    Text(categoryName ?? module.description)
                        .lineLimit(1)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Menu button for library items
                if status == .installed, let menuAction = menuAction {
                    Menu {
                        Button(action: menuAction) {
                            Label("Update", systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive, action: {
                            // TODO: Implement delete
                            print("Delete \(module.name)")
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .menuIndicator(.hidden)
                }
                
                // Action UI based on status
                if showActionButton{
                    actionView
                }
            }
            .frame(width: 150)
            .offset(y: 4)
        }
    }
    
    @ViewBuilder
    private var actionView: some View {
        switch status {
        case .idle:
            Button(action: action) {
                Text("Get")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .overlay(Capsule().stroke(Color.accentColor, lineWidth: 1.2))
            
        case .installed:
            Button(action: action) {
                Text("Open")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .overlay(Capsule().stroke(.secondary.opacity(0.5), lineWidth: 1.2))
            
        case .pending:
            Button(action: action) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                    
                    Image(systemName: "pause.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            
        case .installing(let details):
            Button(action: action) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: CGFloat(details.progress))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(details.progress * 100))")
                        .font(.system(size: 8, weight: .bold))
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            
        case .cancelled:
            Button(action: action) {
                Text("Cancelled")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .overlay(Capsule().stroke(Color.accentColor, lineWidth: 1.2))
        }
    }
}
