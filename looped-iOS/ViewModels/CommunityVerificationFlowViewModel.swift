import Foundation

@MainActor
final class CommunityVerificationFlowViewModel: ObservableObject {
    let communityId: Int
    let communityName: String

    @Published var selectedMethod: CommunityVerificationMethod?
    @Published var startResponse: CommunityVerificationStartResponse?
    @Published var finishResponse: CommunityVerificationFinishResponse?
    @Published var code: String = ""
    @Published var mediaKey: String = ""
    @Published var token: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let verificationService: CommunityVerificationServiceProtocol

    init(
        communityId: Int,
        communityName: String,
        verificationService: CommunityVerificationServiceProtocol = CommunityVerificationService()
    ) {
        self.communityId = communityId
        self.communityName = communityName
        self.verificationService = verificationService
    }

    func selectMethod(_ method: CommunityVerificationMethod) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        finishResponse = nil
        code = ""
        mediaKey = ""
        token = ""
        do {
            let response = try await verificationService.startVerification(
                communityId: communityId,
                method: method
            )
            selectedMethod = method
            startResponse = response
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func resetSelection() {
        selectedMethod = nil
        startResponse = nil
        finishResponse = nil
        code = ""
        mediaKey = ""
        token = ""
        errorMessage = nil
    }

    func submit() async {
        guard !isLoading, let method = selectedMethod else { return }
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMediaKey = mediaKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        switch method {
        case .email:
            guard !trimmedCode.isEmpty else {
                errorMessage = "Enter the verification code."
                return
            }
        case .video:
            guard !trimmedMediaKey.isEmpty else {
                errorMessage = "Enter the media key."
                return
            }
        case .thirdparty:
            guard !trimmedToken.isEmpty else {
                errorMessage = "Enter the provider token."
                return
            }
        }

        isLoading = true
        errorMessage = nil
        do {
            let response = try await verificationService.finishVerification(
                communityId: communityId,
                request: CommunityVerificationFinishRequest(
                    method: method,
                    code: method == .email ? trimmedCode : nil,
                    mediaKey: method == .video ? trimmedMediaKey : nil,
                    token: method == .thirdparty ? trimmedToken : nil
                )
            )
            finishResponse = response
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
