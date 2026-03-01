import Foundation

final class AppAttestStore {
    private let keyIdKey = "looped.appAttest.keyId"
    private let keychain = KeychainStore()

    func loadKeyId() -> String? {
        guard let data = keychain.load(key: keyIdKey),
              let keyId = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !keyId.isEmpty else {
            return nil
        }
        return keyId
    }

    func saveKeyId(_ keyId: String) {
        let trimmed = keyId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        keychain.save(key: keyIdKey, data: Data(trimmed.utf8))
    }

    func clearKeyId() {
        keychain.delete(key: keyIdKey)
    }
}
