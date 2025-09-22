import SwiftUI

struct SideMenuView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header area
            VStack(alignment: .leading, spacing: 16) {
                // Logo and title
                HStack(spacing: 8) {
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 32)

                    Text("ooped")
                        .font(.loopedHeading)
                        .foregroundColor(.loopedContrast)
                }
                .padding(.top, 60)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)

            // Navigation menu items
            VStack(alignment: .leading, spacing: 0) {
                SideMenuButton(icon: "house.fill", title: "Home")
                SideMenuButton(icon: "magnifyingglass", title: "Explore")
                SideMenuButton(icon: "bell", title: "Notifications")
                SideMenuButton(icon: "envelope", title: "Messages")
                SideMenuButton(icon: "bookmark", title: "Bookmarks")
                SideMenuButton(icon: "person", title: "Profile")
                SideMenuButton(icon: "gear", title: "Settings")
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.loopedBackground.ignoresSafeArea(.all))
    }
}

struct SideMenuButton: View {
    let icon: String
    let title: String

    var body: some View {
        Button(action: {
            // TODO: Handle navigation
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.loopedTextSecondary)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SideMenuView()
}