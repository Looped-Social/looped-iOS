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
                    // Company circles section (starts from top, extending into safe area)
                    CompanyStackView(
                        companies: MockCompanies.companies,
                        selectedIndex: $selectedCompanyIndex
                    )
                    .ignoresSafeArea(.all, edges: .top)

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
//                        .padding(.top, 24)

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
