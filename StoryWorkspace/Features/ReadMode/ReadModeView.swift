//
//  ReadModeView.swift
//  StoryWorkspace
//
//  Reading pane: episode header, optional warnings, then a pinned-header section
//  per cut. Anchors let the sidebar jump here; top-offset + bottom preferences
//  report the current cut back so the sidebar can highlight it while scrolling.
//

import SwiftUI
import StoryKit

struct ReadModeView: View {
    let episode: Episode
    let warnings: [ParseWarning]
    let changedLineIDs: Set<LineID>
    @Binding var selection: ReaderTarget?

    /// One scroll-sync update we triggered ourselves, so the jump handler
    /// ignores it instead of re-scrolling.
    @State private var syncing = false
    /// True while a sidebar-initiated jump animates, so cuts scrolled past (or
    /// the origin cut) don't flicker the sidebar highlight.
    @State private var jumping = false
    /// Identifies the latest jump so an earlier jump's guard-release can't clear
    /// `jumping` out from under a newer one.
    @State private var jumpToken = 0

    @State private var cutTops: [Int: CGFloat] = [:]
    @State private var contentBottom: CGFloat = .greatestFiniteMagnitude

    private let space = "reader"
    private let topThreshold: CGFloat = 72 // clears the pinned header

    var body: some View {
        GeometryReader { outer in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        episodeHeader
                            .id(ReaderTarget.goal)
                            .padding(.horizontal, 28)
                            .padding(.top, 22)
                            .padding(.bottom, 8)

                        if !warnings.isEmpty {
                            WarningsBanner(warnings: warnings)
                                .padding(.horizontal, 28)
                                .padding(.bottom, 8)
                        }

                        ForEach(Array(episode.cuts.enumerated()), id: \.offset) { entry in
                            Section {
                                CutSectionView(cut: entry.element, changedLineIDs: changedLineIDs)
                            } header: {
                                CutHeaderView(number: entry.offset + 1, title: entry.element.title)
                                    .background(topReporter(index: entry.offset))
                            }
                            .id(ReaderTarget.cut(entry.offset))
                        }

                        Color.clear
                            .frame(height: 24)
                            .background(bottomReporter)
                    }
                }
                .coordinateSpace(name: space)
                .onChange(of: selection) { _, target in
                    if syncing { syncing = false; return }
                    guard let target else { return }
                    jumping = true
                    jumpToken &+= 1
                    let token = jumpToken
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.4))
                        if token == jumpToken { jumping = false }
                    }
                }
                .onPreferenceChange(CutTopPreferenceKey.self) { tops in
                    cutTops = tops
                    updateCurrentCut(viewportHeight: outer.size.height)
                }
                .onPreferenceChange(BottomPreferenceKey.self) { bottom in
                    contentBottom = bottom
                    updateCurrentCut(viewportHeight: outer.size.height)
                }
            }
        }
    }

    // MARK: Episode header

    private var episodeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let goal = episode.goal {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "target").foregroundStyle(.tint)
                    Text(goal).font(.title3.weight(.semibold))
                }
            }
            Text("\(episode.cuts.count) cuts · \(episode.lineCount) lines")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Current-cut sync

    private func topReporter(index: Int) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: CutTopPreferenceKey.self,
                value: [index: geo.frame(in: .named(space)).minY]
            )
        }
    }

    private var bottomReporter: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: BottomPreferenceKey.self,
                value: geo.frame(in: .named(space)).maxY
            )
        }
    }

    /// Highlight the cut at the top; but once scrolled to the end (past the
    /// first cut), highlight the last cut — so jumping to a final cut that can't
    /// reach the very top still lands on it.
    private func updateCurrentCut(viewportHeight: CGFloat) {
        guard !jumping, !cutTops.isEmpty, viewportHeight > 0 else { return }

        let scrolledPastFirst = (cutTops[0] ?? .greatestFiniteMagnitude) < topThreshold
        let atBottom = contentBottom <= viewportHeight + 1

        let target: ReaderTarget
        if atBottom && scrolledPastFirst {
            target = .cut(episode.cuts.count - 1)
        } else if let top = cutTops
            .filter({ $0.value <= topThreshold })
            .max(by: { $0.key < $1.key })?
            .key {
            target = .cut(top)
        } else {
            target = .goal
        }

        guard selection != target else { return }
        syncing = true
        selection = target
    }
}

private struct CutTopPreferenceKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct BottomPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}
