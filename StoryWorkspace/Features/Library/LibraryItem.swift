//
//  LibraryItem.swift
//  StoryWorkspace
//
//  What the left-column library selection points at: the project's North Star
//  (shared supporting doc) or one episode. Drives the outline and reading panes.
//

import StoryKit

enum LibraryItem: Hashable {
    case northStar
    case episode(DocumentID)
}
