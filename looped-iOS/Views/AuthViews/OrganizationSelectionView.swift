import SwiftUI

// MARK: - Organization Selection View

struct OrganizationSelectionView: View {
    let title: String
    let organizations: [Organization]
    @Binding var searchText: String
    let selectedOrganizationId: UUID?
    let onSelect: (Organization) -> Void
    let onBack: () -> Void
    let onNavigate: (AuthScreen) -> Void

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
                header
                    .padding(.top, 8)
                    .padding(.horizontal, 16)

                Spacer()
                    .frame(height: geometry.size.height * 0.08)

                Text(title)
                    .font(.loopedHeadingMedium)
                    .foregroundColor(.loopedContrast)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.loopedCustom(.medium, size: 16))
                        .foregroundColor(.loopedTextSecondary)

                    TextField("", text: $searchText)
                        .font(.loopedBody)
                        .foregroundColor(.loopedTextPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.loopedMutedBackground)
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
                            OrganizationListRow(
                                organization: organization,
                                isSelected: organization.id == selectedOrganizationId
                            ) {
                                onSelect(organization)
                                if organization.kind == .school {
                                    onNavigate(.degreeSelection)
                                } else {
                                    onNavigate(.departmentSelection)
                                }
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

private extension OrganizationSelectionView {
    var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.loopedCustom(.semibold, size: 20))
                    .foregroundColor(.loopedTextPrimary)
                    .frame(width: 40, height: 40)
            }
            Spacer()
        }
    }
}

private struct OrganizationListRow: View {
    let organization: Organization
    let isSelected: Bool
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

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.loopedCustom(.semibold, size: 18))
                        .foregroundColor(.loopedPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.loopedBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color.loopedPrimary : Color.loopedTextSecondary.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    OrganizationSelectionView(
        title: "Where do you work?",
        organizations: MockOrganizations.companies,
        searchText: .constant(""),
        selectedOrganizationId: nil,
        onSelect: { _ in },
        onBack: { }
    ) { _ in }
}
