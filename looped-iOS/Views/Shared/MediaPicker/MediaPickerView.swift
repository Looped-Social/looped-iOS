import SwiftUI
import PhotosUI

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
                        defer { group.leave() }

                        guard let url = url, error == nil else { return }

                        // Copy the file to a temporary location
                        let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                        let tempURL = TemporaryMediaFile.makeURL(extension: ext)
                        try? FileManager.default.copyItem(at: url, to: tempURL)
                        if url.standardizedFileURL.path.hasPrefix(FileManager.default.temporaryDirectory.standardizedFileURL.path) {
                            try? FileManager.default.removeItem(at: url)
                        }

                        // Generate thumbnail
                        let thumbnail = self.generateVideoThumbnail(url: tempURL)
                        let duration = self.getVideoDuration(url: tempURL)

                        let mediaItem = LocalMediaItem(
                            type: .video,
                            image: thumbnail,
                            videoURL: tempURL,
                            duration: duration
                        )
                        mediaItems.append(mediaItem)
                    }
                } else {
                    // It's an image
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                        defer { group.leave() }

                        guard let image = object as? UIImage, error == nil else { return }

                        let mediaItem = LocalMediaItem(
                            type: .image,
                            image: image
                        )
                        mediaItems.append(mediaItem)
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

        private func generateVideoThumbnail(url: URL) -> UIImage? {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true

            do {
                let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
                return UIImage(cgImage: cgImage)
            } catch {
                return nil
            }
        }

        private func getVideoDuration(url: URL) -> TimeInterval {
            let asset = AVAsset(url: url)
            return CMTimeGetSeconds(asset.duration)
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

import AVFoundation

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
