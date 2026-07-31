//
//  WindowFocusResetter.swift
//  StoryWorkspace
//
//  Suppresses the stray focus ring a toolbar button grabs when the window
//  regains focus. Attach via `.background(WindowFocusResetter())`.
//
//  Why this shape (learned the hard way):
//  - The trigger is the WINDOW becoming key — NOT the app becoming active. The
//    app-level `didBecomeActive` notification does not fire when switching
//    between windows of the same app, so listening there missed that case.
//    `NSWindow.didBecomeKeyNotification` covers both app-return and same-app
//    window switches.
//  - AppKit assigns the first responder as part of becoming key, so the reset
//    must run on the NEXT runloop tick to land after it.
//  - `.focusEffectDisabled()` / `.focusable(false)` are unreliable for toolbar
//    buttons, so we clear the responder at the AppKit level instead.
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
                forName: NSWindow.didBecomeKeyNotification,
                object: nil,
                queue: .main
            ) { [weak view] note in
                guard let window = view?.window,
                      note.object as? NSWindow === window else { return }
                // Run after AppKit sets the first responder for the key window.
                DispatchQueue.main.async { window.makeFirstResponder(nil) }
            }
        }

        deinit {
            if let token { NotificationCenter.default.removeObserver(token) }
        }
    }
}
