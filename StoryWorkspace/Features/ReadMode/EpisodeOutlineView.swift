//
//  EpisodeOutlineView.swift
//  StoryWorkspace
//
//  Sidebar table of contents: Goal + each cut. Selection drives (and reflects)
//  the reading pane's scroll position.
//

import SwiftUI
import StoryKit

struct EpisodeOutlineView: View {
    let episode: Episode
    @Binding var selection: ReaderTarget?

    var body: some View {
        List(selection: $selection) {
            if episode.goal != nil {
                Label("Goal", systemImage: "target")
                    .tag(ReaderTarget.goal)
            }
            Section("Cuts") {
                ForEach(Array(episode.cuts.enumerated()), id: \.offset) { entry in
                    Text("Cut \(entry.offset + 1) · \(entry.element.title)")
                        .lineLimit(1)
                        .tag(ReaderTarget.cut(entry.offset))
                }
            }
        }
        .listStyle(.sidebar)
    }
}
