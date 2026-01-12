import SwiftUI
import UIKit

struct PhotoIdVerificationView: View {
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onSkip: (() -> Void)?
    let onComplete: () -> Void

    @State private var stage: PhotoIdStage = .selfie
    @State private var selfieImage: UIImage?
    @State private var idFrontImage: UIImage?
    @State private var idBackImage: UIImage?
    @State private var showSelfieCamera = false
    @State private var showIdFrontCamera = false
    @State private var showIdBackCamera = false
    @StateObject private var viewModel: PhotoIdVerificationViewModel

    init(
        currentStep: Int,
        totalSteps: Int,
        onBack: @escaping () -> Void,
        onSkip: (() -> Void)? = nil,
        onComplete: @escaping () -> Void
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onBack = onBack
        self.onSkip = onSkip
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: PhotoIdVerificationViewModel())
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    header
                        .padding(.top, 8)
                        .padding(.horizontal, 16)

                    Spacer()
                        .frame(height: geometry.size.height * 0.05)

                    logo

                    Spacer()
                        .frame(height: geometry.size.height * 0.08)

                    switch stage {
                    case .selfie:
                        selfieStage
                    case .workId:
                        workIdStage
                    }

                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.loopedBackground.ignoresSafeArea())
            }

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
        .fullScreenCover(isPresented: $showSelfieCamera) {
            CameraCaptureView(
                position: .front,
                overlayStyle: .none,
                instruction: "Slowly turn your head to the\nRight",
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
                instruction: "Position ID front within\nframe",
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
                instruction: "Position ID back within\nframe",
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
                onComplete()
            }
        }
        .alert("Verification Failed", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
    }
}

private extension PhotoIdVerificationView {
    var header: some View {
        ZStack {
            HStack {
                Button(action: handleBack) {
                    Image(systemName: "chevron.left")
                        .font(.loopedCustom(.semibold, size: 20))
                        .foregroundColor(.loopedTextPrimary)
                        .frame(width: 40, height: 40)
                }
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
        HStack(spacing: 2) {
            Image("logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 48)

            Text("ooped")
                .font(.loopedLargeHeading)
                .foregroundColor(.loopedTextPrimary)
        }
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

            Text("Slowly turn your head to the\nRight")
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextPrimary)
                .multilineTextAlignment(.center)

            Button(action: { showSelfieCamera = true }) {
                Text(selfieImage == nil ? "Take Selfie" : "Retake Selfie")
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedSecondary)
            }

            PrimaryButton(title: "Continue", isEnabled: selfieImage != nil) {
                stage = .workId
            }
            .padding(.horizontal, 32)
        }
    }

    var workIdStage: some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                Button(action: { showIdFrontCamera = true }) {
                    IdDocumentCardView(title: "ID Front", image: idFrontImage)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { showIdBackCamera = true }) {
                    IdDocumentCardView(title: "ID Back", image: idBackImage)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Text("Position your ID within\nframe")
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                Button(action: { showIdFrontCamera = true }) {
                    Text(idFrontImage == nil ? "Take ID Front" : "Retake ID Front")
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedSecondary)
                }

                Button(action: { showIdBackCamera = true }) {
                    Text(idBackImage == nil ? "Take ID Back" : "Retake ID Back")
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedSecondary)
                }
                .opacity(0.85)
            }

            PrimaryButton(
                title: "Continue",
                isEnabled: idFrontImage != nil && idBackImage != nil && selfieImage != nil && !viewModel.isPreparing,
                isLoading: viewModel.isSubmitting,
                action: handleSubmit
            )
            .padding(.horizontal, 32)
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
                onComplete()
            }
        }
    }
}

private enum PhotoIdStage {
    case selfie
    case workId
}

private struct IdDocumentCardView: View {
    let title: String
    let image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.loopedMutedBackground)
            .frame(width: 280, height: 170)
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

#Preview {
    PhotoIdVerificationView(
        currentStep: 3,
        totalSteps: 5,
        onBack: {},
        onSkip: {},
        onComplete: {}
    )
}
