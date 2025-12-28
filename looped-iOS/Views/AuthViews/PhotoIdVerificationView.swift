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
        .sheet(isPresented: $showSelfieCamera) {
            CameraPickerView(selectedImage: $selfieImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showWorkIdCamera) {
            CameraPickerView(selectedImage: $workIdImage)
                .ignoresSafeArea()
        }
    }
}

private extension PhotoIdVerificationView {
    var header: some View {
        ZStack {
            HStack {
                Button(action: handleBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
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
            HStack(spacing: 18) {
                Button(action: { showSelfieCamera = true }) {
                    Circle()
                        .fill(Color(red: 0.86, green: 0.28, blue: 0.27))
                        .frame(width: 150, height: 150)
                        .overlay(
                            Group {
                                if let selfieImage {
                                    Image(uiImage: selfieImage)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 56, weight: .regular))
                                        .foregroundColor(.white)
                                }
                            }
                                .clipShape(Circle())
                        )
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { stage = .workId }) {
                    Circle()
                        .fill(Color.loopedMutedBackground)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.loopedTextSecondary)
                        )
                }
                .disabled(selfieImage == nil)
                .opacity(selfieImage == nil ? 0.4 : 1)
            }

            Text("Slowly turn your head to the\nRight")
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextPrimary)
                .multilineTextAlignment(.center)

            Button(action: { showSelfieCamera = true }) {
                Text(selfieImage == nil ? "Take Selfie" : "Retake Selfie")
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedSecondary)
            }
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
                Circle()
                    .stroke(Color.loopedTextSecondary.opacity(0.35), lineWidth: 4)
                    .frame(width: 64, height: 64)
            }
            .padding(.top, 4)

            if workIdImage != nil {
                Button(action: onComplete) {
                    Text("Continue")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.loopedContrast)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 32)

                Button(action: { showWorkIdCamera = true }) {
                    Text("Retake Photo")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedSecondary)
                }
            }
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
            .fill(Color.white)
            .frame(width: 280, height: 150)
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
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
                        .frame(width: 62, height: 80)
                        .overlay(
                            Group {
                                if let image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 30, weight: .regular))
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
