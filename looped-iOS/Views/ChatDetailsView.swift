import SwiftUI
import Foundation
import UIKit

struct ChatDetailsView: View {
    let conversation: Conversation?
    let channel: Channel?
    let onChatShouldClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("anonymousMode") private var isAnonymousMode = false

    @State private var groupName: String
    @State private var isMuted = false
    @State private var isSyncingMuteState = false
    @State private var isUpdatingMute = false
    @State private var showAddMembers = false
    @State private var showLeaveGroupAlert = false
    @State private var showBlockUserAlert = false
    @State private var currentMemberIds: [UUID]
    @State private var members: [ChannelMember] = []
    @State private var isLoadingMembers = false
    @State private var toastMessage: ToastMessage?
    @State private var memberPendingRemoval: ChannelMember?
    @State private var isLeavingGroup = false
    @State private var isBlockingUser = false

    private let messageService: MessageServiceProtocol = MessageService()
    private let blockService: BlockServiceProtocol = BlockService()

    private var isGroupChat: Bool {
        return channel != nil
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
        } else if let conversation = conversation {
            _groupName = State(initialValue: "")
        } else {
            _groupName = State(initialValue: "")
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
                                Circle()
                                    .fill(Color.loopedSecondary)
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Text(groupInitials)
                                            .font(.loopedCustom(.bold, size: 40))
                                            .foregroundColor(.loopedWhite)
                                    )
                            } else {
                                ProfileAvatarView(
                                    imageURL: conversation?.userProfileImageUrl,
                                    size: 120,
                                    iconScale: 0.4
                                )
                            }

                            if isGroupChat {
                                Button(action: {
                                    toastMessage = ToastMessage(text: "Group photos aren't supported yet.", kind: .info)
                                }) {
                                    Circle()
                                        .fill(Color.loopedPrimary)
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.loopedCustom(size: 16))
                                                .foregroundColor(.loopedWhite)
                                        )
                                }
                                .offset(x: -5, y: -5)
                            }
                        }

                        // Name section
                        if isGroupChat {
                            Text(groupName)
                                .font(.loopedHeadingMedium)
                                .foregroundColor(.loopedTextPrimary)

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
                            showLeaveGroupAlert = true
                        }) {
                            Text("Leave Group")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedError)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.loopedTextSecondary.opacity(0.05))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .disabled(isLeavingGroup)
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
            MutedChatStore.shared.setChannelMuted(newValue, channelId: id)
            toastMessage = ToastMessage(text: newValue ? "Notifications muted" : "Notifications unmuted", kind: .success)
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
                return "You can’t mute this conversation."
            case "not_found":
                return "This conversation no longer exists."
            case "user_not_provisioned":
                return "Messaging isn’t ready yet. Try again."
            default:
                return code
            }
        }
        return error.localizedDescription
    }

    private var groupInitials: String {
        let rawTitle = channel?.name ?? groupName
        let components = rawTitle.split(separator: " ")
        let initials = components.compactMap { component -> Character? in
            component.first { char in
                char.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
            }
        }
        .prefix(2)
        .map { String($0).uppercased() }
        .joined()

        return initials.isEmpty ? "GC" : initials
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

        isLeavingGroup = true
        defer { isLeavingGroup = false }

        do {
            try await messageService.removeChannelMember(channelBackendId: channel.backendId, userId: currentUserId)
            toastMessage = ToastMessage(text: "Left group", kind: .success)
            dismiss()
            onChatShouldClose?()
        } catch {
            toastMessage = ToastMessage(text: error.localizedDescription, kind: .error)
        }
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
