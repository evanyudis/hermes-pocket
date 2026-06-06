import Foundation

enum HermesError: Error, LocalizedError, Equatable {
    case invalidURL
    case unauthorized
    case forbidden
    case rateLimited
    case notFound
    case conflictActiveStream(activeStreamID: String?)
    case backend(message: String)
    case decoding(String)
    case transport(String)
    case streamEnded
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL."
        case .unauthorized:
            return "Unauthorized."
        case .forbidden:
            return "Forbidden."
        case .rateLimited:
            return "Rate limited."
        case .notFound:
            return "Not found."
        case .conflictActiveStream(let activeStreamID):
            return "Session already has active stream: \(activeStreamID ?? "unknown")"
        case .backend(let message):
            return message
        case .decoding(let message):
            return "Decoding failed: \(message)"
        case .transport(let message):
            return "Transport failed: \(message)"
        case .streamEnded:
            return "Stream ended."
        case .notImplemented:
            return "Not implemented yet."
        }
    }
}
