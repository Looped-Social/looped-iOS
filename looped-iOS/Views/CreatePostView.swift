import SwiftUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var postText: String = ""
    @AppStorage("anonymousMode") private var isAnonymous: Bool = false
    @State private var selectedCommunityId: Int?
    @State private var isSubmitting: Bool = false
    @State private var showSettings: Bool = false
    @State private var selectedMedia: [LocalMediaItem] = []
    @State private var showMediaPicker: Bool = false
    @State private var showCamera: Bool = false

    @ObservedObject var feedViewModel: FeedViewModel

    init(feedViewModel: FeedViewModel) {
        self.feedViewModel = feedViewModel
    }
    
    private var characterLimit: Int { 280 }
    private var remainingCharacters: Int { characterLimit - postText.count }
    private var isPostValid: Bool {
        let hasText = !postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = !selectedMedia.isEmpty
        let isTextValid = postText.count <= characterLimit
        return (hasText || hasMedia) && isTextValid
    }
    private var verifiedCommunities: [CommunitySummary] {
        feedViewModel.followedCommunities.filter { $0.canPost }
    }

    private var selectedCommunity: CommunitySummary? {
        verifiedCommunities.first { $0.id == selectedCommunityId }
    }

    private var selectedCommunityName: String {
        selectedCommunity?.name ?? "Select community"
    }

    private var canPost: Bool {
        selectedCommunity != nil
    }

    private var defaultCommunityId: Int? {
        if let lastId = feedViewModel.lastPostedCommunityId,
           verifiedCommunities.contains(where: { $0.id == lastId }) {
            return lastId
        }
        if let selected = feedViewModel.selectedCommunity, selected.canPost {
            return selected.id
        }
        return verifiedCommunities.first?.id
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main content
                VStack(alignment: .leading, spacing: 16) {
                    // Community selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Community")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextSecondary)

                        if verifiedCommunities.isEmpty {
                            HStack {
                                Text("No verified communities yet")
                                    .font(.loopedBody)
                                    .foregroundColor(.loopedTextSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.loopedMutedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Menu {
                                ForEach(verifiedCommunities) { community in
                                    Button(community.name) {
                                        selectedCommunityId = community.id
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedCommunityName)
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
                    }

                    if !canPost {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.loopedSecondary)

                            Text("Verification is required to post in a community.")
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.loopedMutedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.loopedPrimary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        Task {
                            await submitPost()
                        }
                    }
                    .disabled(!isPostValid || isSubmitting || !canPost)
                    .foregroundColor((isPostValid && !isSubmitting && canPost) ? .loopedPrimary : .loopedTextSecondary)
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authViewModel)
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
        .onAppear {
            syncSelectedCommunity()
        }
        .onChange(of: feedViewModel.selectedCommunity?.id) { _ in
            syncSelectedCommunity()
        }
        .onChange(of: feedViewModel.followedCommunities) { _ in
            syncSelectedCommunity()
        }
    }
    
    private func submitPost() async {
        guard let communityId = selectedCommunity?.id else { return }
        guard !postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSubmitting = true
        
        await feedViewModel.createPost(
            content: postText.trimmingCharacters(in: .whitespacesAndNewlines),
            isAnonymous: isAnonymous,
            communityId: communityId
        )
        
        isSubmitting = false
        dismiss()
    }

    private func syncSelectedCommunity() {
        if let selectedCommunityId,
           verifiedCommunities.contains(where: { $0.id == selectedCommunityId }) {
            return
        }
        selectedCommunityId = defaultCommunityId
    }
}

#Preview {
    CreatePostView(feedViewModel: FeedViewModel())
        .environmentObject(AuthViewModel())
}
