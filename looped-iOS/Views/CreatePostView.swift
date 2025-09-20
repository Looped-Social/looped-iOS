import SwiftUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var postText: String = ""
    @State private var isAnonymous: Bool = false
    @State private var selectedChannel: String = "General"
    @State private var isSubmitting: Bool = false
    
    let feedViewModel: FeedViewModel
    
    let channels = ["General", "Random", "Work", "Announcements"]
    
    private var characterLimit: Int { 280 }
    private var remainingCharacters: Int { characterLimit - postText.count }
    private var isPostValid: Bool { !postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && postText.count <= characterLimit }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top navigation bar
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.loopedTextSecondary)
                    .font(.loopedBody)
                    
                    Spacer()
                    
                    Text("New Post")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                    
                    Spacer()
                    
                    Button("Post") {
                        Task {
                            await submitPost()
                        }
                    }
                    .disabled(!isPostValid || isSubmitting)
                    .foregroundColor((isPostValid && !isSubmitting) ? .loopedPrimary : .loopedTextSecondary)
                    .font(.loopedBodyMedium)
                }
                .padding()
                .background(Color.loopedBackground)
                
                // Divider
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.loopedTextSecondary.opacity(0.1))
                
                // Main content
                VStack(alignment: .leading, spacing: 16) {
                    // Channel selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Channel")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                        
                        Menu {
                            ForEach(channels, id: \.self) { channel in
                                Button(channel) {
                                    selectedChannel = channel
                                }
                            }
                        } label: {
                            HStack {
                                Text("# \(selectedChannel)")
                                    .font(.loopedBody)
                                    .foregroundColor(.loopedTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.loopedTextSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.loopedMutedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // Text input area
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's happening?")
                            .font(.loopedSubBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                        
                        TextField("Share your thoughts...", text: $postText, axis: .vertical)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                            .lineLimit(6...10)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.loopedMutedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Character count
                    HStack {
                        Spacer()
                        Text("\(remainingCharacters)")
                            .font(.loopedSmallText)
                            .foregroundColor(remainingCharacters < 20 ? .red : .loopedTextSecondary)
                    }
                    
                    // Anonymous toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Post anonymously")
                                .font(.loopedSubBodyMedium)
                                .foregroundColor(.loopedTextPrimary)
                            
                            Text("Your identity will be hidden from other users")
                                .font(.loopedSmallText)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $isAnonymous)
                            .labelsHidden()
                            .tint(.loopedPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.loopedMutedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                }
                .padding()
                .background(Color.loopedBackground)
            }
        }
        .background(Color.loopedBackground)
    }
    
    private func submitPost() async {
        guard !postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSubmitting = true
        
        await feedViewModel.createPost(
            content: postText.trimmingCharacters(in: .whitespacesAndNewlines),
            isAnonymous: isAnonymous,
            channel: selectedChannel
        )
        
        isSubmitting = false
        dismiss()
    }
}

#Preview {
    CreatePostView(feedViewModel: FeedViewModel())
}