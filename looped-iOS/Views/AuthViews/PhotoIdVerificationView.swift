import SwiftUI
import UIKit

	struct PhotoIdVerificationView: View {
    let communityId: Int?
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onSkip: (() -> Void)?
    let onComplete: () -> Void
    let showsHeader: Bool

    @State private var stage: PhotoIdStage = .selfie
    @State private var selfieImage: UIImage?
    @State private var idFrontImage: UIImage?
    @State private var idBackImage: UIImage?
	    @State private var showSelfieCamera = false
	    @State private var showIdFrontCamera = false
	    @State private var showIdBackCamera = false
	    @StateObject private var viewModel: PhotoIdVerificationViewModel
	    @State private var containerWidth: CGFloat = 0

    init(
        communityId: Int? = nil,
        currentStep: Int,
        totalSteps: Int,
        onBack: @escaping () -> Void,
        onSkip: (() -> Void)? = nil,
        onComplete: @escaping () -> Void,
        showsHeader: Bool = true
    ) {
        self.communityId = communityId
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.onSkip = onSkip
        self.onComplete = onComplete
        self.showsHeader = showsHeader
        _viewModel = StateObject(
            wrappedValue: PhotoIdVerificationViewModel(
                service: PhotoIdVerificationService(communityId: communityId)
            )
        )
    }

	    var body: some View {
	        ZStack {
	            VStack(spacing: 0) {
	                if showsHeader {
	                    header
	                        .padding(.top, 8)
	                        .padding(.horizontal, 16)
	                }

	                ScrollView(showsIndicators: false) {
	                    VStack(spacing: 32) {
	                        logo
	                            .padding(.top, showsHeader ? 16 : 24)

	                        switch stage {
	                        case .selfie:
	                            selfieStage
	                        case .workId:
	                            workIdStage
	                        }
	                    }
	                    .frame(maxWidth: 520)
	                    .frame(maxWidth: .infinity, alignment: .center)
	                    .padding(.horizontal, 24)
	                    .padding(.bottom, 24)
	                }
	            }
	            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
	            .background(Color.loopedBackground.ignoresSafeArea())

	            if viewModel.isPreparing || viewModel.isSubmitting {
	                ZStack {
	                    Color.loopedBlack.opacity(0.35).ignoresSafeArea()
	                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Color.loopedWhite)
                        Text(viewModel.isPreparing ? "Preparing verification…" : "Uploading…")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedWhite)
                    }
                    .padding(18)
                    .background(Color.loopedBlack.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
	        }
	        .readWidth { containerWidth = $0 }
	        .safeAreaInset(edge: .bottom, spacing: 0) {
	            let fallbackWidth = UIScreen.main.bounds.width
	            let availableWidth = max(0, (containerWidth > 0 ? containerWidth : fallbackWidth) - 48)
	            let actionWidth = min(520, availableWidth)
	            HStack {
	                Spacer(minLength: 0)
	                bottomAction
	                    .frame(width: actionWidth)
	                Spacer(minLength: 0)
	            }
	            .frame(maxWidth: .infinity)
	            .padding(.horizontal, 24)
	            .padding(.bottom, 12)
	        }
	        .fullScreenCover(isPresented: $showSelfieCamera) {
	            CameraCaptureView(
	                position: .front,
	                overlayStyle: .none,
	                instruction: instructionWithNonce("Position your face clearly in the frame"),
	                onCancel: { showSelfieCamera = false },
	                onConfirm: { image in
	                    selfieImage = image
	                    showSelfieCamera = false
                }
            )
        }
        .fullScreenCover(isPresented: $showIdFrontCamera) {
            CameraCaptureView(
                position: .back,
                overlayStyle: .idCard,
                instruction: instructionWithNonce("Position ID front within\nframe"),
                onCancel: { showIdFrontCamera = false },
                onConfirm: { image in
                    idFrontImage = image
                    showIdFrontCamera = false
                }
            )
        }
        .fullScreenCover(isPresented: $showIdBackCamera) {
            CameraCaptureView(
                position: .back,
                overlayStyle: .idCard,
                instruction: instructionWithNonce("Position ID back within\nframe"),
                onCancel: { showIdBackCamera = false },
                onConfirm: { image in
                    idBackImage = image
                    showIdBackCamera = false
                }
            )
        }
        .task {
            await viewModel.prepareIfNeeded()
            if viewModel.isAlreadyVerifiedOrPending {
                if let communityId {
                    NotificationCenter.default.post(
                        name: .communityStateChanged,
                        object: nil,
                        userInfo: [LoopedNotificationUserInfoKey.communityId: communityId]
                    )
                }
                onComplete()
            }
        }
        .alert("Verification Failed", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!showsHeader && stage == .workId)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if !showsHeader {
                ToolbarItem(placement: .principal) {
                    VerificationProgressView(currentStep: currentStep, totalSteps: totalSteps)
                }

                if stage == .workId {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { stage = .selfie }) {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Back")
                    }
                }

                if let onSkip {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip", action: onSkip)
                    }
                }
            }
        }
    }
}

private extension PhotoIdVerificationView {
    var header: some View {
        ZStack {
            HStack {
                LoopedBackButton(action: handleBack)
                Spacer()

                if let onSkip {
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedSecondary)
                    }
                    .padding(.trailing, 4)
                }
            }

            VerificationProgressView(currentStep: currentStep, totalSteps: totalSteps)
        }
    }

	    var logo: some View {
	        Image("logo-banner")
	            .resizable()
	            .scaledToFit()
	            .frame(height: 68)
	    }

	    var selfieStage: some View {
	        VStack(spacing: 20) {
	            Button(action: { showSelfieCamera = true }) {
	                Circle()
                    .fill(Color.loopedPrimary)
                    .frame(width: 180, height: 180)
                    .overlay(
                        Group {
                            if let selfieImage {
                                Image(uiImage: selfieImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.loopedCustom(.regular, size: 60))
                                    .foregroundColor(.loopedWhite)
                            }
                        }
                            .clipShape(Circle())
                    )
	            }
	            .buttonStyle(PlainButtonStyle())
	            .disabled(!viewModel.isReadyToCapture)
	            .opacity(viewModel.isReadyToCapture ? 1 : 0.65)

	            VStack(spacing: 10) {
	                nonceCard
	                Text(instructionWithNonce("Position your face clearly in the frame"))
	                    .font(.loopedSubBodyMedium)
	                    .foregroundColor(.loopedTextPrimary)
	                    .multilineTextAlignment(.center)
	            }

	            Button(action: { showSelfieCamera = true }) {
	                Text(selfieImage == nil ? "Take Selfie" : "Retake Selfie")
	                    .font(.loopedSubBodyMedium)
	                    .foregroundColor(.loopedSecondary)
	            }
	            .disabled(!viewModel.isReadyToCapture)
	            .opacity(viewModel.isReadyToCapture ? 1 : 0.65)
	        }
	    }

	    var workIdStage: some View {
	        VStack(spacing: 20) {
	            VStack(spacing: 14) {
	                Button(action: { showIdFrontCamera = true }) {
	                    IdDocumentCardView(title: "ID Front", image: idFrontImage)
	                }
	                .buttonStyle(PlainButtonStyle())
	                .disabled(!viewModel.isReadyToCapture)
	                .opacity(viewModel.isReadyToCapture ? 1 : 0.65)

	                Button(action: { showIdBackCamera = true }) {
	                    IdDocumentCardView(title: "ID Back", image: idBackImage)
	                }
	                .buttonStyle(PlainButtonStyle())
	                .disabled(!viewModel.isReadyToCapture)
	                .opacity(viewModel.isReadyToCapture ? 1 : 0.65)
	            }
	            .frame(maxWidth: .infinity)

	            VStack(spacing: 10) {
	                nonceCard
	                Text(instructionWithNonce("Position your ID within\nframe"))
	                    .font(.loopedSubBodyMedium)
	                    .foregroundColor(.loopedTextPrimary)
	                    .multilineTextAlignment(.center)
	            }

            HStack(spacing: 18) {
                Button(action: { showIdFrontCamera = true }) {
                    Text(idFrontImage == nil ? "Take ID Front" : "Retake ID Front")
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedSecondary)
                }
                .disabled(!viewModel.isReadyToCapture)
                .opacity(viewModel.isReadyToCapture ? 1 : 0.65)

                Button(action: { showIdBackCamera = true }) {
                    Text(idBackImage == nil ? "Take ID Back" : "Retake ID Back")
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedSecondary)
                }
                .disabled(!viewModel.isReadyToCapture)
                .opacity(viewModel.isReadyToCapture ? 0.85 : 0.55)
            }

	        }
	    }

	    @ViewBuilder
	    var bottomAction: some View {
	        switch stage {
	        case .selfie:
	            PrimaryButton(title: "Continue", isEnabled: selfieImage != nil) {
	                stage = .workId
	            }
	        case .workId:
	            PrimaryButton(
	                title: "Continue",
	                isEnabled: idFrontImage != nil && idBackImage != nil && selfieImage != nil && !viewModel.isPreparing,
	                isLoading: viewModel.isSubmitting,
	                action: handleSubmit
	            )
	        }
	    }

    func handleBack() {
        if stage == .workId {
            stage = .selfie
        } else {
            onBack()
        }
    }

    func handleSubmit() {
        guard let selfieImage, let idFrontImage else { return }
        Task {
            let success = await viewModel.submit(selfie: selfieImage, idFront: idFrontImage, idBack: idBackImage)
            if success {
                if let communityId {
                    NotificationCenter.default.post(
                        name: .communityStateChanged,
                        object: nil,
                        userInfo: [LoopedNotificationUserInfoKey.communityId: communityId]
                    )
                }
                onComplete()
            }
        }
    }
}

private enum PhotoIdStage {
    case selfie
    case workId
}

private extension PhotoIdVerificationView {
    @ViewBuilder
    var nonceCard: some View {
        if let nonce = viewModel.visualNonce, !nonce.isEmpty {
            VStack(spacing: 10) {
                Text("Write this code on paper and keep it visible in each photo:")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
                    .multilineTextAlignment(.center)

                Button(action: { UIPasteboard.general.string = nonce }) {
                    HStack(spacing: 10) {
                        Text(nonce)
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.loopedTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Image(systemName: "doc.on.doc")
                            .font(.loopedCustom(.regular, size: 16))
                            .foregroundColor(.loopedTextSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.loopedMutedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Copy verification code")
            }
            .frame(maxWidth: .infinity)
        } else if viewModel.isPreparing {
            HStack(spacing: 10) {
                ProgressView()
                Text("Getting verification code…")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    func instructionWithNonce(_ base: String) -> String {
        guard let nonce = viewModel.visualNonce, !nonce.isEmpty else { return base }
        return "Include code \(nonce) in the photo.\n\(base)"
    }
}

	private struct IdDocumentCardView: View {
	    let title: String
	    let image: UIImage?

	    var body: some View {
	        RoundedRectangle(cornerRadius: 18, style: .continuous)
	            .fill(Color.loopedMutedBackground)
	            .frame(maxWidth: .infinity)
	            .frame(height: 170)
	            .shadow(color: Color.loopedBlack.opacity(0.12), radius: 10, x: 0, y: 6)
	            .overlay(
	                HStack(spacing: 16) {
	                    VStack(alignment: .leading, spacing: 8) {
	                        Text("Looped")
	                            .font(.loopedBodyMedium)
	                            .foregroundColor(.loopedTextPrimary)
	                        Text(title)
	                            .font(.loopedSmallText)
	                            .foregroundColor(.loopedTextSecondary)
	                    }

	                    Spacer()

	                    RoundedRectangle(cornerRadius: 10)
	                        .fill(Color.loopedBackground)
	                        .frame(width: 88, height: 110)
	                        .overlay(
	                            Group {
	                                if let image {
	                                    Image(uiImage: image)
	                                        .resizable()
	                                        .scaledToFill()
	                                } else {
	                                    Image(systemName: "rectangle.on.rectangle")
	                                        .font(.loopedCustom(.regular, size: 36))
	                                        .foregroundColor(.loopedTextSecondary)
	                                }
	                            }
	                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
	                        )
	                }
	                .padding(.horizontal, 20)
	            )
	    }
	}

private extension PhotoIdVerificationView {
    struct WidthPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
}

private extension View {
    func readWidth(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear.preference(key: PhotoIdVerificationView.WidthPreferenceKey.self, value: geometry.size.width)
            }
        )
        .onPreferenceChange(PhotoIdVerificationView.WidthPreferenceKey.self) { newValue in
            onChange(newValue)
        }
    }
}

#Preview {
    PhotoIdVerificationView(
        communityId: 1,
        currentStep: 3,
        totalSteps: 5,
        onBack: {},
        onSkip: {},
        onComplete: {}
    )
}
