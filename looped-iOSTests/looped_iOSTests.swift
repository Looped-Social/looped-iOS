//
//  looped_iOSTests.swift
//  looped-iOSTests
//
//  Created by William Millen on 9/5/25.
//

import Foundation
import Testing
@testable import looped_iOS

struct looped_iOSTests {

    @Test func messageSenderIdMatchesCurrentUserIdWhenSameBackendId() async throws {
        let backendUserId = 42
        let currentUser = User(
            id: UUID.fromBackendId(backendUserId),
            backendId: backendUserId,
            username: "you",
            displayName: "You",
            handle: "you",
            companyId: 1,
            companyName: "Looped",
            bio: nil,
            profileImageURL: nil,
            isVerified: true,
            isAnonymous: false,
            createdAt: nil,
            updatedAt: nil
        )

        let sentMessage = Message(
            id: UUID(),
            backendId: 1,
            content: "hi",
            senderId: UUID.fromBackendId(backendUserId),
            senderDisplayName: nil,
            receiverId: nil,
            conversationBackendId: 1,
            channelBackendId: nil,
            messageType: .direct,
            isRead: false,
            attachments: nil,
            createdAt: Date()
        )

        #expect(sentMessage.senderId == currentUser.id)
    }

}
