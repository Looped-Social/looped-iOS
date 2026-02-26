import SwiftUI

struct PostCardSkeleton: View {
    let showsMedia: Bool

    init(showsMedia: Bool = true) {
        self.showsMedia = showsMedia
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.loopedTextSecondary.opacity(0.18))
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.loopedTextSecondary.opacity(0.18))
                            .frame(width: 140, height: 14)

                        Spacer()

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.loopedTextSecondary.opacity(0.14))
                            .frame(width: 22, height: 14)
                    }

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.loopedTextSecondary.opacity(0.14))
                        .frame(width: 110, height: 12)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.loopedTextSecondary.opacity(0.16))
                    .frame(height: 14)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.loopedTextSecondary.opacity(0.14))
                    .frame(height: 14)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.loopedTextSecondary.opacity(0.12))
                    .frame(width: 220, height: 14)
            }

            if showsMedia {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.loopedTextSecondary.opacity(0.12))
                    .frame(height: 200)
            }

            HStack(spacing: 18) {
                actionPill(width: 64)
                actionPill(width: 64)
                actionPill(width: 74)
                Spacer()
                actionPill(width: 64)
            }

            RoundedRectangle(cornerRadius: 6)
                .fill(Color.loopedTextSecondary.opacity(0.12))
                .frame(width: 84, height: 12)
        }
        .padding(16)
        .background(Color.loopedBackground)
        .accessibilityHidden(true)
    }

    private func actionPill(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.loopedTextSecondary.opacity(0.12))
            .frame(width: width, height: 20)
    }
}

#Preview {
    VStack(spacing: 0) {
        PostCardSkeleton(showsMedia: true)
        Rectangle()
            .frame(height: 1)
            .foregroundColor(.loopedTextSecondary.opacity(0.1))
        PostCardSkeleton(showsMedia: false)
    }
    .background(Color.loopedBackground)
}
