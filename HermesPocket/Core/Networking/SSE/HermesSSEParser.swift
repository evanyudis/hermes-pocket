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
                var value = String(line.dropFirst(6))
                if value.first == " " { value.removeFirst() }
                currentEvent = value
                continue
            }
            if line.hasPrefix("data:") {
                var value = String(line.dropFirst(5))
                if value.first == " " { value.removeFirst() }
                currentData.append(value)
                continue
            }
            if line.hasPrefix("id:") {
                var value = String(line.dropFirst(3))
                if value.first == " " { value.removeFirst() }
                currentID = value
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
        AsyncThrowingStream { continuation in
            let bridge = StreamBridge(configuration: session.configuration, request: request, continuation: continuation)
            bridge.start()
            continuation.onTermination = { _ in
                bridge.cancel()
            }
        }
    }
}

private final class StreamBridge: NSObject, URLSessionDataDelegate {
    private let request: URLRequest
    private let continuation: AsyncThrowingStream<HermesSSEFrame, Error>.Continuation
    private let parser = HermesSSEParser()
    private var task: URLSessionDataTask?
    private var buffer = Data()
    private var didValidateResponse = false
    private var delegateSession: URLSession?

    init(configuration: URLSessionConfiguration, request: URLRequest, continuation: AsyncThrowingStream<HermesSSEFrame, Error>.Continuation) {
        self.request = request
        self.continuation = continuation
        super.init()
        let delegateSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.task = delegateSession.dataTask(with: request)
        self.delegateSession = delegateSession
    }

    func start() {
        task?.resume()
    }

    func cancel() {
        task?.cancel()
        delegateSession?.invalidateAndCancel()
        delegateSession = nil
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
        guard let http = response as? HTTPURLResponse, 200 ... 299 ~= http.statusCode else {
            continuation.finish(throwing: HermesError.transport("SSE request failed"))
            cancel()
            return .cancel
        }
        didValidateResponse = true
        return .allow
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard didValidateResponse else { return }
        buffer.append(data)
        drainBuffer()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                continuation.finish()
            } else {
                continuation.finish(throwing: error)
            }
        } else {
            flushRemainingBuffer()
            continuation.finish()
        }
        delegateSession?.finishTasksAndInvalidate()
        delegateSession = nil
    }

    private func drainBuffer() {
        while true {
            let crlfRange = buffer.range(of: Data([0x0D, 0x0A, 0x0D, 0x0A]))
            let lfRange = buffer.range(of: Data([0x0A, 0x0A]))
            let range: Range<Data.Index>?
            if let crlfRange, let lfRange {
                range = crlfRange.lowerBound < lfRange.lowerBound ? crlfRange : lfRange
            } else {
                range = crlfRange ?? lfRange
            }
            guard let range else { return }
            let frameData = buffer.subdata(in: 0..<range.lowerBound)
            buffer.removeSubrange(0..<range.upperBound)
            emitFrameData(frameData)
        }
    }

    private func flushRemainingBuffer() {
        guard !buffer.isEmpty else { return }
        emitFrameData(buffer)
        buffer.removeAll(keepingCapacity: false)
    }

    private func emitFrameData(_ data: Data) {
        guard let raw = String(data: data, encoding: .utf8) else { return }
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for frame in parser.parse(lines: lines) {
            continuation.yield(frame)
        }
    }
}
