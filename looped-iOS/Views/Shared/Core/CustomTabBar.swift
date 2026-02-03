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

    var selectedIconName: String {
        switch self {
        case .home:
            return "home-selected"
        case .messages:
            return "messages-selected"
        case .search:
            return "search-selected"
        case .notifications:
            return "bell-selected"
        case .profile:
            return "profile-selected"
        }
    }
    
    static let iconSize = CGSize(width: 28, height: 28)
}

// MARK: - Custom Tab Bar View
struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    let showsUpdateDot: (TabItem) -> Bool
    let onReselect: ((TabItem) -> Void)?
    @AppStorage("anonymousMode") private var isAnonymous = false

    init(
        selectedTab: Binding<TabItem>,
        showsUpdateDot: @escaping (TabItem) -> Bool = { _ in false },
        onReselect: ((TabItem) -> Void)? = nil
    ) {
        _selectedTab = selectedTab
        self.showsUpdateDot = showsUpdateDot
        self.onReselect = onReselect
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top border line
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.loopedTextSecondary.opacity(0.1))
            
            HStack(spacing: 0) {
                ForEach(visibleTabs, id: \.self) { tab in
                    TabBarButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        showsUpdateDot: showsUpdateDot(tab)
                    ) {
                        if selectedTab == tab {
                            onReselect?(tab)
                        } else {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
            .padding(.horizontal, 20)
            .background(Color.loopedBackground.ignoresSafeArea(.all, edges: .bottom))
            .padding(.bottom, 0)
        }
        .background(
            GeometryReader { proxy in
                Color.loopedClear
                    .preference(key: LoopedTabBarHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onChange(of: isAnonymous) { _, newValue in
            if newValue && selectedTab == .messages {
                selectedTab = .home
            }
        }
        .onAppear {
            if isAnonymous && selectedTab == .messages {
                selectedTab = .home
            }
        }
    }

    private var visibleTabs: [TabItem] {
        if isAnonymous {
            return TabItem.allCases.filter { $0 != .messages }
        }
        return TabItem.allCases
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let showsUpdateDot: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Group {
                if tab == .search {
                    tabIcon
                        .coachMarkTarget(.mainTabSearch)
                } else {
                    tabIcon
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var tabIcon: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Image(isSelected ? tab.selectedIconName : tab.iconName)
                    .resizable()
                    .renderingMode(isSelected ? .original : .template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: TabItem.iconSize.width, height: TabItem.iconSize.height)
                    .foregroundColor(isSelected ? nil : .loopedTextSecondary)

                if showsUpdateDot {
                    Circle()
                        .fill(Color.loopedSecondary)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.loopedBackground, lineWidth: 1)
                        )
                        .offset(x: 6, y: -2)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(nil, value: isSelected)
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
}
