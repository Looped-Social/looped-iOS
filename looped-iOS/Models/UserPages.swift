import Foundation

struct UserSearchPage {
    let users: [User]
    let nextCursor: String?
}

struct BlockedUsersPage {
    let users: [BlockedUser]
    let nextCursor: String?
}

struct UserCommentsPage {
    let comments: [Comment]
    let nextCursor: String?
}

struct UserRepliesPage {
    let comments: [Comment]
    let nextCursor: String?
}
