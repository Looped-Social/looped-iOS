import SwiftUI

struct MessagesHeader: View {
    let title: String

    var body: some View {
        HStack {
            // Left side: Looped logo/text
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    // Logo
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 32)

                    Text("ooped")
                        .font(.loopedHeading)
                        .foregroundColor(.loopedContrast)
                }
            }

            Spacer()

            // Right side: Dynamic title
            Text(title)
                .font(.loopedLogo)
                .foregroundColor(.loopedTextPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack {
        MessagesHeader(title: "Messages")
        Spacer()
    }
    .background(Color.loopedBackground)
}
