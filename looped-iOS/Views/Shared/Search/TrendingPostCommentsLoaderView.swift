import SwiftUI

struct TrendingPostCommentsLoaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.loopedMutedBackground)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.loopedMutedBackground)
                            .frame(width: 120, height: 12)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.loopedMutedBackground)
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.loopedMutedBackground)
                            .frame(width: 180, height: 12)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.loopedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shimmering()
        .accessibilityLabel("Loading comments")
    }
}

#Preview {
    TrendingPostCommentsLoaderView()
        .padding()
        .background(Color.loopedBackground)
}
