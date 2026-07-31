//
//  WindowFocusResetter.swift
//  StoryWorkspace
//
//  Suppresses the stray focus ring a button grabs when a window becomes key
//  (on launch, app re-activation, window switches, and sheet presentation).
//  Attach once via `.background(WindowFocusResetter())`.
//
//  There is no reliable SwiftUI API for this — `.focusEffectDisabled()` /
//  `.focusable(false)` don't hold for toolbar buttons (confirmed on the Apple
//  forums). So we go to AppKit. On ANY window becoming key we:
//    1. recursively set `focusRingType = .none` on its NSControls, and
//    2. clear the first responder,
//  on the next runloop tick (after AppKit assigns focus). Listening globally
//  (object: nil) covers sheets and same-app window switches too — cases the
//  app-level `didBecomeActive` notification missed.
//

import SwiftUI
import AppKit

struct WindowFocusResetter: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        context.coordinator.start()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var token: NSObjectProtocol?

        func start() {
            token = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil,
                queue: .main
            ) { note in
                guard let window = note.object as? NSWindow else { return }
                DispatchQueue.main.async {
                    disableFocusRings(in: window.contentView?.superview ?? window.contentView)
                    window.makeFirstResponder(nil)
                }
            }
        }

        deinit {
            if let token { NotificationCenter.default.removeObserver(token) }
        }
    }
}

private func disableFocusRings(in view: NSView?) {
    guard let view else { return }
    (view as? NSControl)?.focusRingType = .none
    for subview in view.subviews {
        disableFocusRings(in: subview)
    }
}
