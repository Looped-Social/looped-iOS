import SwiftUI

struct FeedHeader: View {
    let onProfileTap: () -> Void
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
                    Group {
                        if authViewModel.currentUser?.isAnonymous == true {
                            Circle()
                                .fill(Color.loopedTextSecondary.opacity(0.1))
                                .overlay(
                                    Text(initials)
                                        .font(.loopedCustom(.semibold, size: 16))
                                        .foregroundColor(.loopedTextPrimary)
                                )
                                .frame(width: 40, height: 40)
                        } else {
                            ProfileAvatarView(
                                imageURL: authViewModel.currentUser?.profileImageURL,
                                size: 40
                            )
                        }
                    }
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

    private var initials: String {
        if let name = authViewModel.currentUser?.displayName,
           let first = name.split(separator: " ").first?.first {
            return String(first).uppercased()
        }
        return "LU"
    }
}

// Preview intentionally omitted since FeedHeader depends on runtime auth state.
