import Foundation
import Security

private struct KeychainStore {
    private let service = Bundle.main.bundleIdentifier ?? "com.evanyudis.hermes-pocket"

    func saveString(_ value: String, for key: String) {
        saveData(Data(value.utf8), for: key)
    }

    func loadString(for key: String) -> String {
        guard let data = loadData(for: key) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    func saveCookies(_ cookies: [HTTPCookie], for key: String) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: true) else { return }
        saveData(data, for: key)
    }

    func loadCookies(for key: String) -> [HTTPCookie] {
        guard let data = loadData(for: key) else { return [] }
        return (try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [HTTPCookie]) ?? []
    }

    func deleteValue(for key: String) {
        let query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)
    }

    private func saveData(_ data: Data, for key: String) {
        let query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        _ = SecItemAdd(query.merging(attributes, uniquingKeysWith: { _, new in new }) as CFDictionary, nil)
    }

    private func loadData(for key: String) -> Data? {
        let query = baseQuery(for: key).merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ], uniquingKeysWith: { _, new in new })

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}

struct CredentialStore {
    private enum Keys {
        static let baseURL = "hermes.baseURL"
        static let cookies = "hermes.cookies"
        static let defaultModel = "hermes.defaultModel"
        static let defaultModelProvider = "hermes.defaultModelProvider"
        static let streamDebugLoggingEnabled = "hermes.streamDebugLoggingEnabled"
    }

    private let keychain = KeychainStore()

    func saveBaseURL(_ value: String) {
        keychain.saveString(value, for: Keys.baseURL)
    }

    func loadBaseURL() -> String {
        keychain.loadString(for: Keys.baseURL)
    }

    func clearBaseURL() {
        keychain.deleteValue(for: Keys.baseURL)
    }

    func saveCookies(_ cookies: [HTTPCookie]) {
        keychain.saveCookies(cookies, for: Keys.cookies)
    }

    func loadCookies() -> [HTTPCookie] {
        keychain.loadCookies(for: Keys.cookies)
    }

    func clearCookies() {
        keychain.deleteValue(for: Keys.cookies)
        HTTPCookieStorage.shared.cookies?.forEach { cookie in
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
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

    func clearAll() {
        clearBaseURL()
        UserDefaults.standard.removeObject(forKey: Keys.defaultModel)
        UserDefaults.standard.removeObject(forKey: Keys.defaultModelProvider)
        UserDefaults.standard.removeObject(forKey: Keys.streamDebugLoggingEnabled)
        clearCookies()
    }
}
