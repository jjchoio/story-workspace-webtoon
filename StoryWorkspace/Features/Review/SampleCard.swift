//
//  SampleCard.swift
//  StoryWorkspace
//
//  TEMP (Phase 2 step 5 demo): loads the bundled sample-card.json so the card
//  renderer can be viewed before the review flow exists. Remove this and the
//  bundled JSON when step 6 wires real reviewer output.
//

import Foundation
import StoryKit

enum SampleCard {
    static func load() -> Card? {
        guard
            let url = Bundle.main.url(forResource: "sample-card", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(Card.self, from: data)
    }
}
