//
//  FallbackBadge.swift
//  XBible
//
//  Created by Zoe Brooklyn on 6/8/26.
//
import SwiftUI
import XbibleEngine

struct FallbackBadge: View {
    let module: AudioModuleInfo

    var body: some View {
        Text((module.metadata?.displayTitle ?? "M").prefix(1).uppercased())
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.6))
            .frame(width: 36, height: 36)
            .background(Color.white.opacity(0.08))
            .cornerRadius(6)
    }
}
