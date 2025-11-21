import Foundation

struct UserSearchPage {
    let users: [User]
    let nextCursor: String?
}

struct UserCommentsPage {
    let comments: [Comment]
    let nextCursor: String?
}
