import SwiftUI

struct EmptyMessagesView: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let onButtonTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.loopedCustom(.semibold, size: 36))
                .foregroundColor(.loopedTextSecondary.opacity(0.7))
                .padding(.bottom, 2)

            Text(title)
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            Text(subtitle)
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button(buttonTitle) {
                onButtonTap()
            }
            .font(.loopedBodyMedium)
            .foregroundColor(.loopedPrimary)
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 56)
        .padding(.bottom, 24)
    }
}

#Preview {
    EmptyMessagesView(
        title: "No messages yet",
        subtitle: "It’s quiet in here. Start a new chat and make it awkward on purpose.",
        buttonTitle: "Start a new message",
        onButtonTap: { }
    )
    .background(Color.loopedBackground.ignoresSafeArea())
}

