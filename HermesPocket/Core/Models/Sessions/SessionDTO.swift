import Foundation

struct SessionsListDTO: Decodable, Equatable {
    let sessions: [SessionSummaryDTO]

    private enum CodingKeys: String, CodingKey {
        case sessions
    }

    init(sessions: [SessionSummaryDTO]) {
        self.sessions = sessions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var results: [SessionSummaryDTO] = []

        if var sessionsContainer = try? container.nestedUnkeyedContainer(forKey: .sessions) {
            while !sessionsContainer.isAtEnd {
                if let session = try? sessionsContainer.decode(SessionSummaryDTO.self) {
                    results.append(session)
                } else {
                    _ = try? sessionsContainer.decode(JSONValue.self)
                }
            }
        }

        sessions = results
    }
}

struct SessionSummaryDTO: Decodable, Equatable, Identifiable {
    let sessionId: String
    let title: String
    let messageCount: Int
    let updatedAt: Double?
    let lastMessageAt: Double?
    let model: String?
    let profile: String?
    let activeStreamId: String?

    var id: String { sessionId }

    init(
        sessionId: String,
        title: String,
        messageCount: Int,
        updatedAt: Double?,
        lastMessageAt: Double?,
        model: String?,
        profile: String?,
        activeStreamId: String?
    ) {
        self.sessionId = sessionId
        self.title = title
        self.messageCount = messageCount
        self.updatedAt = updatedAt
        self.lastMessageAt = lastMessageAt
        self.model = model
        self.profile = profile
        self.activeStreamId = activeStreamId
    }
}

struct SessionEnvelopeDTO: Decodable, Equatable {
    let session: SessionDTO
}

struct SessionMutationResponseDTO: Decodable, Equatable {
    let ok: Bool?
    let session: SessionDTO?
}

struct SessionDeleteResponseDTO: Decodable, Equatable {
    let ok: Bool?
}

struct SessionActionRequestDTO: Encodable {
    let sessionID: String
}

struct SessionRenameRequestDTO: Encodable {
    let sessionID: String
    let title: String
}

struct SessionToolCallDTO: Decodable, Equatable {
    let name: String?
    let preview: String?
    let args: [String: String]?
    let isError: Bool?
    let status: String?
}

struct SessionDTO: Decodable, Equatable {
    let sessionId: String
    let title: String
    let messages: [MessageDTO]
    let messageCount: Int
    let activeStreamId: String?
    let pendingUserMessage: String?
    let pendingStartedAt: Double?
    let updatedAt: Double?
    let lastMessageAt: Double?
    let model: String?
    let profile: String?
    let toolCalls: [SessionToolCallDTO]?

    static let empty = SessionDTO(
        sessionId: "",
        title: "",
        messages: [],
        messageCount: 0,
        activeStreamId: nil,
        pendingUserMessage: nil,
        pendingStartedAt: nil,
        updatedAt: nil,
        lastMessageAt: nil,
        model: nil,
        profile: nil,
        toolCalls: nil
    )
}

struct MessageDTO: Decodable, Equatable, Identifiable {
    let id: UUID
    let role: String
    let content: MessageContentDTO
    let timestamp: Double?
    let attachments: [AttachmentDTO]

    var displayText: String {
        switch content {
        case .text(let text):
            return Self.stripThinkingContent(text)
        case .unsupported:
            return "Unsupported message payload"
        }
    }

    /// Strips chain-of-thought / reasoning tags that some models (e.g. DeepSeek, Qwen)
    /// embed in the output.
    private static func stripThinkingContent(_ text: String) -> String {
        var result = text

        let thinkingPatterns = [
            "(?i)<thinking>[\\s\\S]*?</thinking>",
            "(?i)<think>[\\s\\S]*?</think>",
            "(?i)\\[thinking\\][\\s\\S]*?\\[/thinking\\]",
            "(?i)<scratchpad>[\\s\\S]*?</scratchpad>",
            "(?i)<reasoning>[\\s\\S]*?</reasoning>",
            "(?i)<analysis>[\\s\\S]*?</analysis>",
            "(?i)<reflection>[\\s\\S]*?</reflection>",
            // Catch unclosed thinking tags (e.g., if stream ended mid-thinking)
            "(?i)<thinking>[\\s\\S]*$",
            "(?i)<think>[\\s\\S]*$"
        ]

        for pattern in thinkingPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsRange = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: nsRange, withTemplate: "")
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey {
        case role, content, timestamp
    }

    init(id: UUID = UUID(), role: String, content: MessageContentDTO, timestamp: Double?, attachments: [AttachmentDTO] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.attachments = attachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? "assistant"
        content = try container.decodeIfPresent(MessageContentDTO.self, forKey: .content) ?? .text("")
        timestamp = try container.decodeIfPresent(Double.self, forKey: .timestamp)
        attachments = []
    }
}

enum MessageContentDTO: Decodable, Equatable {
    case text(String)
    case unsupported

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer() {
            if let text = try? container.decode(String.self) {
                self = .text(text)
                return
            }
            if let boolValue = try? container.decode(Bool.self) {
                self = .text(boolValue ? "true" : "false")
                return
            }
            if let intValue = try? container.decode(Int.self) {
                self = .text(String(intValue))
                return
            }
            if let doubleValue = try? container.decode(Double.self) {
                self = .text(String(doubleValue))
                return
            }
            if let dict = try? container.decode([String: String].self) {
                self = .text(dict["text"] ?? dict["content"] ?? dict["output"] ?? dict.description)
                return
            }
            if let dict = try? container.decode([String: JSONValue].self) {
                let text = dict["text"]?.stringValue
                    ?? dict["content"]?.flattenedText
                    ?? dict["output"]?.flattenedText
                    ?? dict["message"]?.flattenedText
                if let text, !text.isEmpty {
                    self = .text(text)
                    return
                }
            }
            if let array = try? container.decode([JSONValue].self) {
                let text = array.map(\.flattenedText).filter { !$0.isEmpty }.joined(separator: "\n")
                self = text.isEmpty ? .unsupported : .text(text)
                return
            }
        }
        self = .unsupported
    }
}

private enum JSONValue: Decodable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var flattenedText: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object(let object):
            let preferred = ["text", "content", "output", "message", "input", "title"]
                .compactMap { object[$0]?.flattenedText }
                .filter { !$0.isEmpty }
            if !preferred.isEmpty {
                return preferred.joined(separator: "\n")
            }
            return object.values.map(\.flattenedText).filter { !$0.isEmpty }.joined(separator: "\n")
        case .array(let array):
            return array.map(\.flattenedText).filter { !$0.isEmpty }.joined(separator: "\n")
        case .null:
            return ""
        }
    }
}
