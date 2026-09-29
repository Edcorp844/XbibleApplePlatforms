//
//  PlatformPasteboard.swift
//  XBible
//
//  Created by Zoe Brooklyn on 6/8/26.
//


import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct PlatformPasteboard {
    static func copy(_ text: String) {
        #if os(macOS)
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #else
        
        let pasteboard = UIPasteboard.general
        pasteboard.string = text
        #endif
    }
}
