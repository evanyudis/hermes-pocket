import Foundation

struct CreateSessionRequestDTO: Encodable, Equatable {
    let workspace: String?
    let model: String?
    let modelProvider: String?
    let profile: String?
}

struct ChatStartRequestDTO: Encodable, Equatable {
    let sessionId: String
    let message: String
    let workspace: String?
    let model: String?
    let modelProvider: String?
    let attachments: [AttachmentDTO]
    let profile: String?
}

struct AttachmentDTO: Codable, Equatable {
    let name: String
    let path: String
    let mime: String
}

struct UploadedAttachmentDTO: Decodable, Equatable {
    let filename: String
    let path: String
    let size: Int
    let mime: String
    let isImage: Bool?
}

struct ChatStartResponseDTO: Decodable, Equatable {
    let streamId: String?
    let sessionId: String?
    let pendingStartedAt: Double?
    let turnId: String?
    let title: String?
    let error: String?
    let activeStreamId: String?
}

struct StreamStatusDTO: Decodable, Equatable {
    let active: Bool
    let streamId: String
    let replayAvailable: Bool?
}

struct CancelStreamDTO: Decodable, Equatable {
    let ok: Bool
    let cancelled: Bool
    let streamId: String
}

struct ApprovalPendingEnvelopeDTO: Decodable, Equatable {
    let pending: ApprovalPendingDTO?
    let pendingCount: Int?
}

struct ApprovalPendingDTO: Decodable, Equatable {
    let approvalId: String?
    let command: String?
    let description: String?
    let patternKey: String?
    let patternKeys: [String]?
}

struct ApprovalRespondRequestDTO: Encodable, Equatable {
    let sessionId: String
    let choice: String
    let approvalId: String?
}

struct ApprovalRespondResponseDTO: Decodable, Equatable {
    let ok: Bool
    let choice: String?
}

struct ClarifyPendingEnvelopeDTO: Decodable, Equatable {
    let pending: ClarifyPendingDTO?
}

struct ClarifyPendingDTO: Decodable, Equatable {
    let clarifyId: String?
    let question: String?
    let description: String?
    let choicesOffered: [String]?
    let choices: [String]?
}

struct ClarifyRespondRequestDTO: Encodable, Equatable {
    let sessionId: String
    let response: String
    let clarifyId: String?
}

struct ClarifyRespondResponseDTO: Decodable, Equatable {
    let ok: Bool
    let response: String?
    let error: String?
    let stale: Bool?
}
