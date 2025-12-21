import SwiftUI

// MARK: - Organization Selection View

struct OrganizationSelectionView: View {
    let title: String
    let organizations: [Organization]
    let onSelect: (Organization) -> Void
    let onNavigate: (AuthScreen) -> Void

    @State private var searchText = ""

    private var filteredOrganizations: [Organization] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return organizations }
        let query = trimmed.lowercased()
        return organizations.filter { org in
            org.name.lowercased().contains(query) || org.logoText.lowercased().contains(query)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: geometry.size.height * 0.08)

                Text(title)
                    .font(.loopedHeadingMedium)
                    .foregroundColor(.loopedContrast)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.loopedTextSecondary)

                    TextField("", text: $searchText)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(22)
                .padding(.horizontal, 32)
                .padding(.top, 16)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredOrganizations) { organization in
                            OrganizationListRow(organization: organization) {
                                onSelect(organization)
                                onNavigate(.communitySelection(isStudent: organization.kind == .school))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.loopedBackground.ignoresSafeArea())
        }
    }
}

private struct OrganizationListRow: View {
    let organization: Organization
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.loopedMutedBackground)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(organization.logoText)
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedContrast)
                    )

                Text(organization.name)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    OrganizationSelectionView(
        title: "Where do you work?",
        organizations: MockOrganizations.companies,
        onSelect: { _ in }
    ) { _ in }
}
