import SwiftUI

struct FeedHeader: View {
    let onMenuToggle: () -> Void
    let onProfileTap: () -> Void

    init(onMenuToggle: @escaping (() -> Void) = {}, onProfileTap: @escaping (() -> Void) = {}) {
        self.onMenuToggle = onMenuToggle
        self.onProfileTap = onProfileTap
    }

    var body: some View {
        HStack {
            // Left side: Hamburger menu and Looped text
            HStack(spacing: 0) {
                // Hamburger menu button
                Button(action: {
                    onMenuToggle()
                }) {
                    VStack(spacing: 5) {
                        Rectangle()
                            .frame(width: 22, height: 2.5)
                            .foregroundColor(.loopedContrast)
                        Rectangle()
                            .frame(width: 22, height: 2.5)
                            .foregroundColor(.loopedContrast)
                        Rectangle()
                            .frame(width: 22, height: 2.5)
                            .foregroundColor(.loopedContrast)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .zIndex(10)
                .onTapGesture {
                    onMenuToggle()
                }
                
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
                        .fill(Color.loopedPrimary)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
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
        .padding(.vertical, 2)
    }
}

#Preview {
    FeedHeader()
    FeedTabs()
}
