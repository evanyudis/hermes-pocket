import Foundation

struct HermesRequestFactory {
    let baseURL: URL

    func makeJSONRequest(path: String, method: String, body: Data? = nil) throws -> URLRequest {
        guard let url = normalizedURL(path: path) else {
            throw HermesError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    func makeSSERequest(path: String, queryItems: [URLQueryItem]) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw HermesError.invalidURL
        }
        components.path = normalizedPath(path)
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw HermesError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        return request
    }

    private func normalizedURL(path: String) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = normalizedPath(path)
        return components.url
    }

    private func normalizedPath(_ path: String) -> String {
        let basePath = baseURL.path == "/" ? "" : baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pieces = [basePath, cleanPath].filter { !$0.isEmpty }
        return "/" + pieces.joined(separator: "/")
    }
}
