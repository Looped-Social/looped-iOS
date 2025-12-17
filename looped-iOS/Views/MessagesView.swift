import SwiftUI

struct MessagesView: View {
    let onChatSelected: (Conversation?, Channel?) -> Void

    @StateObject private var viewModel = MessagesViewModel()
    @State private var selectedTab: MessageTab = .messages
    @State private var searchText = ""
    @State private var showNewMessage = false

    // Filter conversations based on tab and search text
    private var filteredConversations: [Conversation] {
        // First filter by tab
        let tabFilteredConversations = selectedTab == .messages
            ? viewModel.conversations.filter { !$0.isGroup }  // Messages tab: only individual conversations
            : viewModel.conversations.filter { $0.isGroup }   // Groups tab: only group conversations

        // Then filter by search text
        if searchText.isEmpty {
            return tabFilteredConversations
        } else {
            return tabFilteredConversations.filter { conversation in
                conversation.userName.localizedCaseInsensitiveContains(searchText) ||
                conversation.lastMessage.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            MessagesHeader(title: selectedTab == .messages ? "Messages" : "Groups")

            // Search Bar
            MessagesSearchBar(searchText: $searchText)
                .padding(.bottom, 8)

            // Tabs
            MessagesTabs(selectedTab: $selectedTab)

            // Content (both Messages and Groups use same list structure)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.isLoading && viewModel.conversations.isEmpty {
                        ForEach(0..<10, id: \.self) { _ in
                            ConversationRowSkeleton()
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.loopedTextSecondary.opacity(0.1))
                                .padding(.leading, 78)
                        }
                    } else if filteredConversations.isEmpty {
                        if searchText.isEmpty {
                            EmptyMessagesView(
                                title: selectedTab == .messages ? "No messages yet" : "No groups yet",
                                subtitle: selectedTab == .messages
                                    ? "It’s quiet in here. Start a new chat and make it awkward on purpose."
                                    : "Nothing to see here… yet. Start a conversation and it’ll show up.",
                                buttonTitle: selectedTab == .messages ? "Start a new message" : "Start a new chat",
                                onButtonTap: { showNewMessage = true }
                            )
                        } else {
                            EmptyMessagesView(
                                title: "No matches",
                                subtitle: "We looked everywhere for “\(searchText)”.",
                                buttonTitle: "Clear search",
                                onButtonTap: { searchText = "" }
                            )
                        }
                    } else {
                        ForEach(filteredConversations) { conversation in
                            Button(action: {
                                onChatSelected(conversation, nil)
                            }) {
                                ConversationRow(conversation: conversation)
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Divider line
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.loopedTextSecondary.opacity(0.1))
                                .padding(.leading, 78) // Indent to align with text content
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refreshConversations()
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.loadConversations()
        }
        .sheet(isPresented: $showNewMessage) {
            NewMessageView(onChatSelected: onChatSelected)
        }
    }
}


#Preview {
    MessagesView(onChatSelected: { _, _ in })
}
