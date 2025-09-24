import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var showSearchResults = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Search Bar - Tappable to show search results
                    Button(action: {
                        showSearchResults = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.loopedTextSecondary)
                                .font(.system(size: 16))
                            Text("Search Looped")
                                .font(.loopedBody)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 24) {
                        // Trending Post Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Trending Post")
                                    .font(.loopedSubheadMedium)
                                    .foregroundColor(.loopedTextPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)

                            VStack(spacing: 12) {
                                // Snap-to-center trending posts with TabView
                                TabView(selection: $viewModel.selectedTrendingIndex) {
                                    ForEach(Array(viewModel.trendingPosts.enumerated()), id: \.element.id) { index, post in
                                        TrendingPostCard(
                                            imageName: post.imageName,
                                            title: post.title,
                                            subtitle: post.subtitle
                                        )
                                        .padding(.horizontal, 16)
                                        .tag(index)
                                    }
                                }
                                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                .frame(height: 200)

                                // Custom page indicator dots positioned lower
                                HStack(spacing: 8) {
                                    ForEach(0..<viewModel.trendingPosts.count, id: \.self) { index in
                                        Circle()
                                            .fill(index == viewModel.selectedTrendingIndex ? Color.loopedTextSecondary : Color.loopedTextSecondary.opacity(0.3))
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }

                        // Loops Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Loops")
                                    .font(.loopedSubheadMedium)
                                    .foregroundColor(.loopedTextPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.loops) { loop in
                                        LoopCard(
                                            title: loop.title,
                                            description: loop.description,
                                            memberCount: loop.memberCount
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        // Groups Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Groups")
                                    .font(.loopedSubheadMedium)
                                    .foregroundColor(.loopedTextPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                                ForEach(viewModel.groups) { group in
                                    GroupIcon(
                                        title: group.title,
                                        iconName: group.iconName,
                                        memberCount: group.memberCount
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
            }
            .background(Color.loopedBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showSearchResults) {
            SearchResultsView()
        }
    }
}

#Preview {
    SearchView()
}