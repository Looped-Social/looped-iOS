import SwiftUI
import UIKit

struct PhotoIdVerificationView: View {
    let currentStep: Int
    let totalSteps: Int
    let onBack: () -> Void
    let onComplete: () -> Void

    @State private var stage: PhotoIdStage = .selfie
    @State private var selfieImage: UIImage?
    @State private var workIdImage: UIImage?
    @State private var showSelfieCamera = false
    @State private var showWorkIdCamera = false

    var body: some View {
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
        .fullScreenCover(isPresented: $showSelfieCamera) {
            CameraCaptureView(
                position: .front,
                overlayStyle: .none,
                instruction: "Slowly turn your head to the\nRight",
                onCancel: { showSelfieCamera = false },
                onConfirm: { image in
                    selfieImage = image
                    stage = .workId
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showWorkIdCamera = true
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showWorkIdCamera) {
            CameraCaptureView(
                position: .back,
                overlayStyle: .idCard,
                instruction: "Position Work ID within\nframe",
                onCancel: { showWorkIdCamera = false },
                onConfirm: { image in
                    workIdImage = image
                }
            )
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
            }

            if totalSteps > 1 {
                VerificationProgressView(currentStep: currentStep, totalSteps: totalSteps)
            }
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

            Button(action: { stage = .workId }) {
                Text("Continue")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.loopedPrimary)
                    .clipShape(Capsule())
            }
            .disabled(selfieImage == nil)
            .opacity(selfieImage == nil ? 0.4 : 1)
            .padding(.horizontal, 32)
        }
    }

    var workIdStage: some View {
        VStack(spacing: 20) {
            Button(action: { showWorkIdCamera = true }) {
                WorkIdCardView(image: workIdImage)
            }
            .buttonStyle(PlainButtonStyle())

            Text("Position Work ID within\nframe")
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextPrimary)
                .multilineTextAlignment(.center)

            Button(action: { showWorkIdCamera = true }) {
                Text(workIdImage == nil ? "Take Work ID Photo" : "Retake Work ID Photo")
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedSecondary)
            }

            Button(action: onComplete) {
                Text("Continue")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.loopedPrimary)
                    .clipShape(Capsule())
            }
            .disabled(workIdImage == nil)
            .opacity(workIdImage == nil ? 0.4 : 1)
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
}

private enum PhotoIdStage {
    case selfie
    case workId
}

private struct WorkIdCardView: View {
    let image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.loopedWhite)
            .frame(width: 280, height: 170)
            .shadow(color: Color.loopedBlack.opacity(0.12), radius: 10, x: 0, y: 6)
            .overlay(
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Looped")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextPrimary)
                        Text("Sample Name")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextPrimary)
                        Text("Title Here")
                            .font(.loopedSmallText)
                            .foregroundColor(.loopedTextSecondary)
                    }

                    Spacer()

                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.loopedMutedBackground)
                        .frame(width: 88, height: 110)
                        .overlay(
                            Group {
                                if let image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "person.fill")
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
        onComplete: {}
    )
}
