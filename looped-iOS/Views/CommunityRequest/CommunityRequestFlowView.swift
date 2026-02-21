import Foundation
import SwiftUI
import PhotosUI

private enum CommunityRequestRoute: Hashable {
    case stepTwo
}

enum CommunityRequestType: String, CaseIterable, Identifiable {
    case company = "Company"
    case school = "School"
    case field = "Field"
    case major = "Major"

    var id: String { rawValue }

    var kind: CommunityRequestKind {
        switch self {
        case .company:
            return .company
        case .school:
            return .school
        case .field:
            return .field
        case .major:
            return .major
        }
    }
}

private extension CommunityRequestType {
    init?(kind: CommunityRequestKind) {
        switch kind {
        case .company:
            self = .company
        case .school:
            self = .school
        case .field:
            self = .field
        case .major:
            self = .major
        case .unknown:
            return nil
        }
    }
}

struct CommunityRequestDraft {
    var name: String = ""
    var about: String = ""
    var type: CommunityRequestType?
    var imageData: Data?
    var contactEmail: String = ""
}

struct CommunityRequestFlowView: View {
    enum Mode {
        case standard
        case onboarding
    }

    @Environment(\.dismiss) private var dismiss
    private let mode: Mode
    private let onOnboardingExploreApp: (() async -> Bool)?
    private let locksTypeSelection: Bool
    @State private var path: [CommunityRequestRoute] = []
    @State private var draft: CommunityRequestDraft
    @StateObject private var viewModel = CommunityRequestFlowViewModel()

    init(
        mode: Mode = .standard,
        initialName: String = "",
        suggestedKind: CommunityRequestKind? = nil,
        onOnboardingExploreApp: (() async -> Bool)? = nil
    ) {
        self.mode = mode
        self.onOnboardingExploreApp = onOnboardingExploreApp
        self.locksTypeSelection = suggestedKind != nil
        _draft = State(
            initialValue: CommunityRequestDraft(
                name: initialName,
                about: "",
                type: suggestedKind.flatMap(CommunityRequestType.init(kind:)),
                imageData: nil,
                contactEmail: ""
            )
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            CommunityRequestStepOneView(
                draft: $draft,
                viewModel: viewModel,
                mode: mode,
                locksTypeSelection: locksTypeSelection,
                onCancel: { dismiss() },
                onNext: { path.append(.stepTwo) }
            )
            .navigationDestination(for: CommunityRequestRoute.self) { route in
                switch route {
                case .stepTwo:
                    CommunityRequestStepTwoView(
                        mode: mode,
                        willNotifyByEmail: !draft.contactEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        onOnboardingExploreApp: onOnboardingExploreApp,
                        onDone: { dismiss() }
                    )
                }
            }
        }
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct CommunityRequestStepOneView: View {
    @Binding var draft: CommunityRequestDraft
    @ObservedObject var viewModel: CommunityRequestFlowViewModel
    let mode: CommunityRequestFlowView.Mode
    let locksTypeSelection: Bool
    let onCancel: () -> Void
    let onNext: () -> Void

    @State private var selectedImage: PhotosPickerItem?
    @State private var previewImage: Image?
    @State private var localErrorMessage: String?

    private var isOnboarding: Bool {
        mode == .onboarding
    }

    private var isStepComplete: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.about.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        draft.type != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VerificationProgressView(currentStep: 1, totalSteps: 2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    Image("community-find")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .frame(maxWidth: .infinity)

                    Text("Sorry, we do not have your community yet.")
                        .font(.loopedSubheadMedium)
                        .foregroundColor(.loopedTextPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text("Enter your information below and we will be on it.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Community Name*")
                    TextField("School or company name", text: $draft.name)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.loopedMutedBackground)
                        .cornerRadius(12)
                        .textInputAutocapitalization(.words)
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("About*")
                    TextField("Who is this community for? What is it about?", text: $draft.about, axis: .vertical)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .lineLimit(3...6)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.loopedMutedBackground)
                        .cornerRadius(12)
                        .textInputAutocapitalization(.sentences)
                }

                if isOnboarding {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Type*")
                        if locksTypeSelection {
                            Text(draft.type?.rawValue ?? "Company")
                                .font(.loopedBody)
                                .foregroundColor(.loopedTextPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.loopedMutedBackground)
                                .cornerRadius(12)
                        } else {
                            HStack(spacing: 10) {
                                ForEach([CommunityRequestType.company, .school]) { type in
                                    OnboardingRequestKindChip(
                                        title: type.rawValue,
                                        isSelected: draft.type == type,
                                        onTap: { draft.type = type }
                                    )
                                }
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Type*")
                        Picker(
                            selection: $draft.type,
                            label: HStack {
                                Text(draft.type?.rawValue ?? "Select type")
                                    .font(.loopedBody)
                                    .foregroundColor(draft.type == nil ? .loopedTextSecondary : .loopedTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.loopedCustom(.medium, size: 12))
                                    .foregroundColor(.loopedTextSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.loopedMutedBackground)
                            .cornerRadius(12)
                        ) {
                            ForEach(CommunityRequestType.allCases) { type in
                                Text(type.rawValue)
                                    .tag(Optional(type))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Contact Email", optional: true)
                    TextField(
                        "",
                        text: $draft.contactEmail,
                        prompt: Text("you@example.com")
                            .foregroundColor(.loopedTextSecondary)
                    )
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.loopedMutedBackground)
                        .cornerRadius(12)
                        .tint(.loopedTextPrimary)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 12) {
                    fieldLabel("Picture", optional: true)

                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.loopedMutedBackground)
                                .frame(width: 96, height: 96)

                            if let previewImage {
                                previewImage
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 96, height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            } else {
                                Image(systemName: "plus")
                                    .font(.loopedCustom(.semibold, size: 20))
                                    .foregroundColor(.loopedTextSecondary)
                            }
                        }
                    }
                }

                Button(action: submitRequest) {
                    HStack(spacing: 8) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(.loopedWhite)
                        }
                        Text(viewModel.isSubmitting ? "Submitting..." : "Continue")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedWhite)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.loopedPrimary)
                    .cornerRadius(26)
                }
                .disabled(!isStepComplete || viewModel.isSubmitting)
                .opacity(isStepComplete && !viewModel.isSubmitting ? 1 : 0.4)
                .padding(.top, 8)

                if let errorMessage = localErrorMessage ?? viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedError)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                }

                termsText
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .disabled(viewModel.isSubmitting)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                LoopedCancelTextButton(action: onCancel)
            }
        }
        .onChange(of: selectedImage) { _, newValue in
            Task {
                guard let data = try? await newValue?.loadTransferable(type: Data.self) else { return }
                draft.imageData = data
                if let uiImage = UIImage(data: data) {
                    previewImage = Image(uiImage: uiImage)
                }
                viewModel.clearError()
                localErrorMessage = nil
            }
        }
        .onChange(of: draft.name) { _, _ in
            viewModel.clearError()
            localErrorMessage = nil
        }
        .onChange(of: draft.about) { _, _ in
            viewModel.clearError()
            localErrorMessage = nil
        }
        .onChange(of: draft.type) { _, _ in
            viewModel.clearError()
            localErrorMessage = nil
        }
        .onChange(of: draft.contactEmail) { _, _ in
            localErrorMessage = nil
        }
        .onAppear {
            guard previewImage == nil, let data = draft.imageData, let uiImage = UIImage(data: data) else { return }
            previewImage = Image(uiImage: uiImage)
        }
    }

    private func submitRequest() {
        let trimmedEmail = draft.contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidOptionalEmail(trimmedEmail) else {
            localErrorMessage = "Enter a valid email or leave it blank."
            return
        }

        let shouldNotifyWhenAvailable = !trimmedEmail.isEmpty

        Task {
            let success = await viewModel.submit(
                name: draft.name,
                about: draft.about,
                kind: draft.type?.kind,
                imageData: draft.imageData,
                contactEmail: trimmedEmail,
                notifyWhenAvailable: shouldNotifyWhenAvailable
            )
            if success {
                onNext()
            }
        }
    }

    private func isValidOptionalEmail(_ email: String) -> Bool {
        guard !email.isEmpty else { return true }
        let predicate = NSPredicate(format: "SELF MATCHES[c] %@", "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")
        return predicate.evaluate(with: email)
    }

    @ViewBuilder
    private func fieldLabel(_ title: String, optional: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            if optional {
                Text("Optional")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
            }
        }
    }

    private var termsText: some View {
        (Text("By creating a community you agree to our ")
            .foregroundColor(.loopedTextSecondary)
         + Text("community standards and moderation guidelines")
            .foregroundColor(.loopedSecondary)
            .underline())
            .font(.loopedSmallText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }
}

private struct CommunityRequestStepTwoView: View {
    let mode: CommunityRequestFlowView.Mode
    let willNotifyByEmail: Bool
    let onOnboardingExploreApp: (() async -> Bool)?
    let onDone: () -> Void
    @State private var isCompleting = false
    @State private var completionError: String?

    private var isOnboarding: Bool {
        mode == .onboarding
    }

    var body: some View {
        VStack(spacing: 0) {
            VerificationProgressView(currentStep: 2, totalSteps: 2)
                .padding(.top, 8)

            Spacer()
                .frame(height: 36)

            Image("community-confirm")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 360, maxHeight: 320)

            VStack(spacing: 12) {
                Text("Thank you!")
                    .font(.loopedHeadingMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .multilineTextAlignment(.center)

                Text("You planted the seed for your community.")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .multilineTextAlignment(.center)

                Text(confirmationMessage)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 26)
            .padding(.top, 24)

            if let completionError {
                Text(completionError)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedError)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
                    .padding(.top, 12)
            }

            Spacer()

            PrimaryButton(
                title: "Continue",
                isEnabled: !isCompleting,
                isLoading: isCompleting
            ) {
                handlePrimaryAction()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.loopedBackground.ignoresSafeArea())
        .interactiveDismissDisabled(isCompleting)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handlePrimaryAction() {
        guard isOnboarding else {
            onDone()
            return
        }

        guard let onOnboardingExploreApp else {
            onDone()
            return
        }

        guard !isCompleting else { return }
        completionError = nil
        isCompleting = true

        Task { @MainActor in
            let success = await onOnboardingExploreApp()
            isCompleting = false
            if success {
                onDone()
            } else {
                completionError = "Your request was submitted, but onboarding could not be finished yet. Choose an existing community for now."
            }
        }
    }

    private var confirmationMessage: String {
        if willNotifyByEmail {
            return "We'll get back to you within 48 hours. If you added an email, we'll email you when it's ready. Make sure to check back. You can still verify in other communities in the meantime."
        }
        return "We'll get back to you within 48 hours. You can still verify in other communities in the meantime."
    }
}

private struct OnboardingRequestKindChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.loopedSubBodyMedium)
                .foregroundColor(isSelected ? .loopedWhite : .loopedTextSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.loopedPrimary : Color.loopedMutedBackground)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.loopedPrimary : Color.loopedTextSecondary.opacity(0.25),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CommunityRequestFlowView()
}
