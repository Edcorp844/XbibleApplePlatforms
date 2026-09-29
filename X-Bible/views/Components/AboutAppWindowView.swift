//
//  AboutAppWindowView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 6/10/26.
//

import SwiftUI

struct AboutAppWindowView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            
            // --- LEFT COLUMN: APP ICON ---
            VStack {
                #if os(macOS)
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                #else
                // Fallback icon for iOS or other view context previews
                Image(systemName: "book.circle.fill")
                    .resizable()
                    .frame(width: 64, height: 64) // Explicit sizing applied immediately to prevent blowout
                    .foregroundStyle(Color.accentColor)
                #endif
                Spacer()
            }
            .frame(width: 64, height: 64) // Restrains the bounding container completely
            
            // --- RIGHT COLUMN: BRANDING & METADATA ---
            VStack(alignment: .leading, spacing: 0) {
                
                // Header Group
                Text("XBible")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Version 1.0.0 (Build 2026)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                
                // Pitch/Description Paragraph
                Text("A high-performance scripture study suite powered by the crosswire SWORD engine and native Swift architecture. Built for deep textual analysis and split-pane structural reading workflows.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                
                // Acknowledgments Block
                VStack(alignment: .leading, spacing: 4) {
                    Text("Credits & Open Source:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("• Crosswire SWORD Project Engine (GPLv2)")
                    Text("• XBible Engine")
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.top, 14)
                
                Spacer(minLength: 16)
                
                // --- FOOTER: LEGAL COPYRIGHTS ---
                VStack(alignment: .leading, spacing: 2) {
                    Text("Copyright © 2026 Frost Edson. All rights reserved.")
                    Text("Licensed under the MIT License. Terms apply.")
                }
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            }
        }
        .padding(24)
        #if os(macOS)
        .frame(width: 420, height: 230)
        #endif
    }
}
