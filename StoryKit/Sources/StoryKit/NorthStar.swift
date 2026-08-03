import Foundation

/// The project's North Star: one freeform text document capturing the story's
/// guiding essence — arc, characters, theme. It is shared project context, fed
/// to every reviewer (each weighs it by its own lights). The author imports it
/// from their own file and versions it there; the app persists it verbatim and
/// never edits it (re-import replaces it). First of an eventual family of
/// supporting docs (world setting, character arc, …) — kept a dedicated type
/// until a second doc justifies generalizing.
public struct NorthStar: Equatable, Sendable, Codable {
    /// The document text, stored exactly as imported.
    public var text: String
    /// The name of the file it was imported from, for display ("Loaded from …").
    public var sourceFilename: String?
    /// When it was imported (or last re-imported).
    public var importedAt: Date

    public init(text: String, sourceFilename: String? = nil, importedAt: Date = Date()) {
        self.text = text
        self.sourceFilename = sourceFilename
        self.importedAt = importedAt
    }
}
