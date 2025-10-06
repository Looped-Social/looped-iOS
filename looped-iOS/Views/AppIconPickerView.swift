import SwiftUI

struct AppIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var iconManager = AppIconManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppIconPickerHeader {
                dismiss()
            }

            // Icon Grid
            ScrollView {
                VStack(spacing: 0) {
                    Text("Choose your app icon")
                        .font(.loopedBodyStrong)
                        .foregroundColor(.loopedTextSecondary)
                        .padding(.top, 24)
                        .padding(.bottom, 16)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 24) {
                        ForEach(AppIconManager.AppIcon.allCases) { icon in
                            AppIconCell(
                                icon: icon,
                                isSelected: iconManager.currentIcon == icon
                            ) {
                                changeIcon(to: icon)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .alert("Icon Changed", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func changeIcon(to icon: AppIconManager.AppIcon) {
        iconManager.setIcon(icon) { success, error in
            if success {
                alertMessage = "App icon changed to \(icon.displayName)"
            } else {
                alertMessage = error ?? "Unable to change app icon"
            }
            // Note: iOS shows its own alert when changing icons
        }
    }
}

// MARK: - Header

struct AppIconPickerHeader: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.loopedTextSecondary)
            }

            HStack(spacing: 2) {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 24)

                Text("ooped")
                    .font(.loopedBody24)
                    .foregroundColor(.loopedContrast)
            }

            Spacer()

            Text("App Icon")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 12)
    }
}

// MARK: - Icon Cell

struct AppIconCell: View {
    let icon: AppIconManager.AppIcon
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    // Icon preview
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.loopedBackground)
                        .frame(width: 100, height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    isSelected ? Color.loopedPrimary : Color.clear,
                                    lineWidth: 3
                                )
                        )

                    // Placeholder for icon image
                    // You can replace this with actual app icon asset if available
                    Image(systemName: icon == .default ? "app.fill" : "app.badge.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.loopedPrimary)
                }

                Text(icon.displayName)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Current")
                            .font(.loopedSubBodyMedium)
                    }
                    .foregroundColor(.loopedPrimary)
                } else {
                    Text(" ")
                        .font(.loopedSubBodyMedium)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AppIconPickerView()
}
