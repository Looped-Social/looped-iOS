import Foundation

@MainActor
final class AnonBackupViewModel: ObservableObject {
    @Published var backupState: AnonBackupState?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var anonMemberships: [AnonCommunityMembershipDisplay] = []

    private let anonService: AnonService
    private let verificationService: CommunityVerificationServiceProtocol

    init(
        anonService: AnonService = .shared,
        verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService()
    ) {
        self.anonService = anonService
        self.verificationService = verificationService
    }

    func loadState() async {
        backupState = await anonService.backupState()
        await loadMemberships()
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

    private func loadMemberships() async {
        let memberships = await anonService.currentMemberships()
        guard !memberships.isEmpty else {
            anonMemberships = []
            return
        }
        var nameLookup: [Int: String] = [:]
        if let verifications = try? await verificationService.fetchCommunityVerifications() {
            nameLookup = Dictionary(uniqueKeysWithValues: verifications.map { ($0.communityId, $0.communityName) })
        }
        anonMemberships = memberships.map { communityId, membership in
            AnonCommunityMembershipDisplay(
                communityId: communityId,
                communityName: nameLookup[communityId] ?? "Community \(communityId)",
                expiresAt: membership.certExpiresAt,
                isExpired: membership.isExpired
            )
        }
        .sorted { $0.communityName < $1.communityName }
    }
}

struct AnonCommunityMembershipDisplay: Identifiable, Equatable {
    let communityId: Int
    let communityName: String
    let expiresAt: Date
    let isExpired: Bool

    var id: Int { communityId }
}
