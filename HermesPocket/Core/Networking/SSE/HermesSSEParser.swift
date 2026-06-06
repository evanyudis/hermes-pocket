import Foundation

struct HermesSSEFrame: Equatable {
    let event: String
    let data: String
    let id: String?
}

struct HermesSSEParser {
    func parse(lines: [String]) -> [HermesSSEFrame] {
        var frames: [HermesSSEFrame] = []
        var currentEvent = "message"
        var currentData: [String] = []
        var currentID: String?

        func flush() {
            guard !currentData.isEmpty else { return }
            frames.append(
                HermesSSEFrame(
                    event: currentEvent,
                    data: currentData.joined(separator: "\n"),
                    id: currentID
                )
            )
            currentEvent = "message"
            currentData = []
            currentID = nil
        }

        for line in lines {
            if line.isEmpty {
                flush()
                continue
            }
            if line.hasPrefix(":") {
                continue
            }
            if line.hasPrefix("event:") {
                currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if line.hasPrefix("data:") {
                currentData.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                continue
            }
            if line.hasPrefix("id:") {
                currentID = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
        }

        flush()
        return frames
    }
}

final class HermesSSEClient {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func events(for request: URLRequest) -> AsyncThrowingStream<HermesSSEFrame, Error> {
        let streamSession = session

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await streamSession.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, 200 ... 299 ~= http.statusCode else {
                        throw HermesError.transport("SSE request failed")
                    }

                    var buffered: [String] = []
                    let parser = HermesSSEParser()

                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            continuation.finish()
                            return
                        }
                        if line.isEmpty {
                            buffered.append(line)
                            for frame in parser.parse(lines: buffered) {
                                continuation.yield(frame)
                            }
                            buffered.removeAll(keepingCapacity: true)
                        } else {
                            buffered.append(line)
                        }
                    }

                    if !buffered.isEmpty {
                        for frame in parser.parse(lines: buffered) {
                            continuation.yield(frame)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
