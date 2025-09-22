import SwiftUI

// MARK: - Organization Model

struct Organization: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let logoText: String // For now, using initials instead of actual logos
}

struct MockOrganizations {
    static let companies: [Organization] = [
        Organization(name: "J.P. Morgan", category: "Banking", logoText: "JPMorgan"),
        Organization(name: "Wells Fargo", category: "Banking", logoText: "JPMorgan"),
        Organization(name: "Bank of America", category: "Banking", logoText: "JPMorgan"),
        Organization(name: "Goldman Sachs", category: "Banking", logoText: "JPMorgan"),
        Organization(name: "Morgan Stanley", category: "Banking", logoText: "JPMorgan"),
        Organization(name: "Citibank", category: "Banking", logoText: "JPMorgan"),
        Organization(name: "Charles Schwab", category: "Banking", logoText: "JPMorgan"),
        Organization(name: "First Citizens", category: "Banking", logoText: "JPMorgan")
    ]

    static let schools: [Organization] = [
        Organization(name: "NC State", category: "University", logoText: "JPMorgan"),
        Organization(name: "Chapel Hill", category: "University", logoText: "JPMorgan"),
        Organization(name: "Duke University", category: "University", logoText: "JPMorgan"),
        Organization(name: "Wake Forest", category: "University", logoText: "JPMorgan"),
        Organization(name: "UNC Charlotte", category: "University", logoText: "JPMorgan"),
        Organization(name: "NC A&T", category: "University", logoText: "JPMorgan"),
        Organization(name: "East Carolina", category: "University", logoText: "JPMorgan"),
        Organization(name: "Appalachian State", category: "University", logoText: "JPMorgan")
    ]
}

// MARK: - Organization Selection View

struct OrganizationSelectionView: View {
    let title: String
    let organizations: [Organization]
    let onNavigate: (AuthScreen) -> Void

    @State private var searchText = ""

    private var isStudentFlow: Bool {
        title.contains("school")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and title
            HStack {
                Button(action: {
                    onNavigate(.employmentStatus)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.loopedPrimary)
                }

                Spacer()

                Text(title)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                // Invisible spacer for balance
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 24)

            // Search bar
            VStack {
                TextField("", text: $searchText)
                    .font(.loopedBody)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.loopedPrimary.opacity(0.6), lineWidth: 1.5)
                    )
                    .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            // Popular section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Popular:")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                    Spacer()
                }
                .padding(.horizontal, 20)

                // Organizations list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(organizations) { org in
                            OrganizationRow(organization: org) {
                                onNavigate(.verificationIntro(isStudent: isStudentFlow))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Organization Row

struct OrganizationRow: View {
    let organization: Organization
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Logo circle
                Circle()
                    .fill(Color(red: 0.2, green: 0.4, blue: 0.7)) // Blue color matching design
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(organization.logoText)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    )

                // Name and category
                VStack(alignment: .leading, spacing: 2) {
                    Text(organization.name)
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    Text(organization.category)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }

                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    OrganizationSelectionView(
        title: "Where do you work?",
        organizations: MockOrganizations.companies
    ) { _ in }
}