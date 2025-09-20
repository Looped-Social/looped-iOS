import SwiftUI

struct MessagesHeader: View {
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

            // Right side: Messages title
            Text("Messages")
                .font(.loopedHeading)
                .foregroundColor(.loopedTextPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack {
        MessagesHeader()
        Spacer()
    }
    .background(Color.loopedBackground)
}