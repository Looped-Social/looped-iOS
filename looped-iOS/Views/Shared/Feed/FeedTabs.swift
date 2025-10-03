import SwiftUI

enum FeedTab: String, CaseIterable {
    case forYou = "For You"
    case hot = "Latest"
}

enum FilterTag: String, CaseIterable {
    case allLoops = "All Loops"
    case jpMorgan = "Jp Morgan"
    case finance = "Finance"
    case laborDay = "Interns"
    
    var displayName: String {
        return self.rawValue
    }
}

struct FeedTabs: View {
    @State private var selectedTab: FeedTab = .forYou
    @State private var selectedFilter: FilterTag = .allLoops // Default selected
    @State private var isPlus: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector (For You / Latest)
            VStack(spacing: 0) {
                HStack {
                    ForEach(FeedTab.allCases, id: \.self) { tab in
                        Button(action: {
                            selectedTab = tab
                        }) {
                            Text(tab.rawValue)
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(selectedTab == tab ? .loopedPrimary : .loopedTextSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                
                // Full-width underlines
                HStack(spacing: 0) {
                    // For You underline
                    Rectangle()
                        .frame(height: selectedTab == .forYou ? 2 : 1)
                        .foregroundColor(selectedTab == .forYou ? .loopedPrimary : .loopedTextSecondary.opacity(0.3))
                    
                    // Latest underline
                    Rectangle()
                        .frame(height: selectedTab == .hot ? 2 : 1)
                        .foregroundColor(selectedTab == .hot ? .loopedPrimary : .loopedTextSecondary.opacity(0.3))
                }
            }
            
            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    // Plus/Minus toggle button
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isPlus.toggle()
                        }
                    }) {
                        ZStack {
                            // Horizontal line (always visible)
                            RoundedRectangle(cornerRadius: 1.5)
                                .frame(width: 25, height: 3)
                                .foregroundColor(.loopedSecondary)

                            // Vertical line (only visible for plus)
                            if isPlus {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .frame(width: 3, height: 25)
                                    .foregroundColor(.loopedSecondary)
                            }
                        }
                        .frame(width: 16)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if !isPlus {
                        ForEach(FilterTag.allCases, id: \.self) { filter in
                            Button(action: {
                                selectedFilter = filter
                            }) {
                                Text(filter.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedFilter == filter ? .white : .loopedTextSecondary)
                                    .padding(.horizontal,8)
                                    .padding(.vertical, 8)
                                    .background(selectedFilter == filter ? Color.loopedPrimary : Color.loopedTextSecondary.opacity(0.1))
                                    .cornerRadius(20)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 28)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    VStack {
        FeedHeader()
        FeedTabs()
        Spacer()
    }
    .background(Color.loopedBackground.ignoresSafeArea())
}
