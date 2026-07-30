//
//  CutHeaderView.swift
//  StoryWorkspace
//
//  Pinned section header for a cut: accent bar + "Cut N  Title" on the shared
//  bar material.
//

import SwiftUI

struct CutHeaderView: View {
    let number: Int
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: 4, height: 20)
            (Text("Cut \(number)").foregroundColor(.accentColor) + Text("  " + title))
                .font(.headline)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
