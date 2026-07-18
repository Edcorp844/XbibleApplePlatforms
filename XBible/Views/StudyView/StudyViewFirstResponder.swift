//
//  StudyViewFirstResponder.swift
//  XBible
//
//  Created by Zoe Brooklyn on 6/8/26.
//


import SwiftUI

#if os(macOS)
import AppKit

// MARK: - macOS Platform Implementation
struct StudyViewFirstResponder: NSViewRepresentable {
    @Binding var isFirstResponder: Bool

    func makeNSView(context: Context) -> FirstResponderNSView {
        FirstResponderNSView()
    }

    func updateNSView(_ nsView: FirstResponderNSView, context: Context) {
        if isFirstResponder, nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

class FirstResponderNSView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override var needsPanelToBecomeKey: Bool { true }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        self.window?.makeFirstResponder(self)
    }
}
#endif

#if os(iOS)
import UIKit

// MARK: - iOS Platform Implementation (iOS 26+)
struct StudyViewFirstResponder: UIViewRepresentable {
    @Binding var isFirstResponder: Bool

    func makeUIView(context: Context) -> FirstResponderUIView {
        FirstResponderUIView()
    }

    func updateUIView(_ uiView: FirstResponderUIView, context: Context) {
        DispatchQueue.main.async {
            if isFirstResponder {
                if !uiView.isFirstResponder {
                    uiView.becomeFirstResponder()
                }
            } else {
                if uiView.isFirstResponder {
                    uiView.resignFirstResponder()
                }
            }
        }
    }
}

class FirstResponderUIView: UIView {
    override var canBecomeFirstResponder: Bool { true }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        self.addGestureRecognizer(tapGesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func handleTap() {
        self.becomeFirstResponder()
    }
}
#endif
