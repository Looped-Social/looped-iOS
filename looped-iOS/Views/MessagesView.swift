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
        let tabFilteredConversations: [Conversation]
        switch selectedTab {
        case .messages:
            tabFilteredConversations = viewModel.conversations.filter { !$0.isGroup }  // Messages tab: only individual conversations
        case .groups:
            tabFilteredConversations = viewModel.conversations.filter { $0.isGroup }   // Groups tab: only group conversations
        case .requests:
            tabFilteredConversations = []
        }

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

    private var filteredRequests: [MessageRequest] {
        if searchText.isEmpty {
            return viewModel.messageRequests
        }
        return viewModel.messageRequests.filter { request in
            request.displayName.localizedCaseInsensitiveContains(searchText) ||
            request.previewSummary.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            MessagesHeader(title: headerTitle)

            // Search Bar
            MessagesSearchBar(searchText: $searchText)
                .padding(.bottom, 8)

            // Tabs
            MessagesTabs(selectedTab: $selectedTab)

            // Content (both Messages and Groups use same list structure)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if selectedTab == .requests {
                        if viewModel.isLoadingRequests && viewModel.messageRequests.isEmpty {
                            ProgressView("Loading requests...")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                        } else if filteredRequests.isEmpty {
                            if searchText.isEmpty {
                                EmptyMessagesView(
                                    title: "No requests yet",
                                    subtitle: "When someone you don't follow messages you, they'll show up here.",
                                    buttonTitle: "Refresh",
                                    onButtonTap: { Task { await viewModel.loadMessageRequests() } }
                                )
                            } else {
                                EmptyMessagesView(
                                    title: "No matches",
                                    subtitle: "We looked everywhere for \"\(searchText)\".",
                                    buttonTitle: "Clear search",
                                    onButtonTap: { searchText = "" }
                                )
                            }
                        } else {
                            Text("Approve or reject people you don't follow before chatting.")
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedTextSecondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            ForEach(filteredRequests) { request in
                                MessageRequestRow(
                                    request: request,
                                    isProcessing: viewModel.processingRequestIds.contains(request.backendId),
                                    onApprove: { Task { await viewModel.approveMessageRequest(request) } },
                                    onReject: { Task { await viewModel.rejectMessageRequest(request) } }
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                            }
                        }
                    } else if viewModel.isLoading && viewModel.conversations.isEmpty {
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
                if selectedTab == .requests {
                    await viewModel.loadMessageRequests()
                } else {
                    await viewModel.refreshInbox()
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.loadInbox()
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .requests, viewModel.messageRequests.isEmpty {
                Task { await viewModel.loadMessageRequests() }
            }
        }
        .sheet(isPresented: $showNewMessage) {
            NewMessageView(onChatSelected: onChatSelected)
        }
    }

    private var headerTitle: String {
        switch selectedTab {
        case .messages:
            return "Messages"
        case .requests:
            return "Requests"
        case .groups:
            return "Groups"
        }
    }
}


#Preview {
    MessagesView(onChatSelected: { _, _ in })
}
