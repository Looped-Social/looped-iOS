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
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Feed")
                }
            
            MessagesView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Messages")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
        }
    }
}

#Preview {
    ContentView()
}
