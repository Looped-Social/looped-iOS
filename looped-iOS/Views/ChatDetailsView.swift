import SwiftUI
import Foundation
import UIKit
import PhotosUI

struct ChatDetailsView: View {
    let conversation: Conversation?
    let channel: Channel?
    let onChatShouldClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("anonymousMode") private var isAnonymousMode = false

    @State private var groupName: String
    @State private var editedGroupName: String
    @State private var isUpdatingGroupName = false
    @State private var isMuted = false
    @State private var isSyncingMuteState = false
    @State private var isUpdatingMute = false
    @FocusState private var isGroupNameFocused: Bool
    @State private var showAddMembers = false
    @State private var showLeaveGroupAlert = false
    @State private var showDeleteGroupAlert = false
    @State private var showBlockUserAlert = false
    @State private var currentMemberIds: [UUID]
    @State private var members: [ChannelMember] = []
    @State private var isLoadingMembers = false
    @State private var toastMessage: ToastMessage?
    @State private var memberPendingRemoval: ChannelMember?
    @State private var isLeavingGroup = false
    @State private var isDeletingGroup = false
    @State private var isBlockingUser = false
    @State private var selectedGroupPhoto: PhotosPickerItem?
    @State private var pendingGroupPhotoCropImage: UIImage?
    @State private var isShowingGroupPhotoCropper = false
    @State private var isUpdatingGroupPhoto = false
    @State private var groupPhotoPreview: UIImage?
    @State private var groupPhotoUrlOverride: String?? = nil

    private let messageService: MessageServiceProtocol = MessageService()
    private let blockService: BlockServiceProtocol = BlockService()
    private let mediaService: MediaServiceProtocol = MediaService()

    private var isGroupChat: Bool {
        return channel != nil
    }

    private var canEditGroupName: Bool {
        channel?.viewerCanManageMembers ?? false
    }

    private var canEditGroupPhoto: Bool {
        canEditGroupName
    }

    private var effectiveGroupPhotoUrl: String? {
        groupPhotoUrlOverride ?? channel?.photoUrl
    }

    private enum MuteTarget: Equatable {
        case conversation(Int)
        case channel(Int)
    }

    private var muteTarget: MuteTarget? {
        if let channel {
            return .channel(channel.backendId)
        }
        if let conversation {
            return .conversation(conversation.backendId)
        }
        return nil
    }

    private var chatTitle: String {
        if let channel = channel {
            return channel.name
        } else if let conversation = conversation {
            return conversation.userName
        } else {
            return "Chat"
        }
    }

    private var profileUserBackendId: Int? {
        guard !isGroupChat, let conversation = conversation else { return nil }
        return conversation.backendUserId ?? conversation.userId.backendInt
    }

    private var memberCount: Int {
        if isGroupChat, !members.isEmpty {
            return members.count
        }
        return channel?.memberCount ?? currentMemberIds.count
    }

    private var isCurrentUserOwner: Bool {
        guard let currentUserId = authViewModel.currentUser?.backendId else { return false }
        if let ownerUserId = channel?.ownerUserId {
            return ownerUserId == currentUserId
        }
        return members.first(where: { $0.isOwner })?.backendUserId == currentUserId
    }

    init(conversation: Conversation?, channel: Channel?, onChatShouldClose: (() -> Void)? = nil) {
        self.conversation = conversation
        self.channel = channel
        self.onChatShouldClose = onChatShouldClose

        // Initialize member IDs
        let ids = conversation?.memberIds ?? []
        _currentMemberIds = State(initialValue: ids)

        // Initialize state with current values
        if let channel = channel {
            _groupName = State(initialValue: channel.name)
            _editedGroupName = State(initialValue: channel.name)
        } else if let conversation = conversation {
            _groupName = State(initialValue: "")
            _editedGroupName = State(initialValue: "")
        } else {
            _groupName = State(initialValue: "")
            _editedGroupName = State(initialValue: "")
        }

        _isMuted = State(initialValue: conversation?.isMuted ?? false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Section
                    VStack(spacing: 16) {
                        // Large profile photo
                        ZStack(alignment: .bottomTrailing) {
                            if isGroupChat {
                                Group {
                                    if let groupPhotoPreview {
                                        Image(uiImage: groupPhotoPreview)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    } else {
                                        GroupAvatarView(name: groupName, photoUrl: effectiveGroupPhotoUrl, size: 120)
                                    }
                                }
                            } else {
                                ProfileAvatarView(
                                    imageURL: conversation?.userProfileImageUrl,
                                    size: 120,
                                    iconScale: 0.4
                                )
                            }

                            if isGroupChat, canEditGroupPhoto {
                                PhotosPicker(selection: $selectedGroupPhoto, matching: .images) {
                                    Circle()
                                        .fill(Color.loopedPrimary)
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Group {
                                                if isUpdatingGroupPhoto {
                                                    ProgressView()
                                                        .tint(.loopedWhite)
                                                } else {
                                                    Image(systemName: "camera.fill")
                                                        .font(.loopedCustom(size: 16))
                                                        .foregroundColor(.loopedWhite)
                                                }
                                            }
                                        )
                                }
                                .disabled(isUpdatingGroupPhoto)
                                .onChange(of: selectedGroupPhoto) { _, newValue in
                                    Task { await handleGroupPhotoSelection(newValue) }
                                }
                                .offset(x: -5, y: -5)
                            }
                        }

                        // Name section
                        if isGroupChat {
                            if canEditGroupName {
                                HStack(spacing: 8) {
                                    TextField("Group name", text: $editedGroupName)
                                        .font(.loopedHeadingMedium)
                                        .foregroundColor(.loopedTextPrimary)
                                        .multilineTextAlignment(.center)
                                        .textFieldStyle(.plain)
                                        .focused($isGroupNameFocused)
                                        .submitLabel(.done)
                                        .disabled(isUpdatingGroupName)
                                        .onSubmit {
                                            Task { await saveGroupNameIfNeeded() }
                                        }
                                        .frame(maxWidth: .infinity)

                                    Button(action: { isGroupNameFocused = true }) {
                                        if isUpdatingGroupName {
                                            ProgressView()
                                                .tint(.loopedPrimary)
                                        } else {
                                            Image(systemName: "pencil")
                                                .font(.loopedCustom(size: 18))
                                                .foregroundColor(.loopedPrimary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .loopedTapTarget(minSize: 44)
                                    .disabled(isUpdatingGroupName)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 24)
                            } else {
                                Text(groupName)
                                    .font(.loopedHeadingMedium)
                                    .foregroundColor(.loopedTextPrimary)
                            }

                            Text("\(memberCount) members")
                                .font(.loopedBody)
                                .foregroundColor(.loopedTextSecondary)
                        } else {
                            Text(conversation?.userName ?? "Unknown")
                                .font(.loopedHeadingMedium)
                                .foregroundColor(.loopedTextPrimary)
                        }
                    }
                    .padding(.top, 20)

                    if isGroupChat {
                        membersSection
                    }

                    // Actions Section
                    VStack(spacing: 0) {
                        if isGroupChat {
                            // Group actions
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                showAddMembers = true
                            }) {
                                ChatDetailsActionRow(
                                    icon: "person.badge.plus",
                                    title: "Add Members"
                                )
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 60)
                        } else {
                            // 1-on-1 actions
                            if let backendId = profileUserBackendId {
                                NavigationLink(destination: UserProfileView(userId: backendId)) {
                                    ChatDetailsActionRow(
                                        icon: "person.circle",
                                        title: "View Profile",
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            Divider().padding(.leading, 60)
                        }

                        ChatDetailsToggleRow(
                            icon: "bell.slash",
                            title: "Mute Notifications",
                            isOn: $isMuted
                        )
                        .disabled(muteTarget == nil || isUpdatingMute || (isAnonymousMode && !isGroupChat))

                        if !isGroupChat {
                            Divider().padding(.leading, 60)

                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                showBlockUserAlert = true
                            }) {
                                ChatDetailsActionRow(
                                    icon: "hand.raised",
                                    title: "Block User",
                                    textColor: .loopedError
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isBlockingUser)
                        }
                    }
                    .background(Color.loopedTextSecondary.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)

                    // Danger Zone
                    if isGroupChat {
                        Button(action: {
                            if isCurrentUserOwner {
                                showDeleteGroupAlert = true
                            } else {
                                showLeaveGroupAlert = true
                            }
                        }) {
                            Text(isCurrentUserOwner ? "Delete Group" : "Leave Group")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedError)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.loopedTextSecondary.opacity(0.05))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .disabled(isLeavingGroup || isDeletingGroup)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationTitle(isGroupChat ? "Group Info" : "Contact Info")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.loopedSecondary)
                }
            }
        }
        .toast($toastMessage)
        .onAppear {
            syncMutedStateFromStore()
        }
        .onChange(of: isMuted) { oldValue, newValue in
            guard !isSyncingMuteState else { return }
            Task { await handleMuteToggle(from: oldValue, to: newValue) }
        }
        .sheet(isPresented: $showAddMembers) {
            NewMessageView(
                onChatSelected: { _, _ in },
                channelToAddMembers: channel
            )
        }
        .sheet(isPresented: $isShowingGroupPhotoCropper) {
            if let pendingGroupPhotoCropImage {
                ProfileImageCropperView(
                    image: pendingGroupPhotoCropImage,
                    onCancel: {
                        isShowingGroupPhotoCropper = false
                        self.pendingGroupPhotoCropImage = nil
                        selectedGroupPhoto = nil
                    },
                    onConfirm: { cropped in
                        let prepared = cropped.normalizedOrientation().resized(maxDimension: 1024)
                        groupPhotoPreview = prepared
                        isShowingGroupPhotoCropper = false
                        self.pendingGroupPhotoCropImage = nil
                        selectedGroupPhoto = nil
                        Task { await uploadGroupPhoto(prepared) }
                    }
                )
            } else {
                EmptyView()
            }
        }
        .alert("Delete Group", isPresented: $showDeleteGroupAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteGroup() }
            }
        } message: {
            Text("Delete this group for everyone? This can’t be undone.")
        }
        .alert("Leave Group", isPresented: $showLeaveGroupAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                Task { await leaveGroup() }
            }
        } message: {
            Text("Are you sure you want to leave this group?")
        }
        .alert("Block User", isPresented: $showBlockUserAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                Task { await blockUser() }
            }
        } message: {
            Text("Are you sure you want to block this user? They won't be able to message you.")
        }
        .alert("Remove Member", isPresented: Binding(get: { memberPendingRemoval != nil }, set: { if !$0 { memberPendingRemoval = nil } })) {
            Button("Cancel", role: .cancel) { memberPendingRemoval = nil }
            Button("Remove", role: .destructive) {
                Task {
                    if let member = memberPendingRemoval {
                        await removeMember(member)
                    }
                    memberPendingRemoval = nil
                }
            }
        } message: {
            Text("Remove this member from the group?")
        }
        .task {
            if let channel {
                await loadMembers(channelBackendId: channel.backendId)
            }
        }
    }

    private func syncMutedStateFromStore() {
        guard let muteTarget else { return }
        isSyncingMuteState = true
        defer { isSyncingMuteState = false }
        switch muteTarget {
        case .conversation(let id):
            isMuted = MutedChatStore.shared.isConversationMuted(id)
        case .channel(let id):
            isMuted = MutedChatStore.shared.isChannelMuted(id)
        }
    }

    private func handleMuteToggle(from oldValue: Bool, to newValue: Bool) async {
        guard let muteTarget else {
            await revertMuteToggle(to: false, message: "This chat can’t be muted yet.")
            return
        }

        if isAnonymousMode && !isGroupChat {
            await revertMuteToggle(to: oldValue, message: "Mute isn’t available in anonymous mode.")
            return
        }

        switch muteTarget {
        case .conversation(let id):
            isUpdatingMute = true
            defer { isUpdatingMute = false }
            do {
                let persisted = try await messageService.updateConversationPreferences(conversationId: id, muted: newValue)
                MutedChatStore.shared.setConversationMuted(persisted, conversationId: id)
                toastMessage = ToastMessage(text: persisted ? "Notifications muted" : "Notifications unmuted", kind: .success)
                if persisted != newValue {
                    await revertMuteToggle(to: persisted, message: nil)
                }
            } catch {
                await revertMuteToggle(to: oldValue, message: userFacingMuteError(error))
            }
        case .channel(let id):
            isUpdatingMute = true
            defer { isUpdatingMute = false }
            do {
                let persisted = try await messageService.updateChannelPreferences(channelBackendId: id, muted: newValue)
                MutedChatStore.shared.setChannelMuted(persisted, channelId: id)
                toastMessage = ToastMessage(text: persisted ? "Notifications muted" : "Notifications unmuted", kind: .success)
                if persisted != newValue {
                    await revertMuteToggle(to: persisted, message: nil)
                }
            } catch {
                await revertMuteToggle(to: oldValue, message: userFacingMuteError(error))
            }
        }
    }

    @MainActor
    private func revertMuteToggle(to value: Bool, message: String?) {
        isSyncingMuteState = true
        isMuted = value
        isSyncingMuteState = false
        if let message, !message.isEmpty {
            toastMessage = ToastMessage(text: message, kind: .info)
        }
    }

    private func userFacingMuteError(_ error: Error) -> String {
        if case let APIError.apiError(_, code, _) = error {
            switch code {
            case "anonymous_not_allowed":
                return "Mute isn’t available in anonymous mode."
            case "forbidden":
                return "You can’t mute this chat."
            case "not_found":
                return "This chat no longer exists."
            case "user_not_provisioned":
                return "Messaging isn’t ready yet. Try again."
            default:
                return code
            }
        }
        return error.localizedDescription
    }

    @MainActor
    private func saveGroupNameIfNeeded() async {
        guard canEditGroupName, let channel else { return }

        let trimmed = editedGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            editedGroupName = groupName
            toastMessage = ToastMessage(text: "Group name can’t be empty.", kind: .info)
            return
        }
        guard trimmed != groupName else { return }

        isUpdatingGroupName = true
        defer { isUpdatingGroupName = false }

        do {
            try await messageService.updateChannel(channelBackendId: channel.backendId, name: trimmed)
            groupName = trimmed
            editedGroupName = trimmed
            toastMessage = ToastMessage(text: "Group name updated", kind: .success)
            NotificationCenter.default.post(
                name: Foundation.Notification.Name("ChatChannelUpdated"),
                object: nil,
                userInfo: [
                    "channelBackendId": channel.backendId,
                    "name": trimmed
                ]
            )
        } catch {
            editedGroupName = groupName
            toastMessage = ToastMessage(text: error.localizedDescription, kind: .error)
        }
    }

    @MainActor
    private func handleGroupPhotoSelection(_ newValue: PhotosPickerItem?) async {
        guard canEditGroupPhoto else { return }
        guard let newValue else { return }
        do {
            guard let data = try await newValue.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                toastMessage = ToastMessage(text: "Couldn't read that photo. Try another one.", kind: .error)
                return
            }
            pendingGroupPhotoCropImage = image.normalizedOrientation().resized(maxDimension: 1024)
            isShowingGroupPhotoCropper = true
        } catch {
            toastMessage = ToastMessage(text: "Couldn't load that photo. Try another one.", kind: .error)
        }
    }

    @MainActor
    private func uploadGroupPhoto(_ image: UIImage) async {
        guard canEditGroupPhoto, let channel else { return }
        guard !isUpdatingGroupPhoto else { return }

        guard let payload = makeUploadPayload(from: image) else {
            groupPhotoPreview = nil
            toastMessage = ToastMessage(text: "That photo couldn’t be uploaded. Try another one.", kind: .error)
            return
        }

        isUpdatingGroupPhoto = true
        defer { isUpdatingGroupPhoto = false }

        do {
            let asset = try await mediaService.uploadImage(
                data: payload.data,
                mimeType: payload.mimeType,
                width: payload.width,
                height: payload.height
            )
            let updatedChannel = try await messageService.updateChannelPhoto(
                channelBackendId: channel.backendId,
                photoMediaAssetId: asset.id
            )
            groupPhotoUrlOverride = .some(updatedChannel.photoUrl)
            if updatedChannel.photoUrl != nil {
                groupPhotoPreview = nil
            }
            toastMessage = ToastMessage(text: "Group photo updated", kind: .success)
            NotificationCenter.default.post(
                name: Foundation.Notification.Name("ChatChannelUpdated"),
                object: nil,
                userInfo: [
                    "channelBackendId": channel.backendId,
                    "photoUrl": updatedChannel.photoUrl ?? NSNull()
                ]
            )
        } catch {
            groupPhotoPreview = nil
            toastMessage = ToastMessage(text: userFacingGroupPhotoError(error), kind: .error)
        }
    }

    private struct ImageUploadPayload {
        let data: Data
        let mimeType: String
        let width: Int
        let height: Int
    }

    private func makeUploadPayload(from image: UIImage) -> ImageUploadPayload? {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)

        if imageHasAlpha(image), let pngData = image.pngData() {
            return ImageUploadPayload(data: pngData, mimeType: "image/png", width: width, height: height)
        }

        if let jpegData = image.jpegData(compressionQuality: 0.85) {
            return ImageUploadPayload(data: jpegData, mimeType: "image/jpeg", width: width, height: height)
        }

        return nil
    }

    private func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let alphaInfo = image.cgImage?.alphaInfo else { return false }
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }

    private func userFacingGroupPhotoError(_ error: Error) -> String {
        if case let APIError.apiError(_, apiError, message) = error {
            switch apiError {
            case "user_not_provisioned":
                return "Messaging isn’t ready yet. Try again."
            case "anonymous_not_allowed":
                return "Group photos aren’t available in anonymous mode."
            case "forbidden":
                return "You don’t have permission to edit this group."
            case "not_found":
                return "This group could not be found."
            case "media_asset_not_found":
                return "That photo couldn't be found. Try uploading again."
            case "media_asset_forbidden":
                return "That photo isn't linked to your account. Try uploading again."
            case "invalid_channel_photo":
                return "That file isn't a supported image type."
            default:
                if let message, !message.isEmpty {
                    return message
                }
                return apiError
            }
        }
        return error.localizedDescription
    }

    @ViewBuilder
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Members")
                    .font(.loopedSubheadMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                if isLoadingMembers {
                    ProgressView()
                        .tint(.loopedTextSecondary)
                }
            }
            .padding(.horizontal, 16)

            if members.isEmpty, !isLoadingMembers {
                Text("Members are unavailable right now.")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(members) { member in
                        ChannelMemberRow(
                            member: member,
                            viewerCanManageMembers: channel?.viewerCanManageMembers ?? false,
                            isCurrentUser: member.backendUserId == authViewModel.currentUser?.backendId,
                            onRemove: {
                                memberPendingRemoval = member
                            }
                        )

                        if member.id != members.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(Color.loopedTextSecondary.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
        }
    }

    private func loadMembers(channelBackendId: Int) async {
        guard !isLoadingMembers else { return }
        isLoadingMembers = true
        defer { isLoadingMembers = false }

        do {
            let page = try await messageService.getChannelMembers(channelBackendId: channelBackendId, cursor: nil)
            members = page.members
        } catch {
            toastMessage = ToastMessage(text: error.localizedDescription, kind: .error)
        }
    }

    private func removeMember(_ member: ChannelMember) async {
        guard let channel else { return }
        do {
            try await messageService.removeChannelMember(channelBackendId: channel.backendId, userId: member.backendUserId)
            members.removeAll { $0.backendUserId == member.backendUserId }
            toastMessage = ToastMessage(text: "Removed member", kind: .success)
        } catch {
            toastMessage = ToastMessage(text: error.localizedDescription, kind: .error)
        }
    }

    private func leaveGroup() async {
        guard let channel else { return }
        guard let currentUserId = authViewModel.currentUser?.backendId else {
            toastMessage = ToastMessage(text: "Sign in again to leave this group.", kind: .error)
            return
        }
        guard !isCurrentUserOwner else {
            toastMessage = ToastMessage(text: "Owners can’t leave a group. Delete it instead.", kind: .info)
            return
        }

        isLeavingGroup = true
        defer { isLeavingGroup = false }

        do {
            try await messageService.removeChannelMember(channelBackendId: channel.backendId, userId: currentUserId)
            toastMessage = ToastMessage(text: "Left group", kind: .success)
            dismiss()
            onChatShouldClose?()
        } catch {
            let message: String
            if case let APIError.apiError(_, apiError, _) = error, apiError == "forbidden" {
                message = "Owners can’t leave a group. Delete it instead."
            } else {
                message = error.localizedDescription
            }
            toastMessage = ToastMessage(text: message, kind: .error)
        }
    }

    private func deleteGroup() async {
        guard let channel else { return }
        guard let currentUserId = authViewModel.currentUser?.backendId else {
            toastMessage = ToastMessage(text: "Sign in again to delete this group.", kind: .error)
            return
        }
        guard isCurrentUserOwner else {
            toastMessage = ToastMessage(text: "Only the group owner can delete it.", kind: .info)
            return
        }
        guard !isDeletingGroup else { return }

        isDeletingGroup = true
        defer { isDeletingGroup = false }

        do {
            try await messageService.deleteChannel(channelBackendId: channel.backendId)
            toastMessage = ToastMessage(text: "Group deleted", kind: .success)
            MutedChatStore.shared.setChannelMuted(false, channelId: channel.backendId)
            NotificationCenter.default.post(
                name: Foundation.Notification.Name("ChatChannelDeleted"),
                object: nil,
                userInfo: [
                    "channelBackendId": channel.backendId,
                    "deletedByUserId": currentUserId
                ]
            )
            dismiss()
            onChatShouldClose?()
        } catch {
            toastMessage = ToastMessage(text: userFacingGroupDeleteError(error), kind: .error)
        }
    }

    private func userFacingGroupDeleteError(_ error: Error) -> String {
        if case let APIError.apiError(_, apiError, message) = error {
            switch apiError {
            case "user_not_provisioned":
                return "Messaging isn’t ready yet. Try again."
            case "anonymous_not_allowed":
                return "You must use your verified profile to delete this group."
            case "forbidden":
                return "You don’t have permission to delete this group."
            case "not_found":
                return "This group could not be found."
            default:
                if let message, !message.isEmpty {
                    return message
                }
                return apiError
            }
        }
        return error.localizedDescription
    }

    private func blockUser() async {
        guard let targetUserId = profileUserBackendId else { return }

        isBlockingUser = true
        defer { isBlockingUser = false }

        do {
            _ = try await blockService.blockUser(userId: targetUserId, asAnonymousActor: isAnonymousMode, communityId: nil)
            toastMessage = ToastMessage(text: "Blocked user", kind: .success)
            dismiss()
            onChatShouldClose?()
        } catch {
            toastMessage = ToastMessage(text: error.localizedDescription, kind: .error)
        }
    }
}

private struct ChannelMemberRow: View {
    let member: ChannelMember
    let viewerCanManageMembers: Bool
    let isCurrentUser: Bool
    let onRemove: () -> Void

    var body: some View {
        NavigationLink(destination: UserProfileView(userId: member.backendUserId)) {
            HStack(spacing: 12) {
                ProfileAvatarView(imageURL: member.profileImageUrl, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(member.displayName ?? member.handle)
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextPrimary)

                        if member.isOwner {
                            Text("Owner")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        } else if member.canManageMembers {
                            Text("Admin")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        } else if isCurrentUser {
                            Text("(You)")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        }
                    }

                    Text("@\(member.handle)")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                if viewerCanManageMembers, !isCurrentUser, !member.isOwner {
                    Button(action: onRemove) {
                        Text("Remove")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedError)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Row
struct ChatDetailsActionRow: View {
    let icon: String
    let title: String
    var textColor: Color = .loopedTextPrimary
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.loopedCustom(.medium, size: 20))
                .foregroundColor(.loopedPrimary)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.loopedBodyMedium)
                .foregroundColor(textColor)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.loopedCustom(.semibold, size: 14))
                    .foregroundColor(.loopedTextSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Toggle Row
struct ChatDetailsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.loopedCustom(.medium, size: 20))
                .foregroundColor(.loopedPrimary)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color.loopedSecondary))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Group Member Details View
struct GroupMemberDetailsView: View {
    let profile: UserProfile
    let onRemove: ((UUID) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.preferCommunityShortNames) private var preferCommunityShortNames

    @State private var customNickname: String
    @State private var showImagePicker = false
    @State private var showBlockUserAlert = false
    @State private var showRemoveMemberAlert = false
    @State private var selectedImage: UIImage? = nil
    @State private var isMuted = false
    @State private var toastMessage: ToastMessage?
    @AppStorage("anonymousMode") private var isAnonymousMode = false

    private let blockService: BlockServiceProtocol = BlockService()

    init(profile: UserProfile, onRemove: ((UUID) -> Void)? = nil) {
        self.profile = profile
        self.onRemove = onRemove
        _customNickname = State(initialValue: profile.displayName ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Section
                    VStack(spacing: 16) {
                        // Large profile photo
                        ZStack(alignment: .bottomTrailing) {
                            ProfileAvatarView(
                                imageURL: profile.profileImageURL,
                                size: 120,
                                iconScale: 0.4
                            )

                            // View full photo button
                            Button(action: {
                                showImagePicker = true
                            }) {
                                Circle()
                                    .fill(Color.loopedPrimary)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "eye.fill")
                                            .font(.loopedCustom(size: 16))
                                            .foregroundColor(.loopedWhite)
                                    )
                            }
                            .loopedTapTarget()
                            .offset(x: -5, y: -5)
                        }

                        // Custom nickname
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                TextField("Custom name", text: $customNickname)
                                    .font(.loopedHeadingMedium)
                                    .foregroundColor(.loopedTextPrimary)
                                    .multilineTextAlignment(.center)
                                    .textFieldStyle(.plain)

                                Image(systemName: "pencil")
                                    .font(.loopedCustom(size: 16))
                                    .foregroundColor(.loopedPrimary)
                            }

                            Text("(Custom name for you only)")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        }

                        // Actual username
                        Text(profile.displayName ?? "Unknown")
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextSecondary)

                        Text(profile.formattedJobTitle(preferShortNames: preferCommunityShortNames))
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                    }
                    .padding(.top, 20)

                    // Actions Section
                    VStack(spacing: 0) {
                        if let backendId = profile.backendId {
                            NavigationLink(destination: UserProfileView(userId: backendId)) {
                                ChatDetailsActionRow(
                                    icon: "person.circle",
                                    title: "View Profile",
                                    showChevron: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            ChatDetailsActionRow(
                                icon: "person.circle",
                                title: "View Profile",
                                showChevron: false
                            )
                        }

                        Divider().padding(.leading, 60)

                        ChatDetailsToggleRow(
                            icon: "bell.slash",
                            title: "Mute Notifications",
                            isOn: $isMuted
                        )

                        Divider().padding(.leading, 60)

                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            showRemoveMemberAlert = true
                        }) {
                            ChatDetailsActionRow(
                                icon: "person.fill.xmark",
                                title: "Remove from Group",
                                textColor: .loopedError
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 60)

                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            showBlockUserAlert = true
                        }) {
                            ChatDetailsActionRow(
                                icon: "hand.raised",
                                title: "Block User",
                                textColor: .loopedError
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color.loopedTextSecondary.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationTitle("Member Info")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.loopedSecondary)
                }
            }
        }
        .toast($toastMessage)
        .sheet(isPresented: $showImagePicker) {
            // Full-screen image viewer
            if let imageUrl = profile.profileImageURL, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .ignoresSafeArea()
                .background(Color.loopedBlack)
            }
        }
        .alert("Block User", isPresented: $showBlockUserAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                Task { await blockMemberUser() }
            }
        } message: {
            Text("Are you sure you want to block this user? They won't be able to message you.")
        }
        .alert("Remove Member", isPresented: $showRemoveMemberAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onRemove?(profile.id)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to remove this member from the group?")
        }
    }

    private func blockMemberUser() async {
        guard let userId = profile.backendId else {
            toastMessage = ToastMessage(text: "This profile can't be blocked yet.", kind: .error)
            return
        }

        do {
            _ = try await blockService.blockUser(userId: userId, asAnonymousActor: isAnonymousMode, communityId: nil)
            toastMessage = ToastMessage(text: "Blocked user", kind: .success)
            dismiss()
        } catch {
            toastMessage = ToastMessage(text: error.localizedDescription, kind: .error)
        }
    }
}

// MARK: - Member Row
struct ChatDetailsMemberRow: View {
    let profile: UserProfile
    let isCurrentUser: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    @Environment(\.preferCommunityShortNames) private var preferCommunityShortNames

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 12) {
                // Profile Picture
                ProfileAvatarView(imageURL: profile.profileImageURL, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(profile.displayName ?? "Unknown")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextPrimary)

                        if isCurrentUser {
                            Text("(You)")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        }
                    }

                    Text(profile.formattedJobTitle(preferShortNames: preferCommunityShortNames))
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                if !isCurrentUser {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        onRemove()
                    }) {
                        Text("Remove")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedError)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ChatDetailsView(
        conversation: Conversation(
            userId: UUID(),
            userName: "Sarah Chen",
            userProfileImageUrl: nil,
            lastMessage: "Hey!",
            lastMessageTimestamp: Date(),
            isGroup: true,
            memberIds: [UUID(), UUID()]
        ),
        channel: nil
    )
}
