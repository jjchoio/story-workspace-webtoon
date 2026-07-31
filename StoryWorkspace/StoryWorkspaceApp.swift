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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }

        // The review card lives in its own movable window (dragged by its title
        // bar, placed beside the reader). Opened via openWindow(id:) from the
        // toolbar. TEMP demo trigger until the real review flow lands.
        Window("Review", id: "review-card") {
            ReviewWindow()
                .environment(model)
        }
        .defaultSize(width: 500, height: 560)
        .defaultPosition(.trailing)
        .windowResizability(.contentSize)
    }
}
