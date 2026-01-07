import SwiftUI

struct ChatDetailsView: View {
    let conversation: Conversation?
    let channel: Channel?
    @Environment(\.dismiss) private var dismiss

    @State private var groupName: String
    @State private var customNickname: String
    @State private var isEditingName = false
    @State private var isMuted = false
    @State private var showAddMembers = false
    @State private var showImagePicker = false
    @State private var showLeaveGroupAlert = false
    @State private var showBlockUserAlert = false
    @State private var selectedImage: UIImage? = nil
    @State private var currentMemberIds: [UUID]

    private var isGroupChat: Bool {
        return channel != nil
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
        channel?.memberCount ?? currentMemberIds.count
    }

    init(conversation: Conversation?, channel: Channel?) {
        self.conversation = conversation
        self.channel = channel

        // Initialize member IDs
        let ids = conversation?.memberIds ?? []
        _currentMemberIds = State(initialValue: ids)

        // Initialize state with current values
        if let channel = channel {
            _groupName = State(initialValue: channel.name)
            _customNickname = State(initialValue: "")
        } else if let conversation = conversation {
            _groupName = State(initialValue: "")
            _customNickname = State(initialValue: conversation.userName)
        } else {
            _groupName = State(initialValue: "")
            _customNickname = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationView {
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
                                        Text("VP")
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

                            // Edit photo button
                            Button(action: {
                                showImagePicker = true
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

                        // Name section
                        if isGroupChat {
                            // Group name (editable)
                            HStack(spacing: 8) {
                                if isEditingName {
                                    TextField("Group name", text: $groupName)
                                        .font(.loopedHeadingMedium)
                                        .foregroundColor(.loopedTextPrimary)
                                        .multilineTextAlignment(.center)
                                        .textFieldStyle(.plain)
                                } else {
                                    Text(groupName)
                                        .font(.loopedHeadingMedium)
                                        .foregroundColor(.loopedTextPrimary)
                                }

                                Button(action: {
                                    isEditingName.toggle()
                                }) {
                                    Image(systemName: isEditingName ? "checkmark.circle.fill" : "pencil")
                                        .font(.loopedCustom(size: 20))
                                        .foregroundColor(.loopedPrimary)
                                }
                            }

                            Text("\(memberCount) members")
                                .font(.loopedBody)
                                .foregroundColor(.loopedTextSecondary)
                        } else {
                            // 1-on-1: Custom nickname
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
                        }
                    }
                    .padding(.top, 20)

                    // Actions Section
                    VStack(spacing: 0) {
                        if isGroupChat {
                            // Group actions
                            ChatDetailsActionRow(
                                icon: "person.badge.plus",
                                title: "Add Members",
                                action: {
                                    showAddMembers = true
                                }
                            )

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

                        if !isGroupChat {
                            Divider().padding(.leading, 60)

                            ChatDetailsActionRow(
                                icon: "hand.raised",
                                title: "Block User",
                                textColor: .loopedError,
                                action: {
                                    showBlockUserAlert = true
                                }
                            )
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
                    .foregroundColor(.loopedPrimary)
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showAddMembers) {
            NewMessageView(
                onChatSelected: { _, _ in },
                channelToAddMembers: channel
            )
        }
        .sheet(isPresented: $showImagePicker) {
            CameraPickerView(selectedImage: $selectedImage)
        }
        .alert("Leave Group", isPresented: $showLeaveGroupAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                // TODO: Implement leave group
                dismiss()
            }
        } message: {
            Text("Are you sure you want to leave this group?")
        }
        .alert("Block User", isPresented: $showBlockUserAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                // TODO: Implement block user
                dismiss()
            }
        } message: {
            Text("Are you sure you want to block this user? They won't be able to message you.")
        }
    }
}

// MARK: - Action Row
struct ChatDetailsActionRow: View {
    let icon: String
    let title: String
    var textColor: Color = .loopedTextPrimary
    var showChevron: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action?()
        }) {
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
        .buttonStyle(PlainButtonStyle())
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

    @State private var customNickname: String
    @State private var showImagePicker = false
    @State private var showBlockUserAlert = false
    @State private var showRemoveMemberAlert = false
    @State private var selectedImage: UIImage? = nil
    @State private var isMuted = false

    init(profile: UserProfile, onRemove: ((UUID) -> Void)? = nil) {
        self.profile = profile
        self.onRemove = onRemove
        _customNickname = State(initialValue: profile.displayName ?? "")
    }

    var body: some View {
        NavigationView {
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

                        Text(profile.formattedJobTitle)
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

                        ChatDetailsActionRow(
                            icon: "person.fill.xmark",
                            title: "Remove from Group",
                            textColor: .loopedError,
                            action: {
                                showRemoveMemberAlert = true
                            }
                        )

                        Divider().padding(.leading, 60)

                        ChatDetailsActionRow(
                            icon: "hand.raised",
                            title: "Block User",
                            textColor: .loopedError,
                            action: {
                                showBlockUserAlert = true
                            }
                        )
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
                    .foregroundColor(.loopedPrimary)
                }
            }
        }
        .navigationViewStyle(.stack)
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
                // TODO: Implement block user
                dismiss()
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
}

// MARK: - Member Row
struct ChatDetailsMemberRow: View {
    let profile: UserProfile
    let isCurrentUser: Bool
    let onTap: () -> Void
    let onRemove: () -> Void

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

                    Text(profile.formattedJobTitle)
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
