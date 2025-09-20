import SwiftUI

struct MenuContent: View {
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

            // Menu items placeholder
            VStack(alignment: .leading, spacing: 24) {
                // Placeholder menu items - will be implemented later
                Text("Menu items coming soon...")
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextSecondary)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

#Preview {
    MenuContent()
        .background(Color.loopedBackground)
}