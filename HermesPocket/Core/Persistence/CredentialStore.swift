import Foundation

struct CredentialStore {
    private enum Keys {
        static let baseURL = "hermes.baseURL"
        static let defaultModel = "hermes.defaultModel"
        static let defaultModelProvider = "hermes.defaultModelProvider"
        static let streamDebugLoggingEnabled = "hermes.streamDebugLoggingEnabled"
    }

    func saveBaseURL(_ value: String) {
        UserDefaults.standard.set(value, forKey: Keys.baseURL)
    }

    func loadBaseURL() -> String {
        UserDefaults.standard.string(forKey: Keys.baseURL) ?? ""
    }

    func clearBaseURL() {
        UserDefaults.standard.removeObject(forKey: Keys.baseURL)
    }

    func saveDefaultModel(_ model: String) {
        UserDefaults.standard.set(model, forKey: Keys.defaultModel)
    }

    func loadDefaultModel() -> String {
        UserDefaults.standard.string(forKey: Keys.defaultModel) ?? ""
    }

    func saveDefaultModelProvider(_ provider: String) {
        UserDefaults.standard.set(provider, forKey: Keys.defaultModelProvider)
    }

    func loadDefaultModelProvider() -> String {
        UserDefaults.standard.string(forKey: Keys.defaultModelProvider) ?? ""
    }

    func saveStreamDebugLoggingEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Keys.streamDebugLoggingEnabled)
    }

    func loadStreamDebugLoggingEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: Keys.streamDebugLoggingEnabled)
    }

    func clearCookies() {
        HTTPCookieStorage.shared.cookies?.forEach { cookie in
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }

    func clearAll() {
        clearBaseURL()
        UserDefaults.standard.removeObject(forKey: Keys.defaultModel)
        UserDefaults.standard.removeObject(forKey: Keys.defaultModelProvider)
        UserDefaults.standard.removeObject(forKey: Keys.streamDebugLoggingEnabled)
        clearCookies()
    }
}
