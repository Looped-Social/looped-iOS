import SwiftUI

struct MessagesView: View {
    @State private var selectedTab: MessageTab = .messages
    @State private var searchText = ""
    @State private var showNewMessage = false

    // Filter conversations based on search text
    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return MockConversations.conversations
        } else {
            return MockConversations.conversations.filter { conversation in
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

            // Content based on selected tab
            if selectedTab == .messages {
                // Messages List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredConversations) { conversation in
                            Button(action: {
                                // TODO: Navigate to chat with this user
                                print("Tapped conversation with \(conversation.userName)")
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
            } else {
                // Groups placeholder
                VStack {
                    Spacer()
                    Text("Groups coming soon...")
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextSecondary)
                    Spacer()
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showNewMessage) {
            // TODO: New message composition view
            Text("New Message")
                .font(.loopedHeading)
                .padding()
        }
    }
}


#Preview {
    MessagesView()
}