import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.posts) { post in
                    PostCard(post: post)
                    
                    // Separator line
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.loopedTextSecondary.opacity(0.1))
                }
            }
        }
        .background(Color.loopedBackground)
        .navigationTitle("Company Feed")
        .refreshable {
            await viewModel.loadPosts()
        }
        .task {
            await viewModel.loadPosts()
        }
    }
}


#Preview {
    FeedView()
}