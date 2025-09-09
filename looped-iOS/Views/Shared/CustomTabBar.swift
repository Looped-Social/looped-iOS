import SwiftUI

// MARK: - Tab Items Enum
enum TabItem: String, CaseIterable {
    case home = "Home"
    case messages = "Messages" 
    case search = "Search"
    case notifications = "Notifications"
    case profile = "Profile"
    
    var iconName: String {
        switch self {
        case .home:
            return "home-icon"
        case .messages:
            return "messages-icon"
        case .search:
            return "search-icon"
        case .notifications:
            return "notifications-icon"
        case .profile:
            return "profile-icon"
        }
    }
    
    var iconSize: CGSize {
        switch self {
        case .home:
            return CGSize(width: 35, height: 35)
        case .messages:
            return CGSize(width: 27, height: 27)
        case .search:
            return CGSize(width: 30, height: 30)
        case .notifications:
            return CGSize(width: 35, height: 35)
        case .profile:
            return CGSize(width: 30, height: 30)
        }
    }
}

// MARK: - Custom Tab Bar View
struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    
    var body: some View {
        VStack(spacing: 0) {
            // Top border line
            Rectangle()
                .frame(height: 0.2)
                .foregroundColor(Color("BorderColor"))
            
            HStack(spacing: 0) {
                ForEach(TabItem.allCases, id: \.self) { tab in
                    TabBarButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 20)
            .background(Color.loopedSurface)
            .padding(.bottom, 0)
        }
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Group {
                        Image(tab.iconName)
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: tab.iconSize.width, height: tab.iconSize.height)
                   
                }
                .foregroundColor(isSelected ? .loopedPrimary : .loopedTextSecondary)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
}
