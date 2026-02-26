import SwiftUI

struct ConversationRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.loopedTextSecondary.opacity(0.18))
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.loopedTextSecondary.opacity(0.18))
                    .frame(width: 160, height: 14)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.loopedTextSecondary.opacity(0.14))
                    .frame(height: 14)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.loopedTextSecondary.opacity(0.12))
                    .frame(width: 44, height: 12)

                Circle()
                    .fill(Color.loopedTextSecondary.opacity(0.10))
                    .frame(width: 20, height: 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.loopedBackground)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 0) {
        ForEach(0..<6, id: \.self) { _ in
            ConversationRowSkeleton()
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.loopedTextSecondary.opacity(0.1))
                .padding(.leading, 78)
        }
    }
    .background(Color.loopedBackground)
}
