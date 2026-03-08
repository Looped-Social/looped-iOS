import SwiftUI
import UIKit

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var draftStore: PostDraftStore
    @State private var postText: String = ""
    @FocusState private var isPostTextFocused: Bool
    @AppStorage("anonymousMode") private var isAnonymous: Bool = false
    @AppStorage(LinkPreviewSettings.appStorageKey) private var linkPreviewsEnabled = LinkPreviewSettings.defaultEnabled
    @Environment(\.preferCommunityShortNames) private var preferCommunityShortNames
    @State private var selectedCommunityId: Int?
    @State private var isSubmitting: Bool = false
    @State private var isEnrollingAnon: Bool = false
    @State private var selectedMedia: [LocalMediaItem] = []
    @State private var showMediaPicker: Bool = false
    @State private var showCamera: Bool = false
    @State private var pollDraft: PollDraft?
    @State private var anonMembershipExpired = false
    @State private var anonMembershipMissing = false
    @State private var isRefreshingAnonMembership = false
    @State private var showVerificationInfoAlert = false
    @State private var showDraftPrompt = false
    @State private var activeDraftId: UUID?
    @State private var postableCommunities: [CommunitySummary] = []
    @State private var isLoadingPostableCommunities = false
    @State private var postableCommunitiesError: String?
    @State private var toastMessage: ToastMessage?
    @State private var mentionSuggestions: [User] = []
    @State private var isLoadingMentionSuggestions = false
    @State private var mentionQuery: String?
    @State private var mentionSearchTask: Task<Void, Never>?
    @State private var attachedLinkURL: URL?
    @State private var isUpdatingPostTextInternally = false

    @ObservedObject var feedViewModel: FeedViewModel
    private let communityService: CommunityServiceProtocol
    private let userService: UserServiceProtocol
    private let draft: PostDraft?
    private let prefillText: String?
    private let onPostCreated: (() -> Void)?
    private let onPostStatus: ((ToastMessage) -> Void)?

    init(
        feedViewModel: FeedViewModel,
        communityService: CommunityServiceProtocol = CommunityService(),
        userService: UserServiceProtocol = UserService(),
        draftStore: PostDraftStore = PostDraftStore(),
        draft: PostDraft? = nil,
        prefillText: String? = nil,
        onPostCreated: (() -> Void)? = nil,
        onPostStatus: ((ToastMessage) -> Void)? = nil
    ) {
        self.feedViewModel = feedViewModel
        self.communityService = communityService
        self.userService = userService
        self.draftStore = draftStore
        self.draft = draft
        self.prefillText = prefillText
        self.onPostCreated = onPostCreated
        self.onPostStatus = onPostStatus
        _postText = State(initialValue: draft?.content ?? prefillText ?? "")
        _selectedCommunityId = State(initialValue: draft?.communityId)
        _activeDraftId = State(initialValue: draft?.id)
        _pollDraft = State(initialValue: draft?.poll)
    }
    
    private var characterLimit: Int { 500 }
    private var submissionContent: String {
        Self.composeContent(text: postText, linkURL: attachedLinkURL)
    }
    private var remainingCharacters: Int { characterLimit - submissionContent.count }
    private var isPostValid: Bool {
        let hasText = !submissionContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = !selectedMedia.isEmpty
        let hasValidPoll = pollDraft?.isValid ?? false
        let isTextValid = submissionContent.count <= characterLimit
        return (hasText || hasMedia || hasValidPoll) && isTextValid
    }
    private var selectedCommunity: CommunitySummary? {
        postableCommunities.first { $0.id == selectedCommunityId }
    }

    private var selectedCommunityName: String {
        guard let selectedCommunity else { return "Select community" }
        return CommunityLabelText.preferredName(
            preferShortNames: preferCommunityShortNames,
            name: selectedCommunity.name,
            shortName: selectedCommunity.shortName
        ) ?? selectedCommunity.name
    }

    private var canPost: Bool {
        (selectedCommunity?.canPost ?? false) && (!isAnonymous || !(anonMembershipMissing || anonMembershipExpired))
    }
    private var composerPreviewURL: URL? {
        guard linkPreviewsEnabled else { return nil }
        return attachedLinkURL
    }

	    private var mediaPickerAllowsVideo: Bool {
	        selectedMedia.isEmpty && pollDraft == nil
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

    private var defaultCommunityId: Int? {
        if let lastId = feedViewModel.lastPostedCommunityId,
           postableCommunities.contains(where: { $0.id == lastId }) {
            return lastId
        }
        if let selectedId = feedViewModel.selectedCommunity?.id,
           postableCommunities.contains(where: { $0.id == selectedId }) {
            return selectedId
        }
        return postableCommunities.first?.id
    }

    private var shouldShowMentionSuggestions: Bool {
        isPostTextFocused && (isLoadingMentionSuggestions || !mentionSuggestions.isEmpty)
    }
    
	    var body: some View {
	        NavigationStack {
	            ScrollView {
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

                        if isLoadingPostableCommunities, postableCommunities.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(.loopedSecondary)
                                Text("Loading communities…")
                                    .font(.loopedBody)
                                    .foregroundColor(.loopedTextSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.loopedMutedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if let postableCommunitiesError, !postableCommunitiesError.isEmpty, postableCommunities.isEmpty {
                            HStack {
                                Text(postableCommunitiesError)
                                    .font(.loopedBody)
                                    .foregroundColor(.loopedError)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.loopedMutedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if postableCommunities.isEmpty {
                            HStack {
                                Text("No communities to post in yet")
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
                                ForEach(postableCommunities) { community in
                                    Button(CommunityLabelText.preferredName(
                                        preferShortNames: preferCommunityShortNames,
                                        name: community.name,
                                        shortName: community.shortName
                                    ) ?? community.name) {
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
                            VerifiedBadgeIcon(tint: .loopedSecondary, size: 16)

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
                        HStack(spacing: 8) {
                            Text("What's happening?")
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextSecondary)

                            Spacer()

                            Text("\(remainingCharacters) characters left")
                                .font(.loopedSmallText)
                                .foregroundColor(remainingCharacters < 20 ? .loopedError : .loopedTextSecondary)
                        }

                        TextField("Share your thoughts...", text: $postText, axis: .vertical)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .focused($isPostTextFocused)
                            .lineLimit(6...10)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.loopedMutedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        if shouldShowMentionSuggestions {
                            mentionSuggestionsSection
                        }
                    }

                    if let composerPreviewURL {
                        ZStack(alignment: .topTrailing) {
                            NativeLinkPreviewView(url: composerPreviewURL, style: .composer)
                            Button(action: removeAttachedLink) {
                                ZStack {
                                    Circle()
                                        .fill(Color.loopedBlack.opacity(0.55))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "xmark")
                                        .font(.loopedCustom(.semibold, size: 16))
                                        .foregroundColor(.loopedWhite)
                                }
                                .padding(8)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove link preview")
                        }
                    }

                    // Media attachment buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            isPostTextFocused = false
                            showMediaPicker = true
	                        }) {
	                            HStack(spacing: 6) {
	                                Image(systemName: "photo")
	                                    .font(.loopedCustom(size: 16))
	                                Text("Photo")
                                    .font(.loopedSubBodyMedium)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .minimumScaleFactor(0.85)
                                    .allowsTightening(true)
                            }
                            .foregroundColor(.loopedContrast)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
	                            .background(Color.loopedMutedBackground)
	                            .clipShape(RoundedRectangle(cornerRadius: 8))
	                        }

	                        Button(action: {
	                            isPostTextFocused = false
	                            showCamera = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "camera")
                                    .font(.loopedCustom(size: 16))
                                Text("Camera")
                                    .font(.loopedSubBodyMedium)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .minimumScaleFactor(0.85)
                                    .allowsTightening(true)
                            }
                            .foregroundColor(.loopedContrast)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
	                            .background(Color.loopedMutedBackground)
	                            .clipShape(RoundedRectangle(cornerRadius: 8))
	                        }

                        Button(action: togglePoll) {
                            HStack(spacing: 6) {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.loopedCustom(size: 16))
                                Text(pollDraft == nil ? "Poll" : "Remove Poll")
                                    .font(.loopedSubBodyMedium)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .minimumScaleFactor(0.75)
                                    .allowsTightening(true)
                            }
                            .foregroundColor(.loopedContrast)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.loopedMutedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    if let pollDraftBinding = bindingForPollDraft() {
                        PollComposerCard(
                            pollDraft: pollDraftBinding,
                            onRemove: { pollDraft = nil }
                        )
                    }

                    // Media preview grid
                    if !selectedMedia.isEmpty {
                        MediaPreviewStrip(media: selectedMedia) { item in
                            TemporaryMediaFile.deleteIfOwned(item.videoURL)
                            selectedMedia.removeAll { $0.id == item.id }
                        }
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
	                }
	                .padding()
	                .frame(maxWidth: .infinity, alignment: .leading)
	            }
	            .scrollDismissesKeyboard(.interactively)
	            .background(Color.loopedBackground.ignoresSafeArea())
	            .navigationTitle("New Post")
	            .navigationBarTitleDisplayMode(.inline)
	            .navigationBarBackButtonHidden(true)
	            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    LoopedCancelTextButton(action: handleCancel)
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
        .toast($toastMessage)
        .alert("Verification Required", isPresented: $showVerificationInfoAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You need to be verified in a community to post, comment, or like.")
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
        .loopedInteractiveDismissDisabled(hasDraftableContent, onAttemptToDismiss: handleCancel)
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
                            let newItem = LocalMediaItem(type: .image, image: item.image)
                            if selectedMedia.contains(where: { $0.type == .video }) || selectedMedia.count >= 4 {
                                selectedMedia.forEach { TemporaryMediaFile.deleteIfOwned($0.videoURL) }
                                selectedMedia = [newItem]
                                presentToast(message: "Replaced attachments (max 4 photos).", kind: .info)
                            } else {
                                selectedMedia.append(newItem)
                            }
                        case .video:
                            selectedMedia.forEach { TemporaryMediaFile.deleteIfOwned($0.videoURL) }
                            selectedMedia = [item]
                        case .gif:
                            break
                        }
                    }
                ))
        }
        .onAppear {
            applySharedPrefillIfNeeded()
            syncAttachedLinkFromTextIfNeeded()
            syncSelectedCommunity()
            updateAnonMembershipStatus(autoEnroll: true)
            Task { await loadPostableCommunities() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .communityStateChanged)) { _ in
            Task { await loadPostableCommunities() }
        }
        .onChange(of: feedViewModel.selectedCommunity?.id) { _, _ in
            syncSelectedCommunity()
            updateAnonMembershipStatus(autoEnroll: true)
        }
        .onChange(of: feedViewModel.followedCommunities) { _, _ in
            syncSelectedCommunity()
            updateAnonMembershipStatus(autoEnroll: true)
        }
        .onChange(of: selectedMedia) { _, newValue in
            let videos = newValue.filter { $0.type == .video }
            let images = newValue.filter { $0.type == .image }

            if !videos.isEmpty, !images.isEmpty {
                selectedMedia = Array(images.prefix(4))
                presentToast(message: "You can’t mix photos and video. Keeping photos.", kind: .info)
                return
            }

            if videos.count > 1 {
                selectedMedia = [videos[0]]
                presentToast(message: "Attach up to 1 video.", kind: .info)
                return
            }

            if images.count > 4 {
                selectedMedia = Array(images.prefix(4))
                presentToast(message: "Attach up to 4 photos.", kind: .info)
            }
        }
        .onChange(of: selectedCommunityId) { _, _ in
            updateAnonMembershipStatus(autoEnroll: true)
        }
        .onChange(of: isAnonymous) { _, newValue in
            Task { await handleAnonToggle(isOn: newValue) }
            updateAnonMembershipStatus(autoEnroll: newValue)
        }
        .onChange(of: postText) { _, _ in
            syncAttachedLinkFromTextIfNeeded()
            queueMentionLookup()
        }
        .onChange(of: linkPreviewsEnabled) { _, isEnabled in
            guard !isEnabled else {
                syncAttachedLinkFromTextIfNeeded()
                return
            }
            if let attachedLinkURL {
                postText = Self.composeContent(text: postText, linkURL: attachedLinkURL)
                self.attachedLinkURL = nil
            }
        }
        .onChange(of: isPostTextFocused) { _, focused in
            if focused {
                queueMentionLookup()
            } else {
                clearMentionSuggestions()
            }
        }
        .onDisappear {
            mentionSearchTask?.cancel()
        }
    }

    private func applySharedPrefillIfNeeded() {
        guard draft == nil else { return }
        guard prefillText == nil else { return }
        guard postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let sharedPrefill = SharedPostPrefillStore.loadComposedText() else { return }
        postText = sharedPrefill
        SharedPostPrefillStore.clearPending()
    }

    private func syncAttachedLinkFromTextIfNeeded() {
        guard linkPreviewsEnabled else { return }
        guard attachedLinkURL == nil else { return }
        guard !isUpdatingPostTextInternally else { return }
        guard let url = LoopedTextParser.firstURL(in: postText) else { return }

        let textWithoutURL = LoopedTextParser
            .removingFirstURL(from: postText)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        isUpdatingPostTextInternally = true
        attachedLinkURL = url
        postText = textWithoutURL
        isUpdatingPostTextInternally = false
    }

    private func removeAttachedLink() {
        attachedLinkURL = nil
    }

    private static func composeContent(text: String, linkURL: URL?) -> String {
        guard let linkURL else { return text }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            return linkURL.absoluteString
        }
        return "\(trimmedText)\n\n\(linkURL.absoluteString)"
    }

    private var mentionSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoadingMentionSuggestions {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.loopedSecondary)
                    Text("Finding people…")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            } else {
                ForEach(mentionSuggestions.prefix(6)) { user in
                    Button(action: { applyMentionSuggestion(user) }) {
                        HStack(spacing: 10) {
                            ProfileAvatarView(
                                imageURL: user.profileImageURL,
                                size: 30,
                                variant: .standard
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(resolvedMentionDisplayName(for: user))
                                    .font(.loopedSubBodyMedium)
                                    .foregroundColor(.loopedTextPrimary)
                                    .lineLimit(1)

                                Text("@\(user.handle)")
                                    .font(.loopedSmallText)
                                    .foregroundColor(.loopedTextSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.loopedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.loopedTextSecondary.opacity(0.15), lineWidth: 1)
        )
    }
    
    @MainActor
    private func submitPost() async {
        guard !isSubmitting else { return }
        guard let communityId = selectedCommunity?.id else { return }
        let trimmedContent = submissionContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let pollToSend = pollDraft?.isValid == true ? pollDraft : nil
        guard !trimmedContent.isEmpty || !selectedMedia.isEmpty || pollToSend != nil else { return }
        isPostTextFocused = false

        isSubmitting = true

        let contentToSend = trimmedContent
        let mediaToSend = selectedMedia
        let pollDraftToSend = pollToSend
        let isAnonymousToSend = isAnonymous
        let activeDraftIdToCleanup = activeDraftId
        let communityName = selectedCommunity?.name

        let initialToast = mediaToSend.isEmpty
            ? ToastMessage(text: "Posting…", kind: .loading)
            : ToastMessage(text: "Uploading…", kind: .loading)
        onPostStatus?(initialToast)
        onPostCreated?()
        dismiss()

        Task {
            let result = await feedViewModel.createPost(
                content: contentToSend,
                isAnonymous: isAnonymousToSend,
                communityId: communityId,
                media: mediaToSend,
                poll: pollDraftToSend,
                onStatus: { status in
                    onPostStatus?(status)
                }
            )

            await MainActor.run {
                isSubmitting = false
                if result == .created || result == .createdUnderReview || result == .queuedForReview {
                    NotificationCenter.default.post(name: .profileRefreshRequested, object: nil)
                    if let activeDraftIdToCleanup {
                        draftStore.delete(id: activeDraftIdToCleanup)
                    }
                    if result == .createdUnderReview {
                        onPostStatus?(ToastMessage(text: "Posted (under review)", kind: .success))
                    } else if result == .created {
                        onPostStatus?(ToastMessage(text: "Post created", kind: .success))
                    } else if result == .queuedForReview {
                        onPostStatus?(ToastMessage(text: "Under review", kind: .info))
                    }
                } else {
                    var savedDraftId: UUID?
                    if let activeDraftIdToCleanup {
                        savedDraftId = activeDraftIdToCleanup
                        if !contentToSend.isEmpty || pollDraftToSend != nil {
                            _ = draftStore.upsertDraft(
                                id: activeDraftIdToCleanup,
                                content: contentToSend,
                                communityId: communityId,
                                communityName: communityName,
                                poll: pollDraftToSend
                            )
                        }
                    } else if !contentToSend.isEmpty || pollDraftToSend != nil {
                        let draft = draftStore.upsertDraft(
                            id: nil,
                            content: contentToSend,
                            communityId: communityId,
                            communityName: communityName,
                            poll: pollDraftToSend
                        )
                        savedDraftId = draft.id
                    }

                    let message: String
                    if savedDraftId != nil {
                        message = "Couldn't post. Saved to Drafts (media not saved)."
                    } else {
                        message = feedViewModel.errorMessage ?? "Couldn't post. Try again."
                    }
                    onPostStatus?(ToastMessage(text: message, kind: .error))
                }
            }
        }
    }

    private func syncSelectedCommunity() {
        if let selectedCommunityId,
           postableCommunities.contains(where: { $0.id == selectedCommunityId }) {
            return
        }
        selectedCommunityId = defaultCommunityId
    }

    @MainActor
    private func loadPostableCommunities() async {
        if isLoadingPostableCommunities { return }
        isLoadingPostableCommunities = true
        defer { isLoadingPostableCommunities = false }

        do {
            postableCommunities = try await communityService.fetchPostableCommunities()
            postableCommunitiesError = nil
        } catch {
            postableCommunitiesError = error.localizedDescription
        }
        syncSelectedCommunity()
        updateAnonMembershipStatus(autoEnroll: true)
    }

    private var disabledPostMessage: String {
        if isAnonymous, selectedCommunity != nil, anonMembershipMissing {
            return "Anonymous access isn't enabled for this community yet. Re-enroll to post, comment, or like."
        }
        if isAnonymous, selectedCommunity != nil, anonMembershipExpired {
            return "Anonymous access expired for this community. Re-enroll to post, comment, or like."
        }
        if let selectedCommunity {
            let displayName = CommunityLabelText.preferredName(
                preferShortNames: preferCommunityShortNames,
                name: selectedCommunity.name,
                shortName: selectedCommunity.shortName
            ) ?? selectedCommunity.name
            return "You aren’t verified in \(displayName). Verify to post, comment, or like."
        }
        return "Verification is required to post, comment, or like in this community."
    }

    private func updateAnonMembershipStatus(autoEnroll: Bool = false) {
        guard isAnonymous, let communityId = selectedCommunityId else {
            anonMembershipExpired = false
            anonMembershipMissing = false
            return
        }
        if autoEnroll, isRefreshingAnonMembership { return }
        Task { @MainActor in
            var membership = await AnonService.shared.membership(for: communityId)
            if autoEnroll,
               (membership == nil || membership?.isExpired == true),
               !isEnrollingAnon,
               !isRefreshingAnonMembership {
                isRefreshingAnonMembership = true
                defer { isRefreshingAnonMembership = false }
                do {
                    AnonCommunityResolver.cacheSelectedCommunityId(communityId)
                    _ = try await AnonService.shared.ensureIdentity(communityId: communityId)
                    membership = await AnonService.shared.membership(for: communityId)
                } catch {
                    presentToast(message: error.localizedDescription, kind: .error)
                }
            }
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
        updateAnonMembershipStatus(autoEnroll: false)
    }

    private var hasDraftableContent: Bool {
        CreatePostDraftPromptPolicy.shouldPromptForDraft(content: submissionContent, poll: pollDraft)
    }

	    private var draftPromptMessage: String {
	        if selectedMedia.isEmpty {
	            return "Save this post so you can finish it later."
	        }
	        return "Only your text will be saved. Media attachments are not saved in drafts yet."
	    }

    private func handleCancel() {
        guard hasDraftableContent else {
            cleanupSelectedMedia()
            dismiss()
            return
        }
        showDraftPrompt = true
    }

    private func saveDraftAndDismiss() {
        guard hasDraftableContent else { return }
        let draft = draftStore.upsertDraft(
            id: activeDraftId,
            content: submissionContent,
            communityId: selectedCommunity?.id,
            communityName: selectedCommunity?.name,
            poll: pollDraft
        )
        activeDraftId = draft.id
        cleanupSelectedMedia()
        dismiss()
    }

    private func discardDraftAndDismiss() {
        if let activeDraftId {
            draftStore.delete(id: activeDraftId)
        }
        cleanupSelectedMedia()
        dismiss()
    }

    private func presentToast(message: String, kind: ToastKind = .info) {
        withAnimation(.easeOut(duration: 0.2)) {
            toastMessage = ToastMessage(text: message, kind: kind)
        }
    }

	    private func togglePoll() {
	        isPostTextFocused = false
	        if pollDraft == nil {
	            pollDraft = PollDraft(maxSelections: 1)
	        } else {
	            pollDraft = nil
	        }
	    }

    private func cleanupSelectedMedia() {
        for item in selectedMedia {
            TemporaryMediaFile.deleteIfOwned(item.videoURL)
        }
    }

    private func bindingForPollDraft() -> Binding<PollDraft>? {
        guard pollDraft != nil else { return nil }
        return Binding(
            get: { pollDraft ?? PollDraft() },
            set: { pollDraft = $0 }
        )
    }

    private func queueMentionLookup() {
        mentionSearchTask?.cancel()
        guard isPostTextFocused else {
            clearMentionSuggestions()
            return
        }

        guard let trigger = currentMentionTrigger(in: postText), !trigger.query.isEmpty else {
            clearMentionSuggestions()
            return
        }

        mentionQuery = trigger.query
        isLoadingMentionSuggestions = true

        mentionSearchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }

            do {
                let page = try await userService.searchUsers(query: trigger.query, limit: 20, cursor: nil)
                guard !Task.isCancelled else { return }

                let matches = rankedMentionMatches(users: page.users, query: trigger.query)
                await MainActor.run {
                    guard mentionQuery == trigger.query else { return }
                    mentionSuggestions = matches
                    isLoadingMentionSuggestions = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard mentionQuery == trigger.query else { return }
                    mentionSuggestions = []
                    isLoadingMentionSuggestions = false
                }
            }
        }
    }

    private func clearMentionSuggestions() {
        mentionSearchTask?.cancel()
        mentionSearchTask = nil
        mentionQuery = nil
        mentionSuggestions = []
        isLoadingMentionSuggestions = false
    }

    private func resolvedMentionDisplayName(for user: User) -> String {
        let trimmed = (user.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? user.handle : trimmed
    }

    private func applyMentionSuggestion(_ user: User) {
        guard let trigger = currentMentionTrigger(in: postText) else { return }
        let cleanHandle = normalizedMentionValue(user.handle)
        guard !cleanHandle.isEmpty else { return }
        postText.replaceSubrange(trigger.range, with: "@\(cleanHandle) ")
        isPostTextFocused = true
        clearMentionSuggestions()
    }

    private func rankedMentionMatches(users: [User], query: String) -> [User] {
        let normalizedQuery = normalizedMentionValue(query)

        let uniqueUsers = Dictionary(grouping: users, by: { $0.backendId })
            .compactMap { $0.value.first }

        return uniqueUsers
            .map { user -> (user: User, score: Int, handle: String) in
                let handle = normalizedMentionValue(user.handle)
                let username = normalizedMentionValue(user.username ?? "")
                let score: Int
                if handle == normalizedQuery || username == normalizedQuery {
                    score = 0
                } else if handle.hasPrefix(normalizedQuery) || username.hasPrefix(normalizedQuery) {
                    score = 1
                } else if handle.contains(normalizedQuery) || username.contains(normalizedQuery) {
                    score = 2
                } else {
                    score = 3
                }
                return (user: user, score: score, handle: handle)
            }
            .filter { $0.score < 3 }
            .sorted {
                if $0.score != $1.score { return $0.score < $1.score }
                return $0.handle < $1.handle
            }
            .map { $0.user }
    }

    private func currentMentionTrigger(in text: String) -> MentionTrigger? {
        guard !text.isEmpty else { return nil }

        let endIndex = text.endIndex
        guard let atIndex = text.lastIndex(of: "@") else { return nil }

        // Only trigger when mention token is at the end of the current text.
        let mentionRange = atIndex..<endIndex
        let mentionToken = String(text[mentionRange])
        guard !mentionToken.contains(where: { $0.isWhitespace }) else { return nil }

        // Require token boundary before '@' to avoid emails (foo@bar.com).
        if atIndex > text.startIndex {
            let previous = text[text.index(before: atIndex)]
            if previous.isLetter || previous.isNumber || previous == "_" {
                return nil
            }
        }

        let rawQuery = String(mentionToken.dropFirst())
        guard !rawQuery.isEmpty else { return nil }
        guard rawQuery.unicodeScalars.allSatisfy({ mentionAllowedCharacters.contains($0) }) else { return nil }

        let normalized = normalizedMentionValue(rawQuery)
        guard !normalized.isEmpty else { return nil }

        return MentionTrigger(query: normalized, range: mentionRange)
    }

    private func normalizedMentionValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var mentionAllowedCharacters: CharacterSet {
        CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
    }
}

private extension CreatePostView {
    struct MentionTrigger {
        let query: String
        let range: Range<String.Index>
    }
}

enum CreatePostDraftPromptPolicy {
    static func shouldPromptForDraft(content: String, poll: PollDraft?) -> Bool {
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        guard let poll else { return false }
        if !poll.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return poll.options.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

private struct LoopedInteractiveDismissableView<T: View>: UIViewControllerRepresentable {
    let view: T
    let isDisabled: Bool
    let onAttemptToDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIHostingController<T> {
        UIHostingController(rootView: view)
    }

    func updateUIViewController(_ uiViewController: UIHostingController<T>, context: Context) {
        context.coordinator.isDisabled = isDisabled
        context.coordinator.onAttemptToDismiss = onAttemptToDismiss
        uiViewController.rootView = view
        applyDelegateIfPossible(for: uiViewController, coordinator: context.coordinator)
        DispatchQueue.main.async {
            applyDelegateIfPossible(for: uiViewController, coordinator: context.coordinator)
        }
    }

    private func applyDelegateIfPossible(
        for uiViewController: UIHostingController<T>,
        coordinator: Coordinator
    ) {
        if let presentationController = uiViewController.parent?.presentationController {
            presentationController.delegate = coordinator
            coordinator.observedPresentationController = presentationController
            return
        }

        if let presentationController = uiViewController.presentationController {
            presentationController.delegate = coordinator
            coordinator.observedPresentationController = presentationController
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isDisabled: isDisabled, onAttemptToDismiss: onAttemptToDismiss)
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var isDisabled: Bool
        var onAttemptToDismiss: () -> Void
        weak var observedPresentationController: UIPresentationController?

        init(isDisabled: Bool, onAttemptToDismiss: @escaping () -> Void) {
            self.isDisabled = isDisabled
            self.onAttemptToDismiss = onAttemptToDismiss
        }

        deinit {
            if observedPresentationController?.delegate === self {
                observedPresentationController?.delegate = nil
            }
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            !isDisabled
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            onAttemptToDismiss()
        }
    }
}

private extension View {
    func loopedInteractiveDismissDisabled(
        _ isDisabled: Bool = true,
        onAttemptToDismiss: @escaping () -> Void
    ) -> some View {
        LoopedInteractiveDismissableView(
            view: self,
            isDisabled: isDisabled,
            onAttemptToDismiss: onAttemptToDismiss
        )
    }
}

#Preview {
    CreatePostView(feedViewModel: FeedViewModel(), draftStore: PostDraftStore())
}
