import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MediaPickerView: UIViewControllerRepresentable {
    @Binding var selectedMedia: [LocalMediaItem]
    let maxSelectionCount: Int
    let allowsVideo: Bool
    let appendSelection: Bool
    let onDismiss: (() -> Void)?

    init(
        selectedMedia: Binding<[LocalMediaItem]>,
        maxSelectionCount: Int = 4,
        allowsVideo: Bool = true,
        appendSelection: Bool = false,
        onDismiss: (() -> Void)? = nil
    ) {
        self._selectedMedia = selectedMedia
        self.maxSelectionCount = maxSelectionCount
        self.allowsVideo = allowsVideo
        self.appendSelection = appendSelection
        self.onDismiss = onDismiss
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = maxSelectionCount

        if allowsVideo {
            configuration.filter = .any(of: [.images, .videos])
        } else {
            configuration.filter = .images
        }

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MediaPickerView

        init(_ parent: MediaPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true) {
                self.parent.onDismiss?()
            }

            guard !results.isEmpty else { return }

            var mediaItems: [LocalMediaItem] = []
            let group = DispatchGroup()

            for result in results {
                group.enter()

                // Check if it's a video
                if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                        guard let url = url, error == nil else {
                            group.leave()
                            return
                        }

                        // Copy the file to a temporary location
                        let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                        let tempURL = TemporaryMediaFile.makeURL(extension: ext)
                        try? FileManager.default.copyItem(at: url, to: tempURL)
                        if url.standardizedFileURL.path.hasPrefix(FileManager.default.temporaryDirectory.standardizedFileURL.path) {
                            try? FileManager.default.removeItem(at: url)
                        }

                        Task(priority: .utility) {
                            let thumbnail = await VideoAssetUtilities.thumbnail(for: tempURL)
                            let duration = await VideoAssetUtilities.duration(for: tempURL)
                            let mediaItem = LocalMediaItem(
                                type: .video,
                                image: thumbnail,
                                videoURL: tempURL,
                                duration: duration
                            )
                            await MainActor.run {
                                mediaItems.append(mediaItem)
                            }
                            group.leave()
                        }
                    }
                } else {
                    // It's an image
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                        guard let image = object as? UIImage, error == nil else {
                            group.leave()
                            return
                        }

                        let mediaItem = LocalMediaItem(
                            type: .image,
                            image: image
                        )
                        Task { @MainActor in
                            mediaItems.append(mediaItem)
                            group.leave()
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                if self.parent.appendSelection {
                    self.parent.selectedMedia.append(contentsOf: mediaItems)
                } else {
                    self.parent.selectedMedia = mediaItems
                }
            }
        }
    }
}

// MARK: - Camera Picker
struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.modalPresentationStyle = .fullScreen
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedMedia: [LocalMediaItem] = []
        @State private var showPicker = false

        var body: some View {
            VStack {
                Button("Select Media") {
                    showPicker = true
                }

                if !selectedMedia.isEmpty {
                    Text("\(selectedMedia.count) items selected")
                }
            }
            .sheet(isPresented: $showPicker) {
                MediaPickerView(selectedMedia: $selectedMedia)
            }
        }
    }

    return PreviewWrapper()
}

// MARK: - Camera Media Picker (photo + video)
struct CameraMediaPickerView: UIViewControllerRepresentable {
    @Binding var selectedItem: LocalMediaItem?
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.modalPresentationStyle = .fullScreen
        picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraMediaPickerView

        init(_ parent: CameraMediaPickerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer { parent.presentationMode.wrappedValue.dismiss() }

            let mediaType = info[.mediaType] as? String
            if mediaType == UTType.movie.identifier {
                guard let url = info[.mediaURL] as? URL else { return }
                let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                let tempURL = TemporaryMediaFile.makeURL(extension: ext)
                try? FileManager.default.copyItem(at: url, to: tempURL)

                Task(priority: .utility) {
                    let thumbnail = await VideoAssetUtilities.thumbnail(for: tempURL)
                    let duration = await VideoAssetUtilities.duration(for: tempURL)
                    await MainActor.run {
                        parent.selectedItem = LocalMediaItem(
                            type: .video,
                            image: thumbnail,
                            videoURL: tempURL,
                            duration: duration
                        )
                    }
                }
                return
            }

            if mediaType == UTType.image.identifier || mediaType == "public.image" {
                if let image = info[.originalImage] as? UIImage {
                    parent.selectedItem = LocalMediaItem(type: .image, image: image)
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }

    }
}
