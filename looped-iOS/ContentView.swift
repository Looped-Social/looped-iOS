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
    @State private var isMenuOpen = false
    @StateObject private var feedViewModel = FeedViewModel()
    @StateObject private var commentsManager = CommentsModalManager()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Side Menu (only visible on home tab)
                if selectedTab == .home {
                    SideMenuView()
                        .frame(width: geometry.size.width * 0.8)
                        .offset(x: isMenuOpen ? 0 : -geometry.size.width * 0.8)
                }

                // Main app content
                VStack(spacing: 0) {
                    // Content Area
                    NavigationView {
                        Group {
                            switch selectedTab {
                            case .home:
                                FeedView(onMenuToggle: {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        isMenuOpen.toggle()
                                    }
                                })
                                    .environmentObject(feedViewModel)
                                    .environmentObject(commentsManager)
                            case .messages:
                                MessagesView()
                            case .search:
                                SearchView()
                            case .notifications:
                                NotificationsView()
                            case .profile:
                                ProfileView()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Custom Tab Bar
                    CustomTabBar(selectedTab: $selectedTab)
                }
                .background(Color.loopedBackground)
                .overlay(
                    // Overlay to darken content when menu is open (only on home tab)
                    Group {
                        if selectedTab == .home {
                            Color.black.opacity(isMenuOpen ? 0.3 : 0)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        isMenuOpen = false
                                    }
                                }
                                .allowsHitTesting(isMenuOpen)
                        }
                    }
                )
                .offset(x: (selectedTab == .home && isMenuOpen) ? geometry.size.width * 0.8 : 0)
                .scaleEffect((selectedTab == .home && isMenuOpen) ? 0.95 : 1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isMenuOpen)
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            guard selectedTab == .home else { return }
                            let threshold: CGFloat = 50
                            if isMenuOpen && value.translation.width < -threshold {
                                // Swipe left to close menu
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    isMenuOpen = false
                                }
                            } else if !isMenuOpen && value.translation.width > threshold {
                                // Swipe right to open menu
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    isMenuOpen = true
                                }
                            }
                        }
                )
                
                // Floating Action Button (only show on home tab when menu is closed)
                if selectedTab == .home && !commentsManager.isPresented && !isMenuOpen {
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
        .sheet(isPresented: $showCreatePost) {
            CreatePostView(feedViewModel: feedViewModel)
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
                    Color.loopedBackground
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
