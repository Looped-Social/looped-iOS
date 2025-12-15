import Foundation

struct SearchResultPage<T> {
    let items: [T]
    let nextCursor: String?
}
