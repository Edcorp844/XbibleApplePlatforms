//
//  NewTabMenu.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/29/26.
//

import SwiftUI

struct NewTabMenu: View {
    @EnvironmentObject private var viewModel: StudyViewModel
    
    var body: some View {
        Menu {
            ForEach(TabType.allCases) { type in
                Button {
                    viewModel.createNewTab(ofType: type)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(type.displayName)
                            Text(type.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: type.icon)
                    }
                }
            }
        } label: {
            Label("New", systemImage: "plus")
            .font(.system(size: 25, weight: .regular))        }
    }
}
