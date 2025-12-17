import SwiftUI

struct FeedHeader: View {
    let onProfileTap: () -> Void
    @EnvironmentObject private var authViewModel: AuthViewModel

    init(onProfileTap: @escaping (() -> Void) = {}) {
        self.onProfileTap = onProfileTap
    }

    var body: some View {
        HStack {
            // Looped logo/text
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
            
            HStack(spacing: 10) {
                Button(action: {
                    onProfileTap()
                }) {
                    Circle()
                        .fill(Color.loopedTextSecondary.opacity(0.1))
                        .overlay(
                            Text(initials)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.loopedTextPrimary)
                        )
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
//        .padding(.vertical, 2)
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
