import SwiftUI

struct SideMenuView: View {
    @Binding var selectedTab: TabItem
    @Binding var isMenuOpen: Bool
    @State private var selectedCompanyIndex = 0
    @State private var conversations: [Conversation] = []

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content with unified ScrollView
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Safe area spacing at top
                    Color.clear
                        .frame(height: 40)

                    // Company circles section
                    CompanyStackView(
                        companies: MockCompanies.companies,
                        selectedIndex: $selectedCompanyIndex
                    )

                    // Messages section
                    VStack(alignment: .leading, spacing: 12) {
                        // Messages header
                        HStack {
                            Text("Messages")
                                .font(.loopedHeadingMedium)
                                .foregroundColor(.loopedTextPrimary)

                            Spacer()

                            Button(action: {
                                // Navigate to messages
                                selectedTab = .messages
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    isMenuOpen = false
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.loopedTextSecondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                        // Message list
                        VStack(spacing: 0) {
                            ForEach(conversations.prefix(5)) { conversation in
                                Button(action: {
                                    // Navigate to specific conversation
                                    selectedTab = .messages
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        isMenuOpen = false
                                    }
                                }) {
                                    DrawerMessageRow(conversation: conversation)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .background(Color.loopedBackground)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.loopedBackground.ignoresSafeArea(.all))
            .clipped()

            // Profile icon (top right)
            Button(action: {
                selectedTab = .profile
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isMenuOpen = false
                }
            }) {
                Circle()
                    .fill(Color.loopedPrimary.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.loopedPrimary)
                    )
            }
            .padding(.top, 60)
            .padding(.trailing, 20)
        }
        .task {
            loadConversations()
        }
    }

    private func loadConversations() {
        conversations = MockConversations.conversations
    }
}

#Preview {
    @Previewable @State var selectedTab: TabItem = .home
    @Previewable @State var isMenuOpen = true

    return SideMenuView(selectedTab: $selectedTab, isMenuOpen: $isMenuOpen)
        .background(Color.loopedBackground)
}