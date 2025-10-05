import SwiftUI

struct CompanyStackView: View {
    let companies: [Company]
    @Binding var selectedIndex: Int
    var horizontalOffset: CGFloat = 0

    private let overlapOffset: CGFloat = -320

    var body: some View {
        VStack(spacing: overlapOffset) {
            ForEach(Array(companies.enumerated()), id: \.element.id) { index, company in
                CompanyCircleView(
                    company: company,
                    isSelected: index == selectedIndex,
                    onTap: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedIndex = index
                        }
                    }
                )
                .zIndex(Double(1000 - index))
            }
        }
        .frame(maxWidth: .infinity)
        .offset(x: horizontalOffset, y: -400)
    }
}

#Preview {
    CompanyStackView(
        companies: MockCompanies.companies,
        selectedIndex: .constant(0)
    )
    .background(Color.loopedBackground)
}
