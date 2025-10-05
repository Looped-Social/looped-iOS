import SwiftUI

enum ProfileTab: String, CaseIterable {
    case posts = "Posts"
    case replies = "Replies"
    case saved = "Saved"
}

struct ProfileView: View {
    @State private var selectedTab: ProfileTab = .posts
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Profile Header
            ProfileHeaderView()
            
            // Stats Section
            ProfileStatsView()
            
            // Action Buttons
            ProfileActionButtons()
            
            // Tab Navigation
            ProfileTabsView(selectedTab: $selectedTab)
            
            // Content based on selected tab
            Spacer()
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.loadUserProfile()
        }
    }
}

struct ProfileHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Profile Avatar with Name and Handle beside it
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: "https://via.placeholder.com/80")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.loopedTextSecondary.opacity(0.1))
                        .overlay(
                            Image("profile-icon")
                                .renderingMode(.template)
                                .font(.system(size: 32))
                                .foregroundColor(.loopedTextSecondary)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                
                // Name and Handle beside profile picture
                VStack(alignment: .leading, spacing: 4) {
                    Text("Billy Bob")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.loopedTextPrimary)
                    
                    Text("@billy.bob24")
                        .font(.subheadline)
                        .foregroundColor(.loopedTextSecondary)
                }
                
                Spacer()
            }
            
            // Bio - left aligned
            Text("Hello, i am Billy Bob. Always looking for new connections. Feel free to reach out!")
                .font(.body)
                .foregroundColor(.loopedTextPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
    }
}

struct ProfileStatsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Years in Loop and Company - left aligned
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(.loopedTextSecondary)
                        .font(.system(size: 16))
                    
                    Text("2 years in the Loop")
                        .font(.subheadline)
                        .foregroundColor(.loopedTextSecondary)
                    
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    // Google logo placeholder
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text("G")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    Text("Works at Google")
                        .font(.subheadline)
                        .foregroundColor(.loopedTextSecondary)
                    
                    Spacer()
                }
            }
            
            // Follower Stats - left aligned
            HStack(spacing: 16) {
                Text("100")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.loopedTextPrimary)
                +
                Text(" Following")
                    .font(.subheadline)
                    .foregroundColor(.loopedTextSecondary)
                
                Text("123")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.loopedTextPrimary)
                +
                Text(" Followers")
                    .font(.subheadline)
                    .foregroundColor(.loopedTextSecondary)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

struct ProfileActionButtons: View {
    var body: some View {
        HStack(spacing: 64) {
            Button(action: {
                // TODO: Handle edit profile
            }) {
                Text("Edit Profile")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.loopedTextPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.loopedTextSecondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())

            NavigationLink(destination: SettingsView()) {
                Text("Settings")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.loopedTextPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.loopedTextSecondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 10)
    }
}

struct ProfileTabsView: View {
    @Binding var selectedTab: ProfileTab
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        Text(tab.rawValue)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTab == tab ? .loopedPrimary : .loopedTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            
            // Full-width underlines
            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Rectangle()
                        .frame(height: selectedTab == tab ? 2 : 1)
                        .foregroundColor(selectedTab == tab ? .loopedPrimary : .loopedTextSecondary.opacity(0.3))
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea(.all, edges: .horizontal))
    }
}

#Preview {
    ProfileView()
}
