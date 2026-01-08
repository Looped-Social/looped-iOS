import SwiftUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var draftStore = PostDraftStore()
    @State private var postText: String = ""
    @AppStorage("anonymousMode") private var isAnonymous: Bool = false
    @State private var selectedCommunityId: Int?
    @State private var isSubmitting: Bool = false
    @State private var isEnrollingAnon: Bool = false
    @State private var selectedMedia: [LocalMediaItem] = []
    @State private var showMediaPicker: Bool = false
    @State private var showCamera: Bool = false
    @State private var anonMembershipExpired = false
    @State private var anonMembershipMissing = false
    @State private var showVerificationInfoAlert = false
    @State private var showDraftPrompt = false
    @State private var activeDraftId: UUID?
    @StateObject private var verificationViewModel = CommunityVerificationsViewModel()
    @State private var toastMessage: ToastMessage?

    @ObservedObject var feedViewModel: FeedViewModel
    private let draft: PostDraft?
    private let onPostCreated: (() -> Void)?

    init(feedViewModel: FeedViewModel, draft: PostDraft? = nil, onPostCreated: (() -> Void)? = nil) {
        self.feedViewModel = feedViewModel
        self.draft = draft
        self.onPostCreated = onPostCreated
        _postText = State(initialValue: draft?.content ?? "")
        _selectedCommunityId = State(initialValue: draft?.communityId)
        _activeDraftId = State(initialValue: draft?.id)
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
        let followed = feedViewModel.followedCommunities.filter { $0.canPost }
        let verified = verificationViewModel.items
            .filter { $0.isActive }
            .map { verification in
                CommunitySummary(
                    id: verification.communityId,
                    name: verification.communityName,
                    kind: verification.communityKind,
                    memberCount: 0,
                    isPinned: false,
                    sortOrder: nil,
                    canPost: true
                )
            }
        var merged: [CommunitySummary] = []
        var seen = Set<Int>()
        for community in followed + verified {
            if seen.insert(community.id).inserted {
                merged.append(community)
            }
        }
        return merged
    }

    private var selectedCommunity: CommunitySummary? {
        verifiedCommunities.first { $0.id == selectedCommunityId }
    }

    private var selectedCommunityName: String {
        selectedCommunity?.name ?? "Select community"
    }

    private var canPost: Bool {
        selectedCommunity != nil && (!isAnonymous || !(anonMembershipMissing || anonMembershipExpired))
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
                        HStack {
                            Text("Community")
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextSecondary)
                            Spacer()
                            Button(action: {
                                showVerificationInfoAlert = true
                            }) {
                                Image(systemName: "questionmark.circle")
                                    .font(.loopedCustom(.semibold, size: 14))
                                    .foregroundColor(.loopedTextSecondary)
                            }
                            .accessibilityLabel("Why verification is required")
                        }

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
                                        .font(.loopedCustom(.medium, size: 12))
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
                                .font(.loopedCustom(.semibold, size: 16))
                                .foregroundColor(.loopedSecondary)

                            Text(disabledPostMessage)
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
                                    .font(.loopedCustom(size: 16))
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
                                    .font(.loopedCustom(size: 16))
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
                            .foregroundColor(remainingCharacters < 20 ? .loopedError : .loopedTextSecondary)
                    }
                    
                    // Anonymous mode toggle
                    HStack(spacing: 12) {
                        Image(systemName: "theatermasks")
                            .font(.loopedCustom(size: 14))
                            .foregroundColor(.loopedTextSecondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(isAnonymous ? "Posting anonymously" : "Posting as yourself")
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextPrimary)

                            Text(isAnonymous ? "Your identity is hidden" : "Toggle to post anonymously")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        }

                        Spacer()

                        if isEnrollingAnon {
                            ProgressView()
                                .tint(.loopedSecondary)
                        }

                        Toggle("", isOn: $isAnonymous)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Color.loopedSecondary))
                            .disabled(isEnrollingAnon || (!isAnonymous && selectedCommunityId == nil))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.loopedMutedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
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
                        handleCancel()
                    }
                    .foregroundColor(.loopedSecondary)
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
        .toast($toastMessage)
        .alert("Verification Required", isPresented: $showVerificationInfoAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You need to be verified in a community to post.")
        }
        .alert("Save draft?", isPresented: $showDraftPrompt) {
            Button("Save Draft") {
                saveDraftAndDismiss()
            }
            Button("Discard", role: .destructive) {
                discardDraftAndDismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(draftPromptMessage)
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
            updateAnonMembershipStatus()
            Task { await verificationViewModel.load() }
        }
        .onChange(of: feedViewModel.selectedCommunity?.id) { _ in
            syncSelectedCommunity()
            updateAnonMembershipStatus()
        }
        .onChange(of: feedViewModel.followedCommunities) { _ in
            syncSelectedCommunity()
            updateAnonMembershipStatus()
        }
        .onChange(of: verificationViewModel.items) { _ in
            syncSelectedCommunity()
            updateAnonMembershipStatus()
        }
        .onChange(of: selectedCommunityId) { _ in
            updateAnonMembershipStatus()
        }
        .onChange(of: isAnonymous) { newValue in
            Task { await handleAnonToggle(isOn: newValue) }
            updateAnonMembershipStatus()
        }
    }
    
    @MainActor
    private func submitPost() async {
        guard let communityId = selectedCommunity?.id else { return }
        let trimmedContent = postText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        let didCreate = await feedViewModel.createPost(
            content: trimmedContent,
            isAnonymous: isAnonymous,
            communityId: communityId
        )

        if didCreate {
            if let activeDraftId {
                draftStore.delete(id: activeDraftId)
            }
            onPostCreated?()
            dismiss()
        } else {
            presentToast(message: "Post not created", kind: .error)
        }
    }

    private func syncSelectedCommunity() {
        if let selectedCommunityId,
           verifiedCommunities.contains(where: { $0.id == selectedCommunityId }) {
            return
        }
        selectedCommunityId = defaultCommunityId
    }

    private var disabledPostMessage: String {
        if isAnonymous, selectedCommunity != nil, (anonMembershipMissing || anonMembershipExpired) {
            return "Anonymous access expired for this community. Re-enroll to post."
        }
        return "Verification is required to post in a community."
    }

    private func updateAnonMembershipStatus() {
        guard isAnonymous, let communityId = selectedCommunityId else {
            anonMembershipExpired = false
            anonMembershipMissing = false
            return
        }
        Task { @MainActor in
            let membership = await AnonService.shared.membership(for: communityId)
            anonMembershipMissing = membership == nil
            anonMembershipExpired = membership?.isExpired ?? false
        }
    }

    @MainActor
    private func handleAnonToggle(isOn: Bool) async {
        guard isOn, !isEnrollingAnon else { return }
        guard let communityId = selectedCommunityId else {
            presentToast(message: "Select a community to enable anonymous mode.", kind: .error)
            isAnonymous = false
            return
        }

        isEnrollingAnon = true
        defer { isEnrollingAnon = false }

        do {
            AnonCommunityResolver.cacheSelectedCommunityId(communityId)
            _ = try await AnonService.shared.ensureIdentity(communityId: communityId)
        } catch {
            presentToast(message: error.localizedDescription, kind: .error)
            isAnonymous = false
        }
        updateAnonMembershipStatus()
    }

    private var hasDraftableContent: Bool {
        !postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var draftPromptMessage: String {
        if selectedMedia.isEmpty {
            return "Save this post so you can finish it later."
        }
        return "Only your text will be saved. Media attachments are not saved in drafts yet."
    }

    private func handleCancel() {
        guard hasDraftableContent else {
            dismiss()
            return
        }
        showDraftPrompt = true
    }

    private func saveDraftAndDismiss() {
        guard hasDraftableContent else { return }
        let draft = draftStore.upsertDraft(
            id: activeDraftId,
            content: postText,
            communityId: selectedCommunity?.id,
            communityName: selectedCommunity?.name
        )
        activeDraftId = draft.id
        dismiss()
    }

    private func discardDraftAndDismiss() {
        if let activeDraftId {
            draftStore.delete(id: activeDraftId)
        }
        dismiss()
    }

    private func presentToast(message: String, kind: ToastKind = .info) {
        withAnimation(.easeOut(duration: 0.2)) {
            toastMessage = ToastMessage(text: message, kind: kind)
        }
    }
}

#Preview {
    CreatePostView(feedViewModel: FeedViewModel())
}
