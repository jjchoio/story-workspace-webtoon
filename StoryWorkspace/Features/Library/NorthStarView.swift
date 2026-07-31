//
//  NorthStarView.swift
//  StoryWorkspace
//
//  Reading pane for the project's North Star: the imported text, read-only
//  (the author edits it in their own tool and re-imports). Shown in the detail
//  column when the North Star is selected in the library.
//

import SwiftUI
import StoryKit

struct NorthStarView: View {
    let northStar: NorthStar?

    var body: some View {
        if let northStar {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(northStar)
                    Divider()
                    Text(northStar.text)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(28)
            }
        } else {
            ContentUnavailableView {
                Label("No North Star", systemImage: "star")
            } description: {
                Text("Drag a .txt onto the library — or use + — and choose “North Star”.")
            }
        }
    }

    private func header(_ northStar: NorthStar) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "star.fill").foregroundStyle(.tint)
                Text("North Star").font(.title2.weight(.semibold))
            }
            Text("Loaded from \(northStar.sourceFilename ?? "a file") · \(northStar.importedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
