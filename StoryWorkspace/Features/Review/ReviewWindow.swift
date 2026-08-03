//
//  ReviewWindow.swift
//  StoryWorkspace
//
//  Content of the floating "Review" window (StoryWorkspaceApp scene). It reads
//  the shared project model and, when an episode is loaded, runs a live review
//  via ReviewCardPreview. Movable/resizable/closable as a normal macOS window.
//

import SwiftUI
import StoryKit

struct ReviewWindow: View {
    @Environment(ProjectViewModel.self) private var model

    var body: some View {
        Group {
            if case .loaded(let loaded) = model.state {
                ReviewCardPreview(episode: loaded.episode)
            } else {
                Text("Open a project first, then run a review.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
