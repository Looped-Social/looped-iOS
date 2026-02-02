import SwiftUI

struct ChatInputView: View {
    @Binding var messageText: String
    @Binding var selectedMedia: [LocalMediaItem]
    let onSendTapped: () -> Void

    @State private var showAttachmentOptions = false
    @State private var showMediaPicker = false
    @State private var showCamera = false
    
    private var mediaPickerAllowsVideo: Bool {
        selectedMedia.isEmpty
    }
    
    private var mediaPickerAppendSelection: Bool {
        let hasVideo = selectedMedia.contains(where: { $0.type == .video })
        guard !selectedMedia.isEmpty, !hasVideo else { return false }
        return selectedMedia.count < 4
    }
    
    private var mediaPickerSelectionLimit: Int {
        if mediaPickerAppendSelection {
            return max(1, 4 - selectedMedia.count)
        }
        return 4
    }
    
    private var isMediaSelectionFull: Bool {
        selectedMedia.contains(where: { $0.type == .video }) || selectedMedia.count >= 4
    }

    var body: some View {
        VStack(spacing: 0) {
            // Media preview if any
            if !selectedMedia.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedMedia) { item in
                            ZStack(alignment: .topTrailing) {
                                if let image = item.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                if item.type == .video {
                                    Circle()
                                        .fill(Color.loopedBlack.opacity(0.6))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Image(systemName: "play.fill")
                                                .font(.loopedCustom(size: 10))
                                                .foregroundColor(.loopedWhite)
                                        )
                                }

                                // Remove button
                                Button(action: {
                                    TemporaryMediaFile.deleteIfOwned(item.videoURL)
                                    selectedMedia.removeAll { $0.id == item.id }
                                }) {
                                    Circle()
                                        .fill(Color.loopedBlack.opacity(0.7))
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Image(systemName: "xmark")
                                                .font(.loopedCustom(.bold, size: 10))
                                                .foregroundColor(.loopedWhite)
                                        )
                                }
                                .padding(4)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color.loopedMutedBackground.opacity(0.5))
            }

            HStack(spacing: 12) {
                // Plus button for attachments
                Button(action: {
                    showAttachmentOptions.toggle()
                }) {
                    Image(systemName: "plus")
                        .font(.loopedCustom(.medium, size: 18))
                        .foregroundColor(.loopedPrimary)
                }
                .disabled(isMediaSelectionFull)

                // Text input field
                HStack(spacing: 8) {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1...6)
                        .textFieldStyle(PlainTextFieldStyle())

                    // Send button - show when there's text or media
                    if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedMedia.isEmpty {
                        Button(action: onSendTapped) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.loopedCustom(size: 24))
                                .foregroundColor(.loopedPrimary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.loopedMessageMutedColor)
                        .shadow(color: .loopedBlack.opacity(0.10), radius: 1, x: 0, y: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .padding(.top, 12)
        }
        .background(Color.loopedBackground)
        .safeAreaInset(edge: .bottom) {
            Color.loopedClear.frame(height: 0)
        }
        .onChange(of: selectedMedia) { _, newValue in
            let videos = newValue.filter { $0.type == .video }
            let images = newValue.filter { $0.type == .image }

            if !videos.isEmpty, !images.isEmpty {
                selectedMedia = Array(images.prefix(4))
                return
            }

            if videos.count > 1 {
                selectedMedia = [videos[0]]
                return
            }

            if images.count > 4 {
                selectedMedia = Array(images.prefix(4))
            }
        }
        .actionSheet(isPresented: $showAttachmentOptions) {
            ActionSheet(
                title: Text("Add Attachment"),
                message: Text("Choose an option"),
                buttons: [
                    .default(Text("Photo Library")) {
                        showMediaPicker = true
                    },
                    .default(Text("Camera")) {
                        showCamera = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showMediaPicker) {
            MediaPickerView(
                selectedMedia: $selectedMedia,
                maxSelectionCount: mediaPickerSelectionLimit,
                allowsVideo: mediaPickerAllowsVideo,
                appendSelection: mediaPickerAppendSelection,
                onDismiss: { showMediaPicker = false }
            )
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraMediaPickerView(selectedItem: .init(
                get: { nil },
                set: { item in
                    guard let item else { return }
                    switch item.type {
                    case .image:
                        guard !isMediaSelectionFull else { return }
                        selectedMedia.append(LocalMediaItem(type: .image, image: item.image))
                    case .video:
                        selectedMedia.forEach { TemporaryMediaFile.deleteIfOwned($0.videoURL) }
                        selectedMedia = [item]
                    case .gif:
                        break
                    }
                }
            ))
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Spacer()

        // Preview with empty text
        ChatInputView(
            messageText: .constant(""),
            selectedMedia: .constant([]),
            onSendTapped: {}
        )

        // Preview with text (showing send button)
        ChatInputView(
            messageText: .constant("This is a sample message"),
            selectedMedia: .constant([]),
            onSendTapped: {}
        )
    }
    .background(Color.loopedBackground)
}
