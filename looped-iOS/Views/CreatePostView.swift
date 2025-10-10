import SwiftUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var postText: String = ""
    @AppStorage("anonymousMode") private var isAnonymous: Bool = false
    @State private var selectedChannel: String = "General"
    @State private var isSubmitting: Bool = false
    @State private var showSettings: Bool = false
    @State private var selectedMedia: [LocalMediaItem] = []
    @State private var showMediaPicker: Bool = false
    @State private var showCamera: Bool = false

    let feedViewModel: FeedViewModel
    
    let channels = ["General", "Random", "Work", "Announcements"]
    
    private var characterLimit: Int { 280 }
    private var remainingCharacters: Int { characterLimit - postText.count }
    private var isPostValid: Bool {
        let hasText = !postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = !selectedMedia.isEmpty
        let isTextValid = postText.count <= characterLimit
        return (hasText || hasMedia) && isTextValid
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top navigation bar
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.loopedTextSecondary)
                    .font(.loopedBody)
                    
                    Spacer()
                    
                    Text("New Post")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                    
                    Spacer()
                    
                    Button("Post") {
                        Task {
                            await submitPost()
                        }
                    }
                    .disabled(!isPostValid || isSubmitting)
                    .foregroundColor((isPostValid && !isSubmitting) ? .loopedPrimary : .loopedTextSecondary)
                    .font(.loopedBodyMedium)
                }
                .padding()
                .background(Color.loopedBackground.ignoresSafeArea(.all, edges: .top))
                
                // Divider
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.loopedTextSecondary.opacity(0.1))
                
                // Main content
                VStack(alignment: .leading, spacing: 16) {
                    // Channel selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Channel")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                        
                        Menu {
                            ForEach(channels, id: \.self) { channel in
                                Button(channel) {
                                    selectedChannel = channel
                                }
                            }
                        } label: {
                            HStack {
                                Text("# \(selectedChannel)")
                                    .font(.loopedBody)
                                    .foregroundColor(.loopedTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.loopedTextSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.loopedMutedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // Text input area
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's happening?")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextSecondary)

                        TextField("Share your thoughts...", text: $postText, axis: .vertical)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .lineLimit(6...10)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.loopedMutedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Media attachment buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            showMediaPicker = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "photo")
                                    .font(.system(size: 16))
                                Text("Photo/Video")
                                    .font(.loopedSubBodyMedium)
                            }
                            .foregroundColor(.loopedPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.loopedMutedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Button(action: {
                            showCamera = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "camera")
                                    .font(.system(size: 16))
                                Text("Camera")
                                    .font(.loopedSubBodyMedium)
                            }
                            .foregroundColor(.loopedPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.loopedMutedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Spacer()
                    }

                    // Media preview grid
                    if !selectedMedia.isEmpty {
                        MediaPreviewGrid(
                            media: selectedMedia,
                            maxHeight: 280,
                            onRemove: { item in
                                selectedMedia.removeAll { $0.id == item.id }
                            }
                        )
                    }

                    // Character count
                    HStack {
                        Spacer()
                        Text("\(remainingCharacters)")
                            .font(.loopedSmallText)
                            .foregroundColor(remainingCharacters < 20 ? .red : .loopedTextSecondary)
                    }
                    
                    // Anonymous mode indicator
                    Button(action: {
                        showSettings = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "theatermasks")
                                        .font(.system(size: 14))
                                        .foregroundColor(.loopedTextSecondary)

                                    Text(isAnonymous ? "Posting anonymously" : "Posting as yourself")
                                        .font(.loopedSubBodyMedium)
                                        .foregroundColor(.loopedTextPrimary)
                                }

                                Text(isAnonymous ? "Your identity is hidden" : "Tap to change in settings")
                                    .font(.loopedSmallText)
                                    .foregroundColor(.loopedTextSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.loopedMutedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .padding()
                .background(Color.loopedBackground.ignoresSafeArea(.all, edges: .bottom))
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showMediaPicker) {
            MediaPickerView(selectedMedia: $selectedMedia, maxSelectionCount: 4)
        }
        .sheet(isPresented: $showCamera) {
            CameraPickerView(selectedImage: .init(
                get: { nil },
                set: { image in
                    if let image = image {
                        selectedMedia.append(LocalMediaItem(type: .image, image: image))
                    }
                }
            ))
        }
    }
    
    private func submitPost() async {
        guard !postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSubmitting = true
        
        await feedViewModel.createPost(
            content: postText.trimmingCharacters(in: .whitespacesAndNewlines),
            isAnonymous: isAnonymous,
            channel: selectedChannel
        )
        
        isSubmitting = false
        dismiss()
    }
}

#Preview {
    CreatePostView(feedViewModel: FeedViewModel())
}