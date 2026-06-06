import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    var items: [SessionSummaryDTO] = []
    var isLoading = false
    var lastError: String?
}
