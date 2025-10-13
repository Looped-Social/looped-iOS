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
                    ForEach(filteredConversations) { conversation in
                        Button(action: {
                            if MockConversations.isGroupConversation(conversation) {
                                // Pass both conversation and channel for groups (to access memberIds)
                                onChatSelected(conversation, MockConversations.getChannelForGroupConversation(conversation))
                            } else {
                                onChatSelected(conversation, nil)
                            }
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
            // TODO: New message composition view
            Text("New Message")
                .font(.loopedHeading)
                .padding()
        }
    }
}


#Preview {
    MessagesView(onChatSelected: { _, _ in })
}