//
//  ContentView.swift
//  looped-iOS
//
//  Created by William Millen on 9/5/25.
//

import SwiftUI


enum MenuDestination: Identifiable {
    case liked
    case saved
    case privacy
    case drafts
    case analytics
    case faq
    case settings

    var id: String {
        switch self {
        case .liked: return "liked"
        case .saved: return "saved"
        case .privacy: return "privacy"
        case .drafts: return "drafts"
        case .analytics: return "analytics"
        case .faq: return "faq"
        case .settings: return "settings"
        }
    }
}

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                if authViewModel.shouldEnterOnboardingFlow && !authViewModel.onboardingComplete {
                    AuthView(authViewModel: authViewModel)
                } else {
                    MainTabView()
                        .environmentObject(authViewModel)
                }
            } else {
                AuthView(authViewModel: authViewModel)
            }
        }
        .alert("Verification Required", isPresented: $authViewModel.showDeferredOnboardingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You can browse all posts, but posting is only available after verification.")
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedTab: TabItem = .home
    @State private var showCreatePost = false
    @State private var showNewMessage = false
    @State private var isRightMenuOpen = false
    @State private var showingChat = false
    @State private var selectedConversation: Conversation?
    @State private var selectedChannel: Channel?
    @State private var menuDestination: MenuDestination?
    @StateObject private var feedViewModel = FeedViewModel()
    @StateObject private var commentsManager = CommentsModalManager()
    @State private var showPostVerificationAlert = false
    
    var body: some View {
        GeometryReader { geometry in
            let safeWidth = max(geometry.size.width, 0)
            let drawerWidth = safeWidth * 0.8
            let shadowSpacerWidth = safeWidth * 0.2
            ZStack(alignment: .leading) {
                // Right Menu (only visible on home tab)
                if selectedTab == .home {
                    HStack(spacing: 0) {
                        Spacer()

                        // Menu content constrained to 80% width with full background
                        MenuContent(onMenuItemTap: { destination in
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                isRightMenuOpen = false
                            }
                            // Small delay to let drawer close before navigation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                menuDestination = destination
                            }
                        })
                        .frame(width: geometry.size.width * 0.8)
                        .background(Color.loopedBackground.ignoresSafeArea(.all))
                        .contentShape(Rectangle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.loopedBackground.ignoresSafeArea(.all))
                    .offset(x: isRightMenuOpen ? 0 : drawerWidth)
                    .allowsHitTesting(isRightMenuOpen)
                }

                // Main app content
                VStack(spacing: 0) {
                    // Content Area
                    Group {
                        switch selectedTab {
                        case .home:
                            NavigationView {
                                FeedView(
                                    onProfileTap: {
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                            isRightMenuOpen.toggle()
                                        }
                                    }
                                )
                                    .environmentObject(feedViewModel)
                                    .environmentObject(commentsManager)
                            }
                            .navigationViewStyle(.stack)
                        case .messages:
                            NavigationView {
                                MessagesView(
                                    onChatSelected: { conversation, channel in
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedConversation = conversation
                                            selectedChannel = channel
                                            showingChat = true
                                        }
                                    }
                                )
                            }
                            .navigationViewStyle(.stack)
                        case .search:
                            SearchView()
                        case .notifications:
                            NotificationsView()
                        case .profile:
                            NavigationView {
                                ProfileView()
                            }
                            .navigationViewStyle(.stack)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Custom Tab Bar
                    CustomTabBar(selectedTab: $selectedTab)
                }
                .background(Color.loopedBackground.ignoresSafeArea())
                .overlay(
                    // Blocking overlay when drawer is open - prevents feed interactions
                    Group {
                        if selectedTab == .home && isRightMenuOpen {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        isRightMenuOpen = false
                                    }
                                }
                                .allowsHitTesting(true)
                        }
                    }
                )
                .offset(x: selectedTab == .home ? (isRightMenuOpen ? -drawerWidth : 0) : 0)
                .scaleEffect((selectedTab == .home && isRightMenuOpen) ? 0.95 : 1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isRightMenuOpen)

                // Shadow overlays - feed casting shadow onto drawers
                if selectedTab == .home {
                    // Right shadow - instantly visible/invisible
                    HStack(spacing: 0) {
                        Spacer()
                            .frame(width: shadowSpacerWidth)

                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.black.opacity(0.05),
                                Color.black.opacity(0.1),
                                Color.black.opacity(0.2)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 20)

                        Spacer()
                            .frame(width: max(drawerWidth - 20, 0))
                    }
                    .opacity(isRightMenuOpen ? 1 : 0)
                    .animation(.linear(duration: 0.0), value: isRightMenuOpen)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)
                }

                // Floating Action Button (show on home and messages tabs)
                if (selectedTab == .home || selectedTab == .messages) && !commentsManager.isPresented && !isRightMenuOpen {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            FloatingActionButton(
                                type: selectedTab == .messages ? .sendMessage : .addPost
                            ) {
                                if selectedTab == .messages {
                                    showNewMessage = true
                                } else {
                                    if canCreatePost {
                                        showCreatePost = true
                                    } else {
                                        showPostVerificationAlert = true
                                    }
                                }
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 60) // Position above tab bar
                        }
                    }
                }

                // Chat View - Full Screen Overlay (MUST be last in ZStack)
                if showingChat {
                    ChatView(
                        conversation: selectedConversation,
                        channel: selectedChannel,
                        onBackTapped: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingChat = false
                                selectedConversation = nil
                                selectedChannel = nil
                            }
                        }
                    )
                    .transition(.move(edge: .trailing))
                }

            }
        }
        // MODAL OVERLAY - Completely separate from main content
        .overlay(
            Group {
                if commentsManager.isPresented {
                    modalOverlay
                }
            }
        )
        .sheet(isPresented: $showCreatePost) {
            CreatePostView(feedViewModel: feedViewModel)
        }
        .sheet(isPresented: $showNewMessage) {
            NewMessageView(onChatSelected: { conversation, channel in
                // Dismiss the sheet first
                showNewMessage = false

                // Small delay to let sheet dismiss before showing chat
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedConversation = conversation
                        selectedChannel = channel
                        showingChat = true
                    }
                }
            })
        }
        .fullScreenCover(item: $menuDestination) { destination in
            NavigationView {
                destinationView(for: destination)
            }
            .navigationViewStyle(.stack)
        }
        .alert("Verification Required", isPresented: $showPostVerificationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You can browse all posts, but posting is only available after verification.")
        }
    }

    @ViewBuilder
    private func destinationView(for destination: MenuDestination) -> some View {
        switch destination {
        case .liked:
            LikedPostsView()
        case .saved:
            SavedPostsView()
        case .privacy:
            PrivacyView()
        case .drafts:
            DraftsView()
        case .analytics:
            AnalyticsView()
        case .faq:
            FAQView()
        case .settings:
            SettingsView()
        }
    }
    
    private var modalOverlay: some View {
        ZStack {
            // Background dimming - covers entire screen including safe area
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    commentsManager.dismissComments()
                }

            // Modal content with post above
            VStack(spacing: 0) {
                Spacer()

                // Post display above comments (TikTok style)
                if let post = commentsManager.currentPost {
                    VStack(spacing: 0) {
                        SimplifiedPostCard(post: post)

                        // Separator line
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.loopedTextSecondary.opacity(0.1))
                    }
                    .background(Color.loopedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                // Comments modal
                VStack(spacing: 0) {
                    // Modal handle
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.loopedTextSecondary.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    // Comments content
                    if let post = commentsManager.currentPost {
                        CommentsView(
                            post: post
                        ) {
                            commentsManager.dismissComments()
                        }
                        .environmentObject(commentsManager)
                    }
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.75)
                .background(Color.loopedBackground)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
            }
            .transition(.move(edge: .bottom))
        }
    }

    private var canCreatePost: Bool {
        authViewModel.currentUser?.isVerified == true
    }
}

#Preview {
    ContentView()
}
