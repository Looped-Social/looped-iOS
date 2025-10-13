import SwiftUI

struct NewMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedRecipients: [UserProfile] = []

    private var suggestedContacts: [UserProfile] {
        MockUserProfiles.profiles.filter { !$0.isCurrentUser }
    }

    private var suggestedGroups: [Conversation] {
        MockConversations.getGroupConversations()
    }

    private var filteredContacts: [UserProfile] {
        if searchText.isEmpty {
            return suggestedContacts
        } else {
            return MockUserProfiles.searchUserProfiles(query: searchText)
        }
    }

    private var filteredGroups: [Conversation] {
        if searchText.isEmpty {
            return suggestedGroups
        } else {
            return suggestedGroups.filter { $0.userName.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // To: Field and Recipients
                toFieldSection

                // Contacts List
                contactsList
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationTitle("New Message")
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
                    Button("Next") {
                        handleNextButtonTap()
                    }
                    .foregroundColor(selectedRecipients.isEmpty ? .loopedTextSecondary : .loopedPrimary)
                    .disabled(selectedRecipients.isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - To Field Section
    private var toFieldSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("To:")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                // Selected Recipients as Chips
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedRecipients) { recipient in
                                RecipientChip(
                                    recipient: recipient,
                                    onRemove: { removeRecipient(recipient) }
                                )
                            }

                            // Search TextField
                            TextField("Search people...", text: $searchText)
                                .font(.loopedBody)
                                .foregroundColor(.loopedTextPrimary)
                                .frame(minWidth: searchText.isEmpty ? 120 : nil)
                                .id("searchField")
                        }
                        .padding(.horizontal, 4)
                    }
                    .onChange(of: selectedRecipients.count) { _ in
                        withAnimation {
                            proxy.scrollTo("searchField", anchor: .trailing)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Divider
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.loopedTextSecondary.opacity(0.2))
        }
    }

    // MARK: - Contacts List
    private var contactsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Groups Section
                if !filteredGroups.isEmpty {
                    // Section Header
                    HStack {
                        Text(searchText.isEmpty ? "Group Chats" : "Groups")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                            .textCase(.uppercase)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    // Group Rows
                    ForEach(filteredGroups) { group in
                        GroupRow(
                            group: group,
                            onTap: { navigateToGroup(group) }
                        )
                    }
                }

                // Contacts Section
                if !filteredContacts.isEmpty {
                    // Section Header
                    HStack {
                        Text(searchText.isEmpty ? "Suggested" : "Contacts")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                            .textCase(.uppercase)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .padding(.top, filteredGroups.isEmpty ? 0 : 16)

                    // Contact Rows
                    ForEach(filteredContacts) { contact in
                        ContactRow(
                            contact: contact,
                            isSelected: selectedRecipients.contains { $0.id == contact.id },
                            onTap: { toggleRecipient(contact) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions
    private func toggleRecipient(_ recipient: UserProfile) {
        if let index = selectedRecipients.firstIndex(where: { $0.id == recipient.id }) {
            selectedRecipients.remove(at: index)
        } else {
            selectedRecipients.append(recipient)
        }
    }

    private func removeRecipient(_ recipient: UserProfile) {
        selectedRecipients.removeAll { $0.id == recipient.id }
    }

    private func navigateToGroup(_ group: Conversation) {
        // TODO: Navigate to group chat
        print("Navigate to group: \(group.userName)")
        dismiss()
    }

    private func handleNextButtonTap() {
        guard !selectedRecipients.isEmpty else { return }

        if selectedRecipients.count == 1 {
            // Single recipient: navigate to 1-on-1 conversation
            // TODO: Navigate to individual chat
            print("Navigate to 1-on-1 chat with \(selectedRecipients[0].displayName ?? "Unknown")")
        } else {
            // Multiple recipients: check for existing group or create new one
            let memberIds = selectedRecipients.map { $0.id }

            if let existingGroup = MockConversations.findGroupByMembers(memberIds) {
                // Group already exists: navigate to it
                print("Found existing group: \(existingGroup.userName)")
                // TODO: Navigate to existing group
            } else {
                // No existing group: create new one
                let newGroup = MockConversations.createGroup(withMembers: selectedRecipients)
                print("Created new group: \(newGroup.userName)")
                // TODO: Navigate to new group
            }
        }

        dismiss()
    }
}

// MARK: - Recipient Chip
struct RecipientChip: View {
    let recipient: UserProfile
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(recipient.displayName ?? "Unknown")
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedPrimary)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.loopedPrimary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.loopedPrimary.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Group Row
struct GroupRow: View {
    let group: Conversation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Group Icon
                Circle()
                    .fill(Color.loopedPrimary.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.loopedPrimary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.userName)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    if let memberCount = group.memberIds?.count {
                        Text("\(memberCount) members")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.loopedTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Contact Row
struct ContactRow: View {
    let contact: UserProfile
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile Picture
                AsyncImage(url: URL(string: contact.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.loopedPrimary)
                        .overlay(
                            Image("profile-icon")
                                .renderingMode(.template)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.displayName ?? "Anonymous")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text(contact.formattedJobTitle)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.loopedPrimary)
                } else {
                    Circle()
                        .stroke(Color.loopedTextSecondary.opacity(0.3), lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NewMessageView()
}