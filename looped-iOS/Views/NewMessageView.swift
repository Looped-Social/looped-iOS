import SwiftUI

struct NewMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedRecipients: [UserProfile] = []
    @State private var showCreateGroup = false

    private var suggestedContacts: [UserProfile] {
        MockUserProfiles.profiles.filter { !$0.isCurrentUser }
    }

    private var filteredContacts: [UserProfile] {
        if searchText.isEmpty {
            return suggestedContacts
        } else {
            return MockUserProfiles.searchUserProfiles(query: searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // To: Field and Recipients
                toFieldSection

                // Create New Group Action
                createGroupAction

                // Contacts List
                contactsList

                Spacer()
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
                        // TODO: Navigate to chat with selected recipients
                        dismiss()
                    }
                    .foregroundColor(selectedRecipients.isEmpty ? .loopedTextSecondary : .loopedPrimary)
                    .disabled(selectedRecipients.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showCreateGroup) {
            // TODO: Create Group View
            CreateGroupView()
        }
    }

    // MARK: - To Field Section
    private var toFieldSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("To:")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                // Selected Recipients as Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
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
                    }
                    .padding(.horizontal, 4)
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

    // MARK: - Create Group Action
    private var createGroupAction: some View {
        Button(action: {
            showCreateGroup = true
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.loopedPrimary)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    )

                Text("Create new group")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Contacts List
    private var contactsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                Text(searchText.isEmpty ? "Suggested" : "Results")
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedTextSecondary)
                    .textCase(.uppercase)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Contacts
            ScrollView {
                LazyVStack(spacing: 0) {
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

// MARK: - Create Group View (Placeholder)
struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                Text("Create Group")
                    .font(.loopedHeading)
                    .foregroundColor(.loopedTextPrimary)
                Text("Coming soon...")
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextSecondary)
                Spacer()
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.loopedPrimary)
                }
            }
        }
    }
}

#Preview {
    NewMessageView()
}