import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.posts) { post in
                    PostRowView(post: post)
                }
            }
            .navigationTitle("Company Feed")
            .refreshable {
                await viewModel.loadPosts()
            }
            .task {
                await viewModel.loadPosts()
            }
        }
    }
}

struct PostRowView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(post.isAnonymous ? "Anonymous" : post.authorDisplayName ?? "User")
                    .font(.headline)
                Spacer()
                Text(post.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(post.content)
                .font(.body)
            
            HStack {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "heart")
                        Text("\(post.reactionCount)")
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FeedView()
}