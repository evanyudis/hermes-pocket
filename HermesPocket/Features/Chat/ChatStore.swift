import Foundation
import Observation

struct ActiveToolCall: Equatable {
    let name: String
    let preview: String?
    let args: [String: String]
}

struct ToolCallStep: Identifiable, Equatable {
    let id: UUID
    let name: String
    let preview: String?
    let args: [String: String]
    var status: Status

    enum Status: Equatable {
        case complete
        case error
    }

    init(id: UUID = UUID(), name: String, preview: String?, args: [String: String], status: Status) {
        self.id = id
        self.name = name
        self.preview = preview
        self.args = args
        self.status = status
    }
}

@MainActor
@Observable
final class ChatStore {
    var sessionTitle = "Chat"
    var sessionModel: String?
    var sessionProfile: String?
    var sessionUpdatedAt: Double?
    var draft = ""
    var stagedAttachments: [AttachmentDTO] = []
    var messages: [MessageDTO] = []
    var activeStreamID: String?
    var isLoading = false
    var isStreaming = false
    var isAwaitingAssistantStart = false
    var lastError: String?
    var pendingApproval: ApprovalPendingDTO?
    var pendingApprovalCount = 0
    var pendingClarify: ClarifyPendingDTO?
    var clarifyResponseDraft = ""
    var activeToolCall: ActiveToolCall?
    var pendingToolSteps: [ToolCallStep] = []
}
