import Foundation

// The set of reviewers that ship with the app (D8: reviewers are product
// features the author selects per cycle). The future reviewer-selection UI reads
// this. Adding a reviewer is two edits: a new Reviewers/<Name>Reviewer.swift
// (+ its Prompts/<Name>.md) and one entry here.

public extension ReviewerConfig {
    static let all: [ReviewerConfig] = [
        .dialogue,
    ]
}
