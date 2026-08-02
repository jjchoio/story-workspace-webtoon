//
//  CardStyleDebugView.swift
//  StoryWorkspace
//
//  TEMP: content of the "Card Style" debug window — two segmented switches that
//  restyle the review card live. Delete with CardStyle.swift once the look is
//  settled.
//

import SwiftUI

struct CardStyleDebugView: View {
    @Environment(CardStyleSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Picker("Style", selection: $settings.style) {
                ForEach(CardAccentStyle.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Text("Colors are per-card (warm gradient) + green (accepted) / grey (declined). Open the Review window alongside this to compare.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 340)
    }
}
