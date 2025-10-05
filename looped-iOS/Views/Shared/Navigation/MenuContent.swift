import SwiftUI

struct MenuContent: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var isAnonymous: Bool = false

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Profile Header Section
            VStack(alignment: .center, spacing: 16) {
                // Profile Avatar
                Circle()
                    .fill(Color.loopedTextPrimary)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    )
                    .padding(.top, 60)

                // Display Name
                Text(viewModel.user?.displayName ?? "Billy Bob")
                    .font(.loopedBodyStrong32)
                    .foregroundColor(.loopedContrast)

                // Anonymous Status Toggle
                Button(action: {
                    isAnonymous.toggle()
                    Task {
                        await viewModel.updateProfile(
                            displayName: viewModel.user?.displayName,
                            isAnonymous: isAnonymous
                        )
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("Anonymous Status:")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(isAnonymous ? Color(red: 0.2, green: 0.8, blue: 0.7) : .loopedTextSecondary)
                        Text(isAnonymous ? "ON" : "OFF")
                            .font(.loopedSubBodyBold)
                            .foregroundColor(isAnonymous ? Color(red: 0.2, green: 0.8, blue: 0.7) : .loopedTextSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isAnonymous ? Color(red: 0.2, green: 0.8, blue: 0.7) : .loopedTextSecondary.opacity(0.3), lineWidth: 1.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Hearts Metric
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                    Text("10K Hearts")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)

            // Menu Items
            VStack(alignment: .leading, spacing: 0) {
                MenuItemRow(icon: "heart", title: "Liked", destination: AnyView(LikedPostsView()))
                MenuItemRow(icon: "bookmark", title: "Saved", destination: AnyView(SavedPostsView()))
                MenuItemRow(icon: "lock", title: "Privacy", destination: AnyView(PrivacyView()))
                MenuItemRow(icon: "doc.text", title: "Drafts", destination: AnyView(DraftsView()))
                MenuItemRow(icon: "chart.bar", title: "Analytics", destination: AnyView(AnalyticsView()))
                MenuItemRow(icon: "questionmark.circle", title: "FAQ", destination: AnyView(FAQView()))
            }
            .padding(.horizontal, 24)

            Spacer()

            // Settings Button (Bottom Right)
            HStack {
                Spacer()
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.loopedTextSecondary)
                        .padding(20)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.loopedBackground.ignoresSafeArea(.all))
        .task {
            await viewModel.loadUserProfile()
            isAnonymous = viewModel.user?.isAnonymous ?? false
        }
    }
}

// Menu Item Row Component
struct MenuItemRow: View {
    let icon: String
    let title: String
    let destination: AnyView

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.loopedTextSecondary)
                    .frame(width: 24)

                Text(title)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.loopedTextSecondary.opacity(0.5))
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Placeholder Views
struct LikedPostsView: View {
    var body: some View {
        VStack {
            Text("Liked Posts")
                .font(.loopedHeadingMedium)
                .foregroundColor(.loopedTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SavedPostsView: View {
    var body: some View {
        VStack {
            Text("Saved Posts")
                .font(.loopedHeadingMedium)
                .foregroundColor(.loopedTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyView: View {
    var body: some View {
        VStack {
            Text("Privacy Settings")
                .font(.loopedHeadingMedium)
                .foregroundColor(.loopedTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DraftsView: View {
    var body: some View {
        VStack {
            Text("Drafts")
                .font(.loopedHeadingMedium)
                .foregroundColor(.loopedTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AnalyticsView: View {
    var body: some View {
        VStack {
            Text("Analytics")
                .font(.loopedHeadingMedium)
                .foregroundColor(.loopedTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FAQView: View {
    var body: some View {
        VStack {
            Text("FAQ")
                .font(.loopedHeadingMedium)
                .foregroundColor(.loopedTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    MenuContent()
        .background(Color.loopedBackground)
}
