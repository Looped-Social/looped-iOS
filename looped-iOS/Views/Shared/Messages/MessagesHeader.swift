import SwiftUI

struct MessagesHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.loopedHeaderStrong)
                .foregroundColor(.loopedTextPrimary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

#Preview {
    VStack {
        MessagesHeader(title: "Messages")
        Spacer()
    }
    .background(Color.loopedBackground)
}
