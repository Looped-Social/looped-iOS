import SwiftUI

struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "road.lanes")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.loopedTextSecondary.opacity(0.7))
                .padding(.bottom, 2)

            Text("End of the road")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            Text("No posts yet. Be the first to start something your coworkers actually want to read.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 56)
        .padding(.bottom, 24)
    }
}

#Preview {
    EmptyFeedView()
        .background(Color.loopedBackground.ignoresSafeArea())
}

