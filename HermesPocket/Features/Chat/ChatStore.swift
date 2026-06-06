import Foundation
import Observation

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
    var lastError: String?
    var pendingApproval: ApprovalPendingDTO?
    var pendingApprovalCount = 0
    var pendingClarify: ClarifyPendingDTO?
    var clarifyResponseDraft = ""
}
