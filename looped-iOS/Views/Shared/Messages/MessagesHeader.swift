import SwiftUI

struct MessagesHeader: View {
    let title: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        HStack {
            Image("logo-banner")
                .resizable()
                .scaledToFit()
                .frame(height: bannerHeight)

            Spacer()

            // Right side: Dynamic title
            Text(title)
                .font(.loopedLogo)
                .foregroundColor(.loopedTextPrimary)
        }
        .padding(.horizontal, 16)
    }

    private var bannerHeight: CGFloat {
        horizontalSizeClass == .regular ? 80 : 60
    }
}

#Preview {
    VStack {
        MessagesHeader(title: "Messages")
        Spacer()
    }
    .background(Color.loopedBackground)
}
