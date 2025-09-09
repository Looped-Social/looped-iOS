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
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Content Area
                NavigationView {
                    Group {
                        switch selectedTab {
                        case .home:
                            FeedView()
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
            
            // Floating Action Button (only show on home tab)
            if selectedTab == .home {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingActionButton {
                            // TODO: Handle create post action
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 90) // Position above tab bar
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
