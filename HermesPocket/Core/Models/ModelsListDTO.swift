import Foundation

struct ModelsListDTO: Decodable, Equatable {
    let activeProvider: String?
    let defaultModel: String?
    let groups: [ModelGroupDTO]?

    static let empty = ModelsListDTO(activeProvider: nil, defaultModel: nil, groups: nil)
}

struct ModelGroupDTO: Decodable, Equatable {
    let provider: String?
    let providerId: String?
    let models: [ModelEntryDTO]?
}

struct ModelEntryDTO: Decodable, Equatable, Identifiable {
    let id: String
    let label: String?
}
