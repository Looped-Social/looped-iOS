import SwiftUI
import PhotosUI

private enum CommunityRequestRoute: Hashable {
    case stepTwo
}

enum CommunityRequestType: String, CaseIterable, Identifiable {
    case company = "Company"
    case school = "School"

    var id: String { rawValue }

    var kind: CommunityRequestKind {
        switch self {
        case .company:
            return .company
        case .school:
            return .school
        }
    }
}

struct CommunityRequestDraft {
    var name: String = ""
    var about: String = ""
    var type: CommunityRequestType?
    var imageData: Data?
}

struct CommunityRequestFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var path: [CommunityRequestRoute] = []
    @State private var draft = CommunityRequestDraft()
    @StateObject private var viewModel = CommunityRequestFlowViewModel()

    var body: some View {
        NavigationStack(path: $path) {
            CommunityRequestStepOneView(
                draft: $draft,
                viewModel: viewModel,
                onCancel: { dismiss() },
                onNext: { path.append(.stepTwo) }
            )
            .navigationDestination(for: CommunityRequestRoute.self) { route in
                switch route {
                case .stepTwo:
                    CommunityRequestStepTwoView(
                        onCancel: { dismiss() },
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
    let onCancel: () -> Void
    let onNext: () -> Void

    @State private var selectedImage: PhotosPickerItem?
    @State private var previewImage: Image?

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

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Community Name*")
                    TextField("Your Name here", text: $draft.name)
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
                    TextField("Who's your community for? What's it about?", text: $draft.about, axis: .vertical)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                        .lineLimit(3...6)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.loopedMutedBackground)
                        .cornerRadius(12)
                        .textInputAutocapitalization(.sentences)
                }

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

                VStack(alignment: .leading, spacing: 12) {
                    fieldLabel("Picture")

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

                if let errorMessage = viewModel.errorMessage {
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
            }
        }
        .onChange(of: draft.name) { _, _ in
            viewModel.clearError()
        }
        .onChange(of: draft.about) { _, _ in
            viewModel.clearError()
        }
        .onChange(of: draft.type) { _, _ in
            viewModel.clearError()
        }
        .onAppear {
            guard previewImage == nil, let data = draft.imageData, let uiImage = UIImage(data: data) else { return }
            previewImage = Image(uiImage: uiImage)
        }
    }

    private func submitRequest() {
        Task {
            let success = await viewModel.submit(
                name: draft.name,
                about: draft.about,
                kind: draft.type?.kind,
                imageData: draft.imageData
            )
            if success {
                onNext()
            }
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.loopedBodyMedium)
            .foregroundColor(.loopedTextPrimary)
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
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VerificationProgressView(currentStep: 2, totalSteps: 2)
                    .padding(.top, 8)

                Image("logo-banner")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 68)
                .padding(.top, 12)
                .padding(.bottom, 24)

                Image("confirm-verify")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: geometry.size.height * 0.36)
                    .padding(.horizontal, 28)

                VStack(spacing: 10) {
                    Text("Thanks for submitting!")
                        .font(.loopedSubheadMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text("Give us 24 hours to process your request.\nKeep an eye on your email.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)

                Spacer()

                Button(action: onDone) {
                    Text("Done")
                        .font(.loopedHeadingMedium)
                        .foregroundColor(.loopedWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.loopedPrimary)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.loopedBackground.ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                LoopedCancelTextButton(action: onCancel)
            }
        }
    }
}

#Preview {
    CommunityRequestFlowView()
}
