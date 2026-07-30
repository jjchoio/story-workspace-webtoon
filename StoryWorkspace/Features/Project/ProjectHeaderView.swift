//
//  ProjectHeaderView.swift
//  StoryWorkspace
//
//  Fixed title bar below the toolbar: document name · version, and import date.
//

import SwiftUI

struct ProjectHeaderView: View {
    let documentName: String
    let version: Int
    let importedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(documentName)
                    .font(.title.weight(.semibold))
                Text("v\(version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Imported on \(importedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(.bar)
    }
}
