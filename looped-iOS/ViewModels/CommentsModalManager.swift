import SwiftUI
import Combine

@MainActor
class CommentsModalManager: ObservableObject {
    @Published var isPresented = false
    @Published var currentPost: Post?
    @Published var currentComments: [Comment] = []
    
    func showComments(for post: Post) {
        currentPost = post
        currentComments = MockComments.getCommentsForPost(post.id)
        isPresented = true
    }
    
    func dismissComments() {
        isPresented = false
        // Delay clearing the data to allow for smooth animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.currentPost = nil
            self.currentComments = []
        }
    }
}