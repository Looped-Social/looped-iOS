import SwiftUI

struct HashtagSuggestions: View {
    let hashtags: [String]
    let onHashtagTap: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(hashtags, id: \.self) { hashtag in
                HashtagSuggestionItem(
                    hashtag: hashtag,
                    onTap: {
                        onHashtagTap(hashtag)
                    }
                )

                if hashtag != hashtags.last {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }
}

struct HashtagSuggestionItem: View {
    let hashtag: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(hashtag)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HashtagSuggestions(
        hashtags: ["#interns", "#lunch", "#elevator"],
        onHashtagTap: { _ in }
    )
    .background(Color.loopedBackground)
}
