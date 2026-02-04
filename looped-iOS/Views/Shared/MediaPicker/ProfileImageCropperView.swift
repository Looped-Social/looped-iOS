import SwiftUI
import UIKit

struct ProfileImageCropperView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onConfirm: (UIImage) -> Void

    @State private var cropSide: CGFloat = 0
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Move and scale")
                    .font(.loopedSubheadMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .padding(.top, 8)

                GeometryReader { geometry in
                    let side = min(geometry.size.width, geometry.size.height)
                    let baseScale = baseScale(for: side)
                    let maxOffset = maxOffsets(for: side, totalScale: baseScale * scale)

                    ZStack {
                        Color.loopedBackground

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: side, height: side)
                            .scaleEffect(scale)
                            .offset(clampedOffset(maxOffset: maxOffset))
                            .clipped()
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = clampOffset(
                                            CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            ),
                                            maxOffset: maxOffset
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                            .simultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = clampScale(lastScale * value)
                                        let updatedMaxOffset = maxOffsets(for: side, totalScale: baseScale * scale)
                                        offset = clampOffset(offset, maxOffset: updatedMaxOffset)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        let updatedMaxOffset = maxOffsets(for: side, totalScale: baseScale * scale)
                                        offset = clampOffset(offset, maxOffset: updatedMaxOffset)
                                        lastOffset = offset
                                    }
                            )

                        Circle()
                            .stroke(Color.loopedContrast.opacity(0.9), lineWidth: 2)
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.loopedTextSecondary.opacity(0.15), radius: 10, x: 0, y: 6)
                    .onAppear {
                        cropSide = side
                        let initialMaxOffset = maxOffsets(for: side, totalScale: baseScale * scale)
                        offset = clampOffset(offset, maxOffset: initialMaxOffset)
                        lastOffset = offset
                    }
                    .onChange(of: geometry.size) { _, _ in
                        cropSide = side
                        let updatedMaxOffset = maxOffsets(for: side, totalScale: baseScale * scale)
                        offset = clampOffset(offset, maxOffset: updatedMaxOffset)
                        lastOffset = offset
                    }
                }
                .frame(height: 360)
                .padding(.horizontal, 20)

                VStack(spacing: 10) {
                    HStack {
                        Text("Zoom")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                        Spacer()
                        Text("\(Int(scale * 100))%")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                    }

                    Slider(value: $scale, in: 1...4, step: 0.01) {
                        Text("Zoom")
                    }
                    .labelsHidden()
                    .tint(.loopedPrimary)
                    .onChange(of: scale) { _, newValue in
                        scale = clampScale(newValue)
                        let base = baseScale(for: cropSide)
                        let updatedMaxOffset = maxOffsets(for: cropSide, totalScale: base * scale)
                        offset = clampOffset(offset, maxOffset: updatedMaxOffset)
                        lastOffset = offset
                        lastScale = scale
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(.loopedSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        guard cropSide > 0, let cropped = cropImage(cropSide: cropSide) else {
                            onCancel()
                            return
                        }
                        onConfirm(cropped)
                    }
                    .foregroundColor(.loopedSecondary)
                }
            }
        }
    }
}

private extension ProfileImageCropperView {
    func clampScale(_ value: CGFloat) -> CGFloat {
        min(4, max(1, value))
    }

    func baseScale(for cropSide: CGFloat) -> CGFloat {
        guard cropSide > 0, image.size.width > 0, image.size.height > 0 else { return 1 }
        return max(cropSide / image.size.width, cropSide / image.size.height)
    }

    func maxOffsets(for cropSide: CGFloat, totalScale: CGFloat) -> CGSize {
        guard cropSide > 0 else { return .zero }
        let displayedWidth = image.size.width * totalScale
        let displayedHeight = image.size.height * totalScale
        return CGSize(
            width: max(0, (displayedWidth - cropSide) / 2),
            height: max(0, (displayedHeight - cropSide) / 2)
        )
    }

    func clampOffset(_ value: CGSize, maxOffset: CGSize) -> CGSize {
        CGSize(
            width: min(maxOffset.width, max(-maxOffset.width, value.width)),
            height: min(maxOffset.height, max(-maxOffset.height, value.height))
        )
    }

    func clampedOffset(maxOffset: CGSize) -> CGSize {
        clampOffset(offset, maxOffset: maxOffset)
    }

    func cropImage(cropSide: CGFloat) -> UIImage? {
        let source = image.normalizedOrientation()
        guard let cgImage = source.cgImage, cropSide > 0 else { return nil }

        let base = baseScale(for: cropSide)
        let totalScale = base * scale
        guard totalScale > 0 else { return nil }

        let maxOffset = maxOffsets(for: cropSide, totalScale: totalScale)
        let clamped = clampOffset(offset, maxOffset: maxOffset)

        let displayedWidth = source.size.width * totalScale
        let displayedHeight = source.size.height * totalScale

        let originXInDisplayed = (displayedWidth - cropSide) / 2 - clamped.width
        let originYInDisplayed = (displayedHeight - cropSide) / 2 - clamped.height

        let cropXPoints = originXInDisplayed / totalScale
        let cropYPoints = originYInDisplayed / totalScale
        let cropSizePoints = cropSide / totalScale

        let pixelsPerPointX = CGFloat(cgImage.width) / source.size.width
        let pixelsPerPointY = CGFloat(cgImage.height) / source.size.height

        var cropRect = CGRect(
            x: cropXPoints * pixelsPerPointX,
            y: cropYPoints * pixelsPerPointY,
            width: cropSizePoints * pixelsPerPointX,
            height: cropSizePoints * pixelsPerPointY
        ).integral

        let imageBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        cropRect = cropRect.intersection(imageBounds)
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }

        return UIImage(cgImage: cropped, scale: source.scale, orientation: .up)
    }
}

struct NavigationPopGestureDisabler: UIViewControllerRepresentable {
    let isEnabled: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let navigationController = uiViewController.navigationController else { return }
        if context.coordinator.originalValue == nil {
            context.coordinator.originalValue = navigationController.interactivePopGestureRecognizer?.isEnabled
        }
        navigationController.interactivePopGestureRecognizer?.isEnabled = isEnabled
    }

    func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        guard let navigationController = uiViewController.navigationController else { return }
        if let originalValue = coordinator.originalValue {
            navigationController.interactivePopGestureRecognizer?.isEnabled = originalValue
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var originalValue: Bool?
    }
}

