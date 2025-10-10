import SwiftUI

struct FeedHeader: View {
    let onProfileTap: () -> Void

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
            
            // Profile avatar
            Button(action: {
                onProfileTap()
            }) {
                AsyncImage(url: URL(string: "https://via.placeholder.com/36")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.loopedTextSecondary.opacity(0.1))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.loopedTextSecondary)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .zIndex(100)
            .onTapGesture {
                onProfileTap()
            }
        }
        .padding(.horizontal, 16)
//        .padding(.vertical, 2)
    }
}

#Preview {
    FeedHeader()
    FeedTabs()
}
