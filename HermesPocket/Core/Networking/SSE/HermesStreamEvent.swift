import Foundation

enum HermesStreamEvent: Equatable {
    case token(String)
    case reasoning(String)
    case toolStart(ToolEventDTO)
    case toolComplete(ToolEventDTO)
    case approval(ApprovalPendingDTO)
    case clarify(ClarifyPendingDTO)
    case title(TitleEventDTO)
    case contextStatus(ContextStatusDTO)
    case done(DoneEventDTO)
    case appError(AppErrorEventDTO)
    case cancel
    case streamEnd
    case unknown(name: String, payload: String)

    init(frame: HermesSSEFrame) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        switch frame.event {
        case "token":
            let payload = (try? decoder.decode(TokenEventDTO.self, from: Data(frame.data.utf8)))?.text ?? ""
            self = .token(payload)
        case "reasoning":
            let payload = (try? decoder.decode(TokenEventDTO.self, from: Data(frame.data.utf8)))?.text ?? ""
            self = .reasoning(payload)
        case "tool":
            self = .toolStart((try? decoder.decode(ToolEventDTO.self, from: Data(frame.data.utf8))) ?? ToolEventDTO(name: "tool", preview: nil, args: [:], isError: false))
        case "tool_complete":
            self = .toolComplete((try? decoder.decode(ToolEventDTO.self, from: Data(frame.data.utf8))) ?? ToolEventDTO(name: "tool", preview: nil, args: [:], isError: false))
        case "approval":
            self = .approval((try? decoder.decode(ApprovalPendingDTO.self, from: Data(frame.data.utf8))) ?? ApprovalPendingDTO(approvalId: nil, command: nil, description: nil, patternKey: nil, patternKeys: nil))
        case "clarify":
            self = .clarify((try? decoder.decode(ClarifyPendingDTO.self, from: Data(frame.data.utf8))) ?? ClarifyPendingDTO(clarifyId: nil, question: nil, description: nil, choicesOffered: nil, choices: nil))
        case "title":
            self = .title((try? decoder.decode(TitleEventDTO.self, from: Data(frame.data.utf8))) ?? TitleEventDTO(sessionId: nil, title: ""))
        case "context_status":
            self = .contextStatus((try? decoder.decode(ContextStatusDTO.self, from: Data(frame.data.utf8))) ?? ContextStatusDTO(sessionId: nil, prefill: nil))
        case "done":
            self = .done((try? decoder.decode(DoneEventDTO.self, from: Data(frame.data.utf8))) ?? DoneEventDTO(session: .empty, usage: nil))
        case "apperror":
            self = .appError((try? decoder.decode(AppErrorEventDTO.self, from: Data(frame.data.utf8))) ?? AppErrorEventDTO(label: nil, type: nil, message: nil, hint: nil))
        case "cancel":
            self = .cancel
        case "stream_end":
            self = .streamEnd
        default:
            self = .unknown(name: frame.event, payload: frame.data)
        }
    }
}

struct TokenEventDTO: Decodable, Equatable {
    let text: String
}

struct ToolEventDTO: Decodable, Equatable {
    let name: String
    let preview: String?
    let args: [String: String]
    let isError: Bool

    init(name: String, preview: String?, args: [String: String], isError: Bool) {
        self.name = name
        self.preview = preview
        self.args = args
        self.isError = isError
    }

    private enum CodingKeys: String, CodingKey {
        case name, preview, args
        case isError = "is_error"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        preview = try container.decodeIfPresent(String.self, forKey: .preview)
        args = try container.decodeIfPresent([String: String].self, forKey: .args) ?? [:]
        isError = try container.decodeIfPresent(Bool.self, forKey: .isError) ?? false
    }
}

struct TitleEventDTO: Decodable, Equatable {
    let sessionId: String?
    let title: String
}

struct ContextStatusDTO: Decodable, Equatable {
    let sessionId: String?
    let prefill: PrefillDTO?
}

struct PrefillDTO: Decodable, Equatable {
    let status: String?
    let label: String?
    let error: String?
}

struct DoneEventDTO: Decodable, Equatable {
    let session: SessionDTO
    let usage: UsageDTO?
}

struct AppErrorEventDTO: Decodable, Equatable {
    let label: String?
    let type: String?
    let message: String?
    let hint: String?
}

struct UsageDTO: Decodable, Equatable {
    let inputTokens: Int?
    let outputTokens: Int?
    let estimatedCost: Double?
}
