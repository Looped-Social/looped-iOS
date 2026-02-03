import SwiftUI

struct FeedHeader: View {
    let onProfileTap: () -> Void
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("anonymousMode") private var isAnonymousMode = false

    init(onProfileTap: @escaping (() -> Void) = {}) {
        self.onProfileTap = onProfileTap
    }

    var body: some View {
        HStack {
            Image("logo-banner")
                .resizable()
                .scaledToFit()
                .frame(height: bannerHeight)
            
            Spacer()
            
            HStack(spacing: 10) {
                Button(action: {
                    onProfileTap()
                }) {
                    ProfileAvatarView(
                        imageURL: authViewModel.currentUser?.profileImageURL,
                        size: 40,
                        variant: isAnonymousMode ? .anonymous : .standard
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
//        .padding(.vertical, 2)
    }

    private var bannerHeight: CGFloat {
        horizontalSizeClass == .regular ? 80 : 60
    }
}

// Preview intentionally omitted since FeedHeader depends on runtime auth state.
