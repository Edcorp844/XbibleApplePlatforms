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
                .font(.system(size: isSide ? 30 : 11, weight: .semibold))
                .frame(width: 30, height: 60)
                .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThickMaterial))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                .opacity(isDisabled ? 0.2 : 0.8)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}


struct NavigationRectButton_Previews: PreviewProvider {
    static var previews: some View {
        NavigationRectButton(icon: "chevron.compact.left", action: {}, isDisabled: false, isSide: true)
    }
}
