import Foundation
import Observation

@MainActor
@Observable
final class AuthStore {
    var authEnabled = true
    var isLoggedIn = false
    var isLoading = false
    var lastError: String?
}
