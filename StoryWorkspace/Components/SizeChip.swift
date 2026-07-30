//
//  SizeChip.swift
//  StoryWorkspace
//
//  Color-coded S/M/L panel-size chip. Reserves a fixed slot so lines with no
//  size stay aligned with sized ones.
//

import SwiftUI
import StoryKit

struct SizeChip: View {
    let size: SizeCode?

    var body: some View {
        ZStack {
            if let size {
                Text(size.rawValue)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color(size))
                    .frame(width: 20, height: 18)
                    .background(color(size).opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
            }
        }
        .frame(width: 20, height: 18)
    }

    private func color(_ size: SizeCode) -> Color {
        switch size {
        case .s: return .blue
        case .m: return .orange
        case .l: return .purple
        }
    }
}
