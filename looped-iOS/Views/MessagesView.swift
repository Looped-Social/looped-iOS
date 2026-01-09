import SwiftUI

struct MessagesView: View {
    let onChatSelected: (Conversation?, Channel?) -> Void

    @StateObject private var viewModel = MessagesViewModel()
    @State private var selectedTab: MessageTab = .messages
    @State private var searchText = ""
    @State private var showNewMessage = false
    @AppStorage("anonymousMode") private var isAnonymousMode = false

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
        if trimmedSearchText.count < 2 {
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

    private var filteredChannels: [Channel] {
        if trimmedSearchText.count < 2 {
            return viewModel.channels
        }
        return viewModel.channels.filter { channel in
            channel.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isUsingBackendSearch: Bool {
        selectedTab != .requests && trimmedSearchText.count >= 2
    }

    private var filteredSearchResults: [MessageSearchHit] {
        switch selectedTab {
        case .messages:
            return viewModel.searchResults.filter { $0.type == .conversation }
        case .groups:
            return viewModel.searchResults.filter { $0.type == .channel }
        case .requests:
            return []
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            MessagesHeader(title: headerTitle)

            // Search Bar
            MessagesSearchBar(searchText: $searchText)
                .padding(.bottom, 8)
                .onChange(of: searchText) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard selectedTab != .requests else {
                        viewModel.clearSearch()
                        return
                    }
                    if trimmed.count < 2 {
                        viewModel.clearSearch()
                        return
                    }
                    viewModel.searchMessages(query: trimmed)
                }

            // Tabs
            MessagesTabs(selectedTab: $selectedTab)

            // Content (both Messages and Groups use same list structure)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if isUsingBackendSearch {
                        if isAnonymousMode {
                            EmptyMessagesView(
                                title: "Search unavailable",
                                subtitle: "Message search isn’t available in anonymous mode.",
                                buttonTitle: "Clear search",
                                onButtonTap: { searchText = "" }
                            )
                            .padding(.top, 24)
                        } else if let error = viewModel.searchErrorMessage, !error.isEmpty {
                            EmptyMessagesView(
                                title: "Search failed",
                                subtitle: error,
                                buttonTitle: "Clear search",
                                onButtonTap: { searchText = "" }
                            )
                            .padding(.top, 24)
                        } else if viewModel.isSearching {
                            ProgressView("Searching...")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                        } else if filteredSearchResults.isEmpty {
                            EmptyMessagesView(
                                title: "No matches",
                                subtitle: "We looked everywhere for “\(trimmedSearchText)”.",
                                buttonTitle: "Clear search",
                                onButtonTap: { searchText = "" }
                            )
                            .padding(.top, 24)
                        } else {
                            ForEach(filteredSearchResults) { hit in
                                Button(action: {
                                    switch hit.type {
                                    case .conversation:
                                        if let conversation = hit.conversation {
                                            onChatSelected(conversation, nil)
                                        }
                                    case .channel:
                                        if let channel = hit.channel {
                                            onChatSelected(nil, channel)
                                        }
                                    }
                                }) {
                                    MessageSearchResultRow(hit: hit)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.loopedTextSecondary.opacity(0.1))
                                    .padding(.leading, 78)
                            }
                        }
                    } else if selectedTab == .requests {
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
                                    onApprove: {
                                        Task {
                                            let conversation = await viewModel.approveMessageRequest(request)
                                            await MainActor.run {
                                                searchText = ""
                                                selectedTab = request.isGroup ? .groups : .messages
                                                if let conversation {
                                                    onChatSelected(conversation, nil)
                                                }
                                            }
                                        }
                                    },
                                    onReject: { Task { await viewModel.rejectMessageRequest(request) } }
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                            }
                        }
                    } else if selectedTab == .groups {
                        if viewModel.isLoadingChannels && viewModel.channels.isEmpty {
                            ProgressView("Loading groups...")
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                        } else if filteredChannels.isEmpty {
                            if searchText.isEmpty {
                                EmptyMessagesView(
                                    title: "No groups yet",
                                    subtitle: "Nothing to see here… yet. Start a conversation and it’ll show up.",
                                    buttonTitle: "Start a new chat",
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
                            ForEach(filteredChannels) { channel in
                                Button(action: {
                                    onChatSelected(nil, channel)
                                }) {
                                    GroupChannelRow(channel: channel)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.loopedTextSecondary.opacity(0.1))
                                    .padding(.leading, 78)
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
                } else if selectedTab == .groups {
                    await viewModel.loadChannels()
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
            if newValue == .groups, viewModel.channels.isEmpty {
                Task { await viewModel.loadChannels() }
            }
            if newValue == .requests {
                viewModel.clearSearch()
            } else if trimmedSearchText.count >= 2 {
                viewModel.searchMessages(query: trimmedSearchText)
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
