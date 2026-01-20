import SwiftUI

enum MessageTab: String, CaseIterable {
    case messages = "Messages"
    case groups = "Groups"
    case requests = "Requests"
}

struct MessagesTabs: View {
    @Binding var selectedTab: MessageTab

    var body: some View {
        HStack(spacing: 10) {
            ForEach(MessageTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    Text(tab.rawValue)
                        .font(selectedTab == tab ? .loopedSubBodyBold : .loopedSubBodyMedium)
                        .foregroundColor(selectedTab == tab ? .loopedWhite : .loopedTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity)
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
