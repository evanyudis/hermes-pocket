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

    init(name: String, path: String, mime: String) {
        self.name = name
        self.path = path
        self.mime = mime
    }

    init(from decoder: Decoder) throws {
        // The server may send attachments as either:
        //   a) a JSON object: {"name": "...", "path": "...", "mime": "..."}
        //   b) a plain string: "/path/to/file.pdf"
        // Handle both to avoid decoding failures.
        if let singleValue = try? decoder.singleValueContainer(),
           let path = try? singleValue.decode(String.self) {
            self.path = path
            let url = URL(fileURLWithPath: path)
            self.name = url.lastPathComponent
            let ext = url.pathExtension.lowercased()
            if !ext.isEmpty {
                // Map common extensions to MIME types
                let mimeMap: [String: String] = [
                    "pdf": "application/pdf",
                    "png": "image/png",
                    "jpg": "image/jpeg",
                    "jpeg": "image/jpeg",
                    "gif": "image/gif",
                    "webp": "image/webp",
                    "svg": "image/svg+xml",
                    "txt": "text/plain",
                    "json": "application/json",
                    "js": "application/javascript",
                    "ts": "application/typescript",
                    "tsx": "text/typescript",
                    "jsx": "text/jsx",
                    "swift": "text/swift",
                    "py": "text/x-python",
                    "md": "text/markdown",
                    "html": "text/html",
                    "css": "text/css",
                    "xml": "application/xml",
                    "yaml": "text/yaml",
                    "yml": "text/yaml",
                    "zip": "application/zip",
                    "tar": "application/x-tar",
                    "gz": "application/gzip"
                ]
                self.mime = mimeMap[ext.lowercased()] ?? "application/octet-stream"
            } else {
                self.mime = "application/octet-stream"
            }
            return
        }
        // Object format: decode keys directly (handles both camelCase and snake_case
        // via the global decoder's convertFromSnakeCase strategy)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.path = try container.decode(String.self, forKey: .path)
        self.mime = try container.decodeIfPresent(String.self, forKey: .mime) ?? "application/octet-stream"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(mime, forKey: .mime)
    }

    private enum CodingKeys: String, CodingKey {
        case name, path, mime
    }
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
