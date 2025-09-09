import SwiftUI

struct FeedHeader: View {
    var body: some View {
        HStack {
            // Left side: Hamburger menu and Looped text
            HStack(spacing: 12) {
                // Hamburger menu button
                Button(action: {
                    // TODO: Handle menu action
                }) {
                    VStack(spacing: 5) {
                        Rectangle()
                            .frame(width: 22, height: 2.5)
                            .foregroundColor(.loopedTextSecondary)
                        Rectangle()
                            .frame(width: 22, height: 2.5)
                            .foregroundColor(.loopedTextSecondary)
                        Rectangle()
                            .frame(width: 22, height: 2.5)
                            .foregroundColor(.loopedTextSecondary)
                    }
                }
                
                // Looped logo/text
                HStack(spacing: 6) {
                    Text("Looped")
                        .font(.loopedLogo)
                        .foregroundColor(.loopedPrimary)
                    
                    // Dropdown arrow
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.loopedTextSecondary)
                }
            }
            
            Spacer()
            
            // Profile avatar
            Button(action: {
                // TODO: Handle profile action
            }) {
                AsyncImage(url: URL(string: "https://via.placeholder.com/36")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.loopedPrimary)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack {
        FeedHeader()
        Spacer()
    }
    .background(Color.loopedBackground)
}
