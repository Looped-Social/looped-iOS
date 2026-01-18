import SwiftUI
import AVFoundation
import UIKit

struct CameraCaptureView: View {
    let position: AVCaptureDevice.Position
    let overlayStyle: CameraOverlayStyle
    let instruction: String
    let onCancel: () -> Void
    let onConfirm: (UIImage) -> Void

    @StateObject private var controller = CameraCaptureController()
    @State private var bottomControlsHeight: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    
    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    private var isCameraAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        UIImagePickerController.isSourceTypeAvailable(.camera)
        #endif
    }

    var body: some View {
        ZStack {
            if isRunningInPreviews || !isCameraAvailable {
                Color.loopedBlack.ignoresSafeArea()
                overlay
                header
                VStack(spacing: 10) {
                    Text(isRunningInPreviews ? "Camera isn't available in previews." : "Camera isn't available on Simulator.")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedWhite)
                        .multilineTextAlignment(.center)
                    Text("Run on a physical device to capture photos.")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedWhite.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
            } else if controller.isAuthorized {
                CameraPreview(session: controller.session, position: position)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()

                overlay
                header

                if let image = controller.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                }
            } else {
                Color.loopedBlack.ignoresSafeArea()
            }
        }
        .readWidth { containerWidth = $0 }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if controller.isAuthorized, !isRunningInPreviews, isCameraAvailable {
                let fallbackWidth = UIScreen.main.bounds.width
                let availableWidth = max(0, (containerWidth > 0 ? containerWidth : fallbackWidth) - 48)
                let controlsWidth = min(520, availableWidth)
                HStack {
                    Spacer(minLength: 0)
                    bottomControls
                        .frame(width: controlsWidth)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .readHeight { bottomControlsHeight = $0 }
            }
        }
        .alert("Camera Error", isPresented: $controller.showErrorAlert) {
            Button("OK", role: .cancel) {
                handleCancel()
            }
        } message: {
            Text(controller.errorMessage ?? "Camera isn't available right now.")
        }
        .onAppear {
            guard !isRunningInPreviews, isCameraAvailable else { return }
            controller.configure(position: position)
            controller.start()
        }
        .onChange(of: controller.authorizationStatus) { _, newValue in
            if newValue == .denied || newValue == .restricted {
                handleCancel()
            }
        }
        .onDisappear {
            controller.stop()
        }
    }
}

private extension CameraCaptureView {
    struct HeightPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    struct WidthPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    var bottomControls: some View {
        VStack(spacing: 16) {
            if controller.capturedImage == nil {
                Text(instruction)
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedWhite)
                    .multilineTextAlignment(.center)
            }

            if controller.capturedImage == nil {
                captureButton
            } else {
                confirmButtons
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    var header: some View {
        VStack {
            HStack {
                LoopedCloseButton(
                    action: handleCancel,
                    foregroundColor: .loopedWhite,
                    iconSize: 18,
                    hitArea: 44,
                    showsBackground: true,
                    backgroundColor: .loopedBlack,
                    backgroundOpacity: 0.5
                )
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()
        }
    }

    var overlay: some View {
        GeometryReader { geometry in
            ZStack {
                if overlayStyle == .idCard {
                    let width = geometry.size.width * 0.78
                    let height = width / 1.58
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.loopedWhite.opacity(0.9), lineWidth: 2)
                        .frame(width: width, height: height)
                        .position(
                            x: geometry.size.width / 2,
                            y: max(0, (geometry.size.height - bottomControlsHeight) / 2)
                        )
                        .shadow(color: Color.loopedBlack.opacity(0.25), radius: 6, x: 0, y: 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    var captureButton: some View {
        Button(action: controller.capture) {
            ZStack {
                Circle()
                    .stroke(Color.loopedWhite.opacity(0.7), lineWidth: 4)
                    .frame(width: 74, height: 74)
                Circle()
                    .fill(Color.loopedWhite)
                    .frame(width: 58, height: 58)
            }
        }
    }

    var confirmButtons: some View {
        HStack(spacing: 16) {
            Button(action: controller.retake) {
                Text("Retake")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.loopedBlack.opacity(0.55))
                    .clipShape(Capsule())
            }

            Button(action: handleConfirm) {
                Text("Use Photo")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.loopedWhite)
                    .clipShape(Capsule())
            }
        }
    }

    func handleCancel() {
        onCancel()
    }

    func handleConfirm() {
        guard let image = controller.capturedImage else { return }
        onConfirm(image)
    }
}

private extension View {
    func readHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear.preference(key: CameraCaptureView.HeightPreferenceKey.self, value: geometry.size.height)
            }
        )
        .onPreferenceChange(CameraCaptureView.HeightPreferenceKey.self) { newValue in
            onChange(newValue)
        }
    }

    func readWidth(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear.preference(key: CameraCaptureView.WidthPreferenceKey.self, value: geometry.size.width)
            }
        )
        .onPreferenceChange(CameraCaptureView.WidthPreferenceKey.self) { newValue in
            onChange(newValue)
        }
    }
}

enum CameraOverlayStyle: Equatable {
    case none
    case idCard
}

final class CameraCaptureController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var isAuthorized = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var capturedImage: UIImage?
    @Published var errorMessage: String?
    @Published var showErrorAlert = false

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "looped.camera.session")
    private var isConfigured = false
    private var currentPosition: AVCaptureDevice.Position = .front

    func configure(position: AVCaptureDevice.Position) {
        currentPosition = position
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }

        switch status {
        case .authorized:
            isAuthorized = true
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    self?.authorizationStatus = granted ? .authorized : .denied
                }
                if granted {
                    self?.configureSession()
                }
            }
        default:
            isAuthorized = false
        }
    }

    func start() {
        sessionQueue.async {
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

	    func capture() {
	        sessionQueue.async {
	            guard self.isConfigured, self.session.isRunning else {
	                self.presentError("Camera isn't ready yet.")
	                return
	            }
	            guard !self.session.inputs.isEmpty, self.session.outputs.contains(self.output) else {
	                self.presentError("Camera couldn't be configured.")
	                return
	            }
	            let hasEnabledVideoConnection = self.output.connections.contains { connection in
	                connection.isEnabled && connection.inputPorts.contains { $0.mediaType == .video }
	            }
	            guard hasEnabledVideoConnection else {
	                self.presentError("Camera isn't available on this device.")
	                return
	            }
	            let settings = AVCapturePhotoSettings()
	            self.output.capturePhoto(with: settings, delegate: self)
	        }
	    }

    func retake() {
        capturedImage = nil
        start()
    }

    private func configureSession() {
        sessionQueue.async {
            if self.isConfigured {
                self.updateInput()
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            self.session.inputs.forEach { self.session.removeInput($0) }

            guard let input = self.makeInput() else {
                self.session.commitConfiguration()
                self.presentError("Camera isn't available on this device.")
                return
            }
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            } else {
                self.session.commitConfiguration()
                self.presentError("Camera couldn't be configured.")
                return
            }

            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }

            self.session.commitConfiguration()
            self.isConfigured = true
            self.session.startRunning()
        }
    }

    private func updateInput() {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        guard let input = makeInput(), session.canAddInput(input) else {
            session.commitConfiguration()
            presentError("Camera isn't available on this device.")
            return
        }
        session.addInput(input)
        session.commitConfiguration()
    }

    private func makeInput() -> AVCaptureDeviceInput? {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else {
            return nil
        }
        return try? AVCaptureDeviceInput(device: device)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            return
        }

        DispatchQueue.main.async {
            self.capturedImage = image
        }
        stop()
    }

    private func presentError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showErrorAlert = true
        }
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let position: AVCaptureDevice.Position

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        guard let connection = uiView.previewLayer.connection else { return }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = position == .front
        }
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}

#Preview {
    CameraCaptureView(
        position: .front,
        overlayStyle: .none,
        instruction: "Position your face clearly in the frame",
        onCancel: {},
        onConfirm: { _ in }
    )
}
