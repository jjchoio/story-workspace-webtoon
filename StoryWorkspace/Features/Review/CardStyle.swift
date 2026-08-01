//
//  CardStyle.swift
//  StoryWorkspace
//
//  TEMP visual sandbox: lets us A/B the review card's chrome (plain / orange
//  outline / orange fill) and accent color live from a debug window. Once we
//  settle on a look, delete this file, CardStyleDebugView, the "Card Style"
//  toolbar button + debug Window scene, and hardcode the winning treatment in
//  CardView.
//

import SwiftUI

enum CardAccentStyle: String, CaseIterable, Identifiable {
    case plain, outline, filled, solid
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum CardAccentColor: String, CaseIterable, Identifiable {
    case systemOrange = "System orange"
    case coffee = "Coffee"
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .systemOrange: return .orange
        case .coffee: return Color(red: 0.82, green: 0.47, blue: 0.20) // warm amber
        }
    }
}

/// Shared across the review card window and the debug window so a switch there
/// restyles the card live.
@Observable
final class CardStyleSettings {
    var style: CardAccentStyle = .plain
    var color: CardAccentColor = .systemOrange
}
