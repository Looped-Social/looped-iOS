import SwiftUI

struct CompanyCircleView: View {
    let company: Company
    let isSelected: Bool
    let onTap: () -> Void

    private let circleSize: CGFloat = 450

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background gradient circle
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                company.color,
                                company.color
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: circleSize, height: circleSize)

                // Company info overlay
                VStack(spacing: 8) {
                    Text(company.category)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.white)

                    Text(company.name)
                        .font(.loopedHeading)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(company.role)
                        .font(.loopedBody)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(company.subtitle)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 40)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .offset(y: isSelected ? 200 : 130)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    VStack {
        CompanyCircleView(
            company: MockCompanies.companies[0],
            isSelected: true,
            onTap: {}
        )

        CompanyCircleView(
            company: MockCompanies.companies[1],
            isSelected: false,
            onTap: {}
        )
    }
    .background(Color.loopedBackground)
}
