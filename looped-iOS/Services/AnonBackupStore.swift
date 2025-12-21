import Foundation

struct AnonBackupState: Codable {
    let blobId: String
    let createdAt: Date
}

final class AnonBackupStore {
    private let stateKey = "looped.anon.backup.state"
    private let keychain = KeychainStore()

    func loadState() -> AnonBackupState? {
        guard let data = keychain.load(key: stateKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AnonBackupState.self, from: data)
    }

    func saveState(_ state: AnonBackupState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        keychain.save(key: stateKey, data: data)
    }

    func clearState() {
        keychain.delete(key: stateKey)
    }
}
