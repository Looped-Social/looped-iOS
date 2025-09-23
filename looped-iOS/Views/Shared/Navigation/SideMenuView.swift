import SwiftUI

struct SideMenuView: View {
    @Binding var selectedTab: TabItem
    @Binding var isMenuOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header area
            VStack(alignment: .leading, spacing: 16) {
                // Logo and title
                HStack(spacing: 8) {
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 32)

                    Text("ooped")
                        .font(.loopedHeading)
                        .foregroundColor(.loopedContrast)
                }
                .padding(.top, 60)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)

            // Navigation menu items
            VStack(alignment: .leading, spacing: 0) {
                SideMenuButton(icon: "house.fill", title: "Home", action: {
                    selectedTab = .home
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isMenuOpen = false
                    }
                })
                SideMenuButton(icon: "magnifyingglass", title: "Explore", action: {
                    selectedTab = .search
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isMenuOpen = false
                    }
                })
                SideMenuButton(icon: "bell", title: "Notifications", action: {
                    selectedTab = .notifications
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isMenuOpen = false
                    }
                })
                SideMenuButton(icon: "envelope", title: "Messages", action: {
                    selectedTab = .messages
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isMenuOpen = false
                    }
                })
                SideMenuButton(icon: "bookmark", title: "Bookmarks", action: {
                    // TODO: Implement bookmarks functionality
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isMenuOpen = false
                    }
                })
                SideMenuButton(icon: "person", title: "Profile", action: {
                    selectedTab = .profile
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isMenuOpen = false
                    }
                })
                SideMenuButton(icon: "gear", title: "Settings", action: {
                    // TODO: Implement settings navigation
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isMenuOpen = false
                    }
                })
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.loopedBackground.ignoresSafeArea(.all))
    }
}

struct SideMenuButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.loopedTextSecondary)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    @State var selectedTab: TabItem = .home
    @State var isMenuOpen = true

    return SideMenuView(selectedTab: $selectedTab, isMenuOpen: $isMenuOpen)
}