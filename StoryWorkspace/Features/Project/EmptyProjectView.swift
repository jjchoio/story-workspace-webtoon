//
//  EmptyProjectView.swift
//  StoryWorkspace
//
//  First-launch empty state: prompt to import an episode.
//

import SwiftUI

struct EmptyProjectView: View {
    let onImport: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No episode yet", systemImage: "tray")
        } description: {
            Text("Import a script (.txt) in either the Scroll Block or Cut convention.")
        } actions: {
            Button("Import Episode…", action: onImport)
                .buttonStyle(.borderedProminent)
        }
    }
}
