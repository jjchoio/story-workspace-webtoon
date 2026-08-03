import Foundation

// Provider-neutral model interface: the seam that lets the reviewer layer swap
// between Claude, Gemini, or GPT without knowing which is behind it. This is a
// deliberate abstraction (author's call) — the reviewer talks only to these
// text-in / text-out types; every vendor-specific detail (wire format, auth,
// thinking blocks) lives inside a concrete adapter such as ClaudeModel.
//
// v1 carries only what the instructed-JSON reasoner needs: a system prompt, a
// user/assistant message list, and a max-tokens cap. Streaming and structured
// (tool-use) output are deferred; adding them here later is additive.

/// One turn in a model request.
public struct ModelMessage: Equatable, Sendable {
    public enum Role: String, Sendable {
        case user, assistant
    }

    public var role: Role
    public var text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

/// A provider-neutral request. No vendor concepts (models, effort, thinking) —
/// those are the adapter's concern.
public struct ModelRequest: Equatable, Sendable {
    public var system: String?
    public var messages: [ModelMessage]
    public var maxTokens: Int

    public init(system: String? = nil, messages: [ModelMessage], maxTokens: Int) {
        self.system = system
        self.messages = messages
        self.maxTokens = maxTokens
    }
}

/// A provider-neutral response: the model's answer as plain text (all text
/// content concatenated; the adapter drops any non-text blocks).
public struct ModelResponse: Equatable, Sendable {
    public var text: String

    public init(text: String) {
        self.text = text
    }
}

/// Failures a language-model adapter can raise.
public enum ModelError: Error, Equatable {
    /// No credential was available (e.g. the API-key env var is unset).
    case missingAPIKey
    /// The provider returned a non-2xx status; `body` is the raw error payload.
    case http(status: Int, body: String)
    /// The response could not be decoded into a `ModelResponse`.
    case malformedResponse
}

/// The reason stage's provider seam. `ClaudeModel` implements it now; Gemini /
/// GPT adapters would be siblings. `async throws` so a real network call fits.
public protocol LanguageModel: Sendable {
    func send(_ request: ModelRequest) async throws -> ModelResponse
}
