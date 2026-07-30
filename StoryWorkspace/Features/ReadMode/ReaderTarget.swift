//
//  ReaderTarget.swift
//  StoryWorkspace
//
//  A navigation / scroll target within the episode reader: the goal anchor or a
//  specific cut. Shared by the sidebar outline and the reading pane.
//

import Foundation

enum ReaderTarget: Hashable {
    case goal
    case cut(Int)
}
