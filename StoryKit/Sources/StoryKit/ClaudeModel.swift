import Foundation
import os

// The Claude adapter: the ONE place that knows Anthropic's wire format. Swift
// has no official Anthropic SDK, so this talks raw HTTPS to the Messages API
// (POST /v1/messages). Everything above it sees only the neutral LanguageModel
// interface, so a Gemini or GPT adapter would slot in beside this file with no
// change to the reviewer layer.
//
// The request body is intentionally minimal (model, max_tokens, system,
// messages). Effort / thinking tuning is deferred — on the default model,
// thinking is on and its blocks carry empty text, so `send` simply keeps the
// text blocks and ignores the rest.

public struct ClaudeModel: LanguageModel {
    /// The Anthropic model id. Defaults to the current Opus.
    public var model: String
    private let apiKey: String
    private let urlSession: URLSession

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2023-06-01"
    private static let log = Logger(subsystem: "StoryWorkspace.AI", category: "ClaudeModel")

    public init(apiKey: String, model: String = "claude-opus-5", urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.urlSession = urlSession
    }

    /// Build a client from `ANTHROPIC_API_KEY` in the environment (dev spike;
    /// not a shippable credential path). Throws `.missingAPIKey` if unset/blank.
    public static func fromEnvironment(model: String = "claude-opus-5") throws -> ClaudeModel {
        let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key, !key.isEmpty else {
            log.error("ANTHROPIC_API_KEY is not set")
            throw ModelError.missingAPIKey
        }
        return ClaudeModel(apiKey: key, model: model)
    }

    public func send(_ request: ModelRequest) async throws -> ModelResponse {
        let body = RequestBody(
            model: model,
            max_tokens: request.maxTokens,
            system: request.system,
            messages: request.messages.map { .init(role: $0.role.rawValue, content: $0.text) }
        )
        var urlRequest = URLRequest(url: Self.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        Self.log.info(
            "POST \(Self.endpoint.absoluteString, privacy: .public) model=\(model, privacy: .public) bytes=\(urlRequest.httpBody?.count ?? 0, privacy: .public)"
        )

        let (data, response) = try await urlSession.data(for: urlRequest)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        Self.log.info("response status=\(status, privacy: .public) bytes=\(data.count, privacy: .public)")

        guard (200..<300).contains(status) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            Self.log.error("HTTP \(status, privacy: .public): \(bodyText, privacy: .public)")
            throw ModelError.http(status: status, body: bodyText)
        }

        guard let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data) else {
            Self.log.error("could not decode Messages response")
            throw ModelError.malformedResponse
        }
        // Keep only text blocks (thinking blocks arrive with empty text).
        let text = decoded.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()
        return ModelResponse(text: text)
    }

    // MARK: Anthropic wire shapes (private to this adapter)

    private struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String?
        let messages: [Message]

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    private struct ResponseBody: Decodable {
        let content: [Block]

        struct Block: Decodable {
            let type: String
            let text: String?
        }
    }
}
