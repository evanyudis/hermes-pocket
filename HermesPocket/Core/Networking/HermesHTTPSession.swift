import Foundation

final class HermesHTTPSession: @unchecked Sendable {
    let rest: URLSession
    let stream: URLSession

    init(cookieStorage: HTTPCookieStorage = .shared) {
        let restConfiguration = URLSessionConfiguration.default
        restConfiguration.httpCookieStorage = cookieStorage
        restConfiguration.httpShouldSetCookies = true
        restConfiguration.waitsForConnectivity = true
        restConfiguration.timeoutIntervalForRequest = 30
        restConfiguration.timeoutIntervalForResource = 60

        let streamConfiguration = URLSessionConfiguration.default
        streamConfiguration.httpCookieStorage = cookieStorage
        streamConfiguration.httpShouldSetCookies = true
        streamConfiguration.waitsForConnectivity = true
        streamConfiguration.timeoutIntervalForRequest = 300
        streamConfiguration.timeoutIntervalForResource = 600

        self.rest = URLSession(configuration: restConfiguration)
        self.stream = URLSession(configuration: streamConfiguration)
    }
}
