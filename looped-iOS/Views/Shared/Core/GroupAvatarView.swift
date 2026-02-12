import SwiftUI
import Foundation

struct GroupAvatarView: View {
    let name: String
    let photoUrl: String?
    let size: CGFloat

    private var initials: String {
        let components = name.split(separator: " ")
        let initials = components.compactMap { component -> Character? in
            component.first { char in
                char.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
            }
        }
        .prefix(2)
        .map { String($0).uppercased() }
        .joined()

        return initials.isEmpty ? "GC" : initials
    }

    private var resolvedPhotoUrl: URL? {
        let trimmed = (photoUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    private var initialsFont: Font {
        let computed = max(10, size * 0.32)
        return .loopedCustom(.semibold, size: computed, relativeTo: .caption)
    }

    var body: some View {
        if let resolvedPhotoUrl {
            CachedAvatarImageView(url: resolvedPhotoUrl) {
                placeholder
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            placeholder
                .frame(width: size, height: size)
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.loopedSecondary)
            .overlay(
                Text(initials)
                    .font(initialsFont)
                    .foregroundColor(.loopedWhite)
            )
    }
}
