//
//  NavigationRectButton.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/23/26.
//

import SwiftUI

// MARK: - Navigation Button

struct NavigationRectButton: View {
    let icon: String
    let action: () -> Void
    let isDisabled: Bool
    var isSide: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: isSide ? 18 : 11, weight: .bold))
                .frame(width: 28, height: 36)
                .background(RoundedRectangle(cornerRadius: 20).fill(.thinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                .opacity(isDisabled ? 0.2 : 0.8)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
