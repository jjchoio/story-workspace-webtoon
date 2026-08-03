//
//  CardStatusBadge.swift
//  StoryWorkspace
//
//  At-a-glance lifecycle badge: "v{n} · {status}", colored per state (D12/D13).
//

import SwiftUI
import StoryKit

struct CardStatusBadge: View {
    let version: Int
    let status: CardStatus

    var body: some View {
        Text("v\(version) · \(status.rawValue)")
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
    }

    private var color: Color {
        switch status {
        case .open:       return .gray
        case .challenged: return .orange
        case .renewed:    return .blue
        case .accepted:   return .green
        case .dismissed:  return .gray
        case .stale:      return .yellow
        case .overruled:  return .red
        }
    }
}
