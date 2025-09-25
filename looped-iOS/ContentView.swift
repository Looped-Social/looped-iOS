//
//  ContentView.swift
//  looped-iOS
//
//  Created by William Millen on 9/5/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                AuthView(authViewModel: authViewModel)
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: TabItem = .home
    @State private var showCreatePost = false
    @State private var showNewMessage = false
    @State private var isMenuOpen = false
    @State private var isRightMenuOpen = false
    @State private var showingChat = false
    @State private var selectedConversation: Conversation?
    @State private var selectedChannel: Channel?
    @StateObject private var feedViewModel = FeedViewModel()
    @StateObject private var commentsManager = CommentsModalManager()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Side Menu (only visible on home tab)
                if selectedTab == .home {
                    HStack(spacing: 0) {
                        // Menu content constrained to 80% width with full background
                        SideMenuView(selectedTab: $selectedTab, isMenuOpen: $isMenuOpen)
                            .frame(width: geometry.size.width * 0.8)
                            .background(Color.loopedBackground.ignoresSafeArea(.all))
                            .contentShape(Rectangle())

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.loopedBackground.ignoresSafeArea(.all))
                    .offset(x: isMenuOpen ? 0 : -geometry.size.width * 0.8)
                    .allowsHitTesting(isMenuOpen)
                }

                // Right Menu (only visible on home tab)
                if selectedTab == .home {
                    HStack(spacing: 0) {
                        Spacer()

                        // Menu content constrained to 80% width with full background
                        MenuContent()
                            .frame(width: geometry.size.width * 0.8)
                            .background(Color.loopedBackground.ignoresSafeArea(.all))
                            .contentShape(Rectangle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.loopedBackground.ignoresSafeArea(.all))
                    .offset(x: isRightMenuOpen ? 0 : geometry.size.width * 0.8)
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
                                    onMenuToggle: {
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                            isRightMenuOpen = false // Close right menu if open
                                            isMenuOpen.toggle()
                                        }
                                    },
                                    onProfileTap: {
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                            isMenuOpen = false // Close left menu if open
                                            isRightMenuOpen.toggle()
                                        }
                                    }
                                )
                                    .environmentObject(feedViewModel)
                                    .environmentObject(commentsManager)
                            }
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
                        case .search:
                            SearchView()
                        case .notifications:
                            NotificationsView()
                        case .profile:
                            NavigationView {
                                ProfileView()
                            }
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
                        if selectedTab == .home && (isMenuOpen || isRightMenuOpen) {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        isMenuOpen = false
                                        isRightMenuOpen = false
                                    }
                                }
                                .allowsHitTesting(true)
                        }
                    }
                )
                .offset(x: selectedTab == .home ? (isMenuOpen ? geometry.size.width * 0.8 : (isRightMenuOpen ? -geometry.size.width * 0.8 : 0)) : 0)
                .scaleEffect((selectedTab == .home && (isMenuOpen || isRightMenuOpen)) ? 0.95 : 1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isMenuOpen)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isRightMenuOpen)

                // Shadow overlays - feed casting shadow onto drawers
                if selectedTab == .home {
                    // Left shadow - instantly visible/invisible
                    HStack(spacing: 0) {
                        Spacer()
                            .frame(width: geometry.size.width * 0.8 - 20)

                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.2),
                                Color.black.opacity(0.1),
                                Color.black.opacity(0.05),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 20)

                        Spacer()
                            .frame(width: geometry.size.width * 0.2)
                    }
                    .opacity(isMenuOpen ? 1 : 0)
                    .animation(.linear(duration: 0.0), value: isMenuOpen)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)

                    // Right shadow - instantly visible/invisible
                    HStack(spacing: 0) {
                        Spacer()
                            .frame(width: geometry.size.width * 0.2)

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
                            .frame(width: geometry.size.width * 0.8 - 20)
                    }
                    .opacity(isRightMenuOpen ? 1 : 0)
                    .animation(.linear(duration: 0.0), value: isRightMenuOpen)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)
                }

                // Floating Action Button (show on home and messages tabs)
                if selectedTab == .home && !commentsManager.isPresented && !isMenuOpen && !isRightMenuOpen {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            FloatingActionButton {
                                showCreatePost = true
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 90) // Position above tab bar
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
        .animation(.easeInOut(duration: 0.3), value: commentsManager.isPresented)
        .animation(.easeInOut(duration: 0.3), value: showingChat)
        .sheet(isPresented: $showCreatePost) {
            CreatePostView(feedViewModel: feedViewModel)
        }
        .sheet(isPresented: $showNewMessage) {
            NewMessageView()
        }
    }
    
    private var modalOverlay: some View {
        ZStack {
            // Background dimming
            Color.black.opacity(0.5)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        commentsManager.dismissComments()
                    }
                }
            
            // Modal content with post above
            VStack(spacing: 0) {
                Spacer()
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.15) // Reduce spacer to move everything higher
                
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
                            post: post, 
                            comments: commentsManager.currentComments
                        ) {
                            commentsManager.dismissComments()
                        }
                    }
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.5) // Reduced height to make room for post
                .background(
//                    Color.loopedBackground.ignoresSafeArea()
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

#Preview {
    ContentView()
}
