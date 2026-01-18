import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var showSearchResults = false
    @Environment(\.preferCommunityShortNames) private var preferCommunityShortNames

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Search Bar - Tappable to show search results
                    Button(action: {
                        showSearchResults = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.loopedTextSecondary)
                                .font(.loopedCustom(size: 16))
                            Text("Search Looped")
                                .font(.loopedBody)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.loopedGray.opacity(0.15))
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

                            if viewModel.trendingPosts.isEmpty {
                                Text("No trending posts yet.")
                                    .font(.loopedSubBodyRegular)
                                    .foregroundColor(.loopedTextSecondary)
                                    .padding(.horizontal, 16)
                            } else {
                                VStack(spacing: 12) {
                                    // Snap-to-center trending posts with TabView
                                    TabView(selection: $viewModel.selectedTrendingIndex) {
                                        ForEach(Array(viewModel.trendingPosts.enumerated()), id: \.element.id) { index, post in
                                            TrendingPostCard(
                                                imageName: post.imageURL ?? "",
                                                title: post.title,
                                                subtitle: post.subtitleText(preferShortNames: preferCommunityShortNames)
                                            )
                                            .padding(.horizontal, 16)
                                            .tag(index)
                                        }
                                    }
                                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                    .frame(height: 200)

                                    if viewModel.trendingPosts.count > 1 {
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
                            }
                        }

                        // Communities Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Communities")
                                    .font(.loopedSubheadMedium)
                                    .foregroundColor(.loopedTextPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)

                            Text("Recommended communities for you")
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedTextSecondary)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.recommendedCommunities) { community in
                                        NavigationLink(
                                            destination: CommunityProfileView(
                                                community: CommunityProfileData(community: community)
                                            )
                                        ) {
                                            LoopCard(
                                                title: CommunityLabelText.preferredName(
                                                    preferShortNames: preferCommunityShortNames,
                                                    name: community.name,
                                                    shortName: community.shortName
                                                ) ?? community.name,
                                                description: community.description,
                                                memberCount: community.memberCount,
                                                imageURL: community.imageUrl
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        // Majors & Departments Section
                        VStack(alignment: .leading, spacing: 24) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Majors")
                                        .font(.loopedSubheadMedium)
                                        .foregroundColor(.loopedTextPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)

                                if viewModel.majors.isEmpty {
                                    Text(viewModel.specializationsError ?? "No majors yet.")
                                        .font(.loopedSubBodyRegular)
                                        .foregroundColor(.loopedTextSecondary)
                                        .padding(.horizontal, 16)
                                } else {
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                                        ForEach(viewModel.majors) { major in
                                            NavigationLink(
                                                destination: CommunityProfileView(
                                                    community: CommunityProfileData(community: major)
                                                )
                                            ) {
                                                SpecializationIcon(
                                                    name: major.name,
                                                    memberCount: major.memberCount
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }

                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Departments")
                                        .font(.loopedSubheadMedium)
                                        .foregroundColor(.loopedTextPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)

                                if viewModel.departments.isEmpty {
                                    Text(viewModel.specializationsError ?? "No departments yet.")
                                        .font(.loopedSubBodyRegular)
                                        .foregroundColor(.loopedTextSecondary)
                                        .padding(.horizontal, 16)
                                } else {
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                                        ForEach(viewModel.departments) { department in
                                            NavigationLink(
                                                destination: CommunityProfileView(
                                                    community: CommunityProfileData(community: department)
                                                )
                                            ) {
                                                SpecializationIcon(
                                                    name: department.name,
                                                    memberCount: department.memberCount
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
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
        .environmentObject(FeedViewModel())
        .environmentObject(AuthViewModel())
}
