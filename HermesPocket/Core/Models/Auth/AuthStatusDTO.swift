import Foundation

struct AuthStatusDTO: Decodable, Equatable {
    let authEnabled: Bool
    let loggedIn: Bool
    let passwordAuthEnabled: Bool
    let passwordlessEnabled: Bool
    let passkeysEnabled: Bool
    let passkeysCount: Int?
    let passkeyFeatureFlag: Bool?
}
