import SwiftUI

struct NewMessageView: View {
    let onChatSelected: (Conversation?, Channel?) -> Void
    var channelToAddMembers: Channel? = nil
    var onMembersAdded: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedRecipients: [UserProfile] = []
    @StateObject private var searchViewModel = NewMessageSearchViewModel()
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    private let messageService: MessageServiceProtocol = MessageService()

    private var filteredContacts: [UserProfile] {
        searchViewModel.results.map { UserProfile.from(user: $0, isCurrentUser: false) }
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
                ToolbarItem(placement: .cancellationAction) {
                    LoopedCancelTextButton(action: { dismiss() })
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
        .onChange(of: searchText) { newValue in
            Task { await searchViewModel.search(query: newValue) }
        }
        .alert("Unable to Start Chat", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Something went wrong.")
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
                if !filteredContacts.isEmpty {
                    HStack {
                        Text(searchText.isEmpty ? "Suggested" : "Contacts")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                            .textCase(.uppercase)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    ForEach(filteredContacts) { contact in
                        ContactRow(
                            contact: contact,
                            isSelected: selectedRecipients.contains { $0.id == contact.id },
                            onTap: { toggleRecipient(contact) }
                        )
                    }
                } else if searchText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Search coworkers to start a conversation.")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                } else if searchViewModel.isSearching {
                    ProgressView("Searching...")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No results")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
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

    private func handleNextButtonTap() {
        guard !selectedRecipients.isEmpty else { return }

        if let channelToAddMembers {
            let backendIds = selectedRecipients.compactMap { $0.backendId }
            guard !backendIds.isEmpty else { return }
            Task {
                do {
                    _ = try await messageService.addChannelMembers(
                        channelBackendId: channelToAddMembers.backendId,
                        userIds: backendIds
                    )
                    onMembersAdded?()
                    dismiss()
                } catch {
                }
            }
            return
        }

        if selectedRecipients.count == 1, let backendId = selectedRecipients[0].backendId {
            Task {
                do {
                    let conversation = try await messageService.startConversation(with: backendId)
                    onChatSelected(conversation, nil)
                    dismiss()
                } catch {
                    presentStartConversationError(error)
                }
            }
            return
        }

        let backendIds = selectedRecipients.compactMap { $0.backendId }
        guard !backendIds.isEmpty else { return }
        let groupName = makeGroupName(from: selectedRecipients)
        Task {
            do {
                let channel = try await messageService.createChannel(name: groupName, memberUserIds: backendIds)
                onChatSelected(nil, channel)
                dismiss()
            } catch {
            }
        }
    }

    private func makeGroupName(from recipients: [UserProfile]) -> String {
        let names = recipients.compactMap { profile in
            let primary = profile.displayName ?? profile.username
            let trimmedPrimary = primary.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = profile.handle.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedPrimary.isEmpty ? fallback : trimmedPrimary
        }
        .filter { !$0.isEmpty }

        guard !names.isEmpty else { return "New Group" }
        if names.count == 1 { return names[0] }
        if names.count == 2 { return "\(names[0]) & \(names[1])" }
        return "\(names[0]), \(names[1]) +\(names.count - 2)"
    }

    private func presentStartConversationError(_ error: Error) {
        if case let APIError.apiError(code, apiError, _) = error,
           code == 403 || apiError == "forbidden" {
            errorMessage = "This person isn't accepting new message requests."
        } else {
            errorMessage = error.localizedDescription
        }
        showErrorAlert = true
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
                    .font(.loopedCustom(.medium, size: 12))
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
    @Environment(\.preferCommunityShortNames) private var preferCommunityShortNames

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
                                .font(.loopedCustom(size: 16))
                                .foregroundColor(.loopedWhite)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.displayName ?? "Anonymous")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text(contact.formattedJobTitle(preferShortNames: preferCommunityShortNames))
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.loopedCustom(size: 20))
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

// MARK: - Search ViewModel
@MainActor
final class NewMessageSearchViewModel: ObservableObject {
    @Published var results: [User] = []
    @Published var isSearching = false
    private let userService: UserServiceProtocol
    
    init(userService: UserServiceProtocol = UserService()) {
        self.userService = userService
    }
    
    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        do {
            let page = try await userService.searchUsers(query: trimmed, limit: 20, cursor: nil)
            results = page.users
        } catch {
            results = []
        }
        isSearching = false
    }
}

#Preview {
    NewMessageView(onChatSelected: { _, _ in })
}
