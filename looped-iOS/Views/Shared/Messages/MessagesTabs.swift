import SwiftUI

enum MessageTab: String, CaseIterable {
    case messages = "Messages"
    case groups = "Groups"
    case requests = "Requests"
}

struct MessagesTabs: View {
    @Binding var selectedTab: MessageTab

    var body: some View {
        HStack(spacing: 12) {
            ForEach(MessageTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    Text(tab.rawValue)
                        .font(selectedTab == tab ? .loopedSubBodyBold : .loopedSubBodyMedium)
                        .foregroundColor(selectedTab == tab ? .loopedWhite : .loopedTextSecondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTab == tab ? Color.loopedPrimary : Color.loopedClear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selectedTab == tab ? Color.loopedClear : Color.loopedTextSecondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    @State var selectedTab: MessageTab = .messages

    return VStack {
        MessagesTabs(selectedTab: $selectedTab)
        Spacer()
    }
    .background(Color.loopedBackground)
}
