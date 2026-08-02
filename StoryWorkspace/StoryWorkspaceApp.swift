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
        // Squarish: fits ~2 columns of the Grid deck; also fits one carousel
        // card + peek. User-resizable.
        .defaultSize(width: 1000, height: 820)
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
