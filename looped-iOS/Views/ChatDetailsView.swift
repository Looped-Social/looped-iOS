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
    @State private var showRemoveMemberAlert: UUID? = nil
    @State private var selectedImage: UIImage? = nil

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

    private var memberIds: [UUID] {
        if let conversation = conversation, let ids = conversation.memberIds {
            return ids
        }
        return []
    }

    init(conversation: Conversation?, channel: Channel?) {
        self.conversation = conversation
        self.channel = channel

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
                                    .fill(Color.purple)
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Text("VP")
                                            .font(.system(size: 40, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            } else if let profileImageUrl = conversation?.userProfileImageUrl {
                                AsyncImage(url: URL(string: profileImageUrl)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.loopedPrimary.opacity(0.3))
                                        .overlay(
                                            Text(String(chatTitle.prefix(1)).uppercased())
                                                .font(.system(size: 40, weight: .bold))
                                                .foregroundColor(.loopedPrimary)
                                        )
                                }
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.loopedPrimary.opacity(0.3))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Text(String(chatTitle.prefix(1)).uppercased())
                                            .font(.system(size: 40, weight: .bold))
                                            .foregroundColor(.loopedPrimary)
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
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
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
                                        .font(.system(size: 20))
                                        .foregroundColor(.loopedPrimary)
                                }
                            }

                            Text("\(memberIds.count) members")
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
                                        .font(.system(size: 16))
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
                            NavigationLink(destination: Text("User Profile")) {
                                ChatDetailsActionRow(
                                    icon: "person.circle",
                                    title: "View Profile",
                                    showChevron: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

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
                                textColor: .red,
                                action: {
                                    showBlockUserAlert = true
                                }
                            )
                        }
                    }
                    .background(Color.loopedTextSecondary.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)

                    // Members Section (Group only)
                    if isGroupChat && !memberIds.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Members")
                                .font(.loopedBodyStrong)
                                .foregroundColor(.loopedTextPrimary)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                ForEach(memberIds, id: \.self) { memberId in
                                    if let profile = MockUserProfiles.getUserProfile(byId: memberId) {
                                        ChatDetailsMemberRow(
                                            profile: profile,
                                            isCurrentUser: profile.isCurrentUser,
                                            onRemove: {
                                                showRemoveMemberAlert = memberId
                                            }
                                        )

                                        if memberId != memberIds.last {
                                            Divider().padding(.leading, 68)
                                        }
                                    }
                                }
                            }
                            .background(Color.loopedTextSecondary.opacity(0.05))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }
                    }

                    // Danger Zone
                    if isGroupChat {
                        Button(action: {
                            showLeaveGroupAlert = true
                        }) {
                            Text("Leave Group")
                                .font(.loopedBodyMedium)
                                .foregroundColor(.red)
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
            NewMessageView(onChatSelected: { _, _ in
                // TODO: Handle adding members
                showAddMembers = false
            })
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
        .alert("Remove Member", isPresented: .init(
            get: { showRemoveMemberAlert != nil },
            set: { if !$0 { showRemoveMemberAlert = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                showRemoveMemberAlert = nil
            }
            Button("Remove", role: .destructive) {
                if let memberId = showRemoveMemberAlert {
                    // TODO: Implement remove member
                    showRemoveMemberAlert = nil
                }
            }
        } message: {
            Text("Are you sure you want to remove this member from the group?")
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
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.loopedPrimary)
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(.loopedBodyMedium)
                    .foregroundColor(textColor)

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
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
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.loopedPrimary)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.4, green: 0.7, blue: 0.6)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Member Row
struct ChatDetailsMemberRow: View {
    let profile: UserProfile
    let isCurrentUser: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture
            AsyncImage(url: URL(string: profile.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.loopedPrimary.opacity(0.3))
                    .overlay(
                        Text(String((profile.displayName ?? "U").prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.loopedPrimary)
                    )
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

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
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
