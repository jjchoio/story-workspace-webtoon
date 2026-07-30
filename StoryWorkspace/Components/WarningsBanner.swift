//
//  WarningsBanner.swift
//  StoryWorkspace
//
//  Import-warning banner (numbering gaps, lost size markers, stray markup).
//

import SwiftUI
import StoryKit

struct WarningsBanner: View {
    let warnings: [ParseWarning]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(warnings.enumerated()), id: \.offset) { entry in
                Label(entry.element.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(.primary)
    }
}
