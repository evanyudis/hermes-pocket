import Foundation
import Observation

@MainActor
@Observable
final class ConnectionStore {
    var baseURLString = ""
    var isLoading = false
    var lastError: String?

    var trimmedBaseURLString: String {
        baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var baseURL: URL? {
        guard let url = URL(string: trimmedBaseURLString), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return nil
        }
        return url
    }
}
