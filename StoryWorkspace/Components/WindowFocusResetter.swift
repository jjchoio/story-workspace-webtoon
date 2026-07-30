//
//  WindowFocusResetter.swift
//  StoryWorkspace
//
//  Clears the window's first responder whenever the app reactivates, so a
//  toolbar button doesn't grab a stray focus ring after the user returns from
//  Finder or another app. Attach via `.background(WindowFocusResetter())`.
//

import SwiftUI
import AppKit

struct WindowFocusResetter: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.observe(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var token: NSObjectProtocol?

        func observe(_ view: NSView) {
            token = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil, queue: .main
            ) { [weak view] _ in
                view?.window?.makeFirstResponder(nil)
            }
        }

        deinit {
            if let token { NotificationCenter.default.removeObserver(token) }
        }
    }
}
