import SwiftUI

enum MessageTab: String, CaseIterable {
    case messages = "Messages"
    case groups = "Groups"
    case requests = "Requests"
}

struct MessagesTabs: View {
    @Binding var selectedTab: MessageTab
    let pendingRequestCount: Int

    init(selectedTab: Binding<MessageTab>, pendingRequestCount: Int = 0) {
        _selectedTab = selectedTab
        self.pendingRequestCount = pendingRequestCount
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(MessageTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    ZStack(alignment: .topTrailing) {
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

                        if tab == .requests, pendingRequestCount > 0 {
                            Text(badgeText)
                                .font(.loopedSmallTextMedium)
                                .foregroundColor(.loopedWhite)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.loopedSecondary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.loopedBackground, lineWidth: 1)
                                )
                                .offset(x: 10, y: -6)
                                .accessibilityLabel("\(pendingRequestCount) message requests")
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var badgeText: String {
        pendingRequestCount > 99 ? "99+" : "\(pendingRequestCount)"
    }
}

	#Preview {
	    @State var selectedTab: MessageTab = .messages

	    return VStack {
	        MessagesTabs(selectedTab: $selectedTab, pendingRequestCount: 3)
	        Spacer()
	    }
	    .background(Color.loopedBackground)
	}
