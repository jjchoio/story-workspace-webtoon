//
//  CardStyle.swift
//  StoryWorkspace
//
//  Card visual system. Style (outline default) is still tweakable from the debug
//  window while we iterate; colors are now decided by state and deck position:
//   • default  — a warm tone sampled left-to-right from a fixed gradient by the
//                card's index (card 0 is always the same, card 1 the next, …).
//   • accepted — warm green (shared by every card).
//   • declined — cold grey (shared).
//  Revert returns a card to its default (gradient) color.
//

import SwiftUI

enum CardAccentStyle: String, CaseIterable, Identifiable {
    case plain, outline, filled, solid
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// How the review deck presents itself — a focused single card with the
/// neighbors peeking. Selectable (like light/dark) so we can feel out the right
/// balance of "one thing at a time" vs. a physical stack.
enum DeckStyle: String, CaseIterable, Identifiable {
    case focused   // wide peek, neighbors are empty shells (no content)
    case physical  // neighbors blurred + 15% smaller, content visible
    case minimal   // tiny sliver, strong dim
    case simple    // plain scrollable strip — a big window shows every card

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    enum Layout { case carousel, strip }
    var layout: Layout { self == .simple ? .strip : .carousel }

    /// Points of each neighbor visible beside the centered card. (Clamped by the
    /// window width.) `focused` shows ~10% of the card's 460pt width.
    var peek: CGFloat {
        switch self { case .focused: 46; case .physical: 160; case .minimal: 16; case .simple: 0 }
    }
    var neighborOpacity: Double {
        switch self { case .minimal: 0.12; default: 1.0 }
    }
    var neighborScale: CGFloat {
        switch self { case .physical: 0.85; case .minimal: 0.82; case .focused, .simple: 1.0 }
    }
    var neighborBlur: CGFloat {
        switch self { case .physical: 5; default: 0 }
    }
    /// Focused shows neighbors as empty shells (frame only); the rest keep content.
    var neighborShowsContent: Bool { self != .focused }
}

/// The card color palette. `default` colors come from `gradient` (a warm
/// coffee→amber→red→brown family); state colors are shared across cards.
enum CardAccent {
    /// Warm family, ordered as a left-to-right sweep. Enough distinct stops for
    /// ~10 cards; beyond that we clamp to the last.
    static let gradient: [Color] = [
        Color(red: 0.80, green: 0.45, blue: 0.20), // coffee
        Color(red: 0.88, green: 0.55, blue: 0.22), // caramel
        Color(red: 0.92, green: 0.62, blue: 0.18), // amber
        Color(red: 0.90, green: 0.72, blue: 0.24), // gold
        Color(red: 0.92, green: 0.50, blue: 0.18), // pumpkin
        Color(red: 0.88, green: 0.40, blue: 0.20), // burnt orange
        Color(red: 0.80, green: 0.32, blue: 0.20), // terracotta
        Color(red: 0.72, green: 0.26, blue: 0.18), // brick red
        Color(red: 0.60, green: 0.34, blue: 0.18), // brown
        Color(red: 0.48, green: 0.28, blue: 0.16), // dark brown
    ]

    static let accepted = Color(red: 0.33, green: 0.62, blue: 0.42) // warm green
    static let declined = Color(red: 0.46, green: 0.47, blue: 0.50) // cold grey

    /// The default color for the card at `index`, clamped to the gradient.
    static func defaultColor(index: Int) -> Color {
        gradient[max(0, min(index, gradient.count - 1))]
    }
}

/// Shared across the review deck and the debug window so a style switch there
/// restyles the cards live. Color is no longer a toggle — see `CardAccent`.
@Observable
final class CardStyleSettings {
    var style: CardAccentStyle = .outline
    var deck: DeckStyle = .focused
}
