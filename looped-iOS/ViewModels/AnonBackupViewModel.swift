import Foundation

@MainActor
final class AnonBackupViewModel: ObservableObject {
    @Published var backupState: AnonBackupState?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let anonService: AnonService

    init(anonService: AnonService = .shared) {
        self.anonService = anonService
    }

    func loadState() async {
        backupState = await anonService.backupState()
    }

    func createBackup(passphrase: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            let state = try await anonService.createBackup(passphrase: passphrase)
            backupState = state
            successMessage = "Backup created"
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func restoreBackup(blobId: String, passphrase: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            _ = try await anonService.restoreBackup(blobId: blobId, passphrase: passphrase)
            await loadState()
            successMessage = "Backup restored"
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
