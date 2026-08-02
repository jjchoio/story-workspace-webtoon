//
//  StoryWorkspaceApp.swift
//  StoryWorkspace
//
//  Created by Joshua Choi on 7/27/26.
//

import SwiftUI

@main
struct StoryWorkspaceApp: App {
    // Owned here so both the reader window and the floating review-card window
    // read the same project state (Observation environment injection).
    @State private var model = ProjectViewModel()
    // TEMP visual sandbox for the card look; drop with CardStyle.swift.
    @State private var cardStyle = CardStyleSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(cardStyle)
        }

        // The review card lives in its own movable window (dragged by its title
        // bar, placed beside the reader). Opened via openWindow(id:) from the
        // toolbar.
        Window("Review", id: "review-card") {
            ReviewWindow()
                .environment(model)
                .environment(cardStyle)
        }
        // Fits one full card (460×520) plus a peek of the neighbors and the
        // controls ~100px below; user-resizable.
        .defaultSize(width: 720, height: 720)
        .defaultPosition(.trailing)
        // Don't let the aux windows restore on launch — otherwise macOS can
        // relaunch into just this window with no main project window.
        .restorationBehavior(.disabled)

        // TEMP: debug switches to A/B the card's visual treatment.
        Window("Card Style", id: "card-style-debug") {
            CardStyleDebugView()
                .environment(cardStyle)
        }
        .defaultSize(width: 360, height: 200)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
    }
}
