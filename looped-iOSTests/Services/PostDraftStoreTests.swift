import Foundation
import Testing
@testable import looped_iOS

@Suite(.serialized)
@MainActor
struct PostDraftStoreTests {

    @Test
    func upsertDraft_trimsContentAndPersistsOrdering() async {
        let suite = "looped.tests.postdraft.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = PostDraftStore(storage: defaults)

        let first = store.upsertDraft(content: "  first  ", communityId: 1, communityName: "A")
        try? await Task.sleep(nanoseconds: 20_000_000)
        let second = store.upsertDraft(content: "second", communityId: 2, communityName: "B")

        #expect(first.content == "first")
        #expect(store.drafts.count == 2)
        #expect(store.drafts.first?.id == second.id)

        let reloaded = PostDraftStore(storage: defaults)
        #expect(reloaded.drafts.count == 2)
        #expect(reloaded.drafts.first?.id == second.id)

        defaults.removePersistentDomain(forName: suite)
    }

    @Test
    func upsertDraft_existingId_updatesInPlace() {
        let suite = "looped.tests.postdraft.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = PostDraftStore(storage: defaults)
        let original = store.upsertDraft(content: "hello", communityId: 1, communityName: "A")
        let updated = store.upsertDraft(
            id: original.id,
            content: "updated",
            communityId: 3,
            communityName: "C",
            poll: PollDraft(question: "Q", options: ["A", "B"])
        )

        #expect(store.drafts.count == 1)
        #expect(updated.id == original.id)
        #expect(store.drafts.first?.content == "updated")
        #expect(store.drafts.first?.communityId == 3)
        #expect(store.drafts.first?.poll?.question == "Q")

        defaults.removePersistentDomain(forName: suite)
    }

    @Test
    func deleteAndClear_removeDrafts() {
        let suite = "looped.tests.postdraft.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = PostDraftStore(storage: defaults)
        let first = store.upsertDraft(content: "first", communityId: nil, communityName: nil)
        _ = store.upsertDraft(content: "second", communityId: nil, communityName: nil)

        store.delete(id: first.id)
        #expect(store.drafts.count == 1)

        store.clearAll()
        #expect(store.drafts.isEmpty)

        defaults.removePersistentDomain(forName: suite)
    }

    @Test
    func createPostDraftPromptPolicy_ignoresWhitespaceWithoutPoll() {
        let shouldPrompt = CreatePostDraftPromptPolicy.shouldPromptForDraft(
            content: "   \n\t  ",
            poll: nil
        )

        #expect(shouldPrompt == false)
    }

    @Test
    func createPostDraftPromptPolicy_promptsForTextQuestionOrOption() {
        let textOnly = CreatePostDraftPromptPolicy.shouldPromptForDraft(
            content: "hello",
            poll: nil
        )
        let pollQuestionOnly = CreatePostDraftPromptPolicy.shouldPromptForDraft(
            content: "   ",
            poll: PollDraft(question: "Question", options: ["", ""])
        )
        let pollOptionOnly = CreatePostDraftPromptPolicy.shouldPromptForDraft(
            content: "   ",
            poll: PollDraft(question: "   ", options: ["Option", ""])
        )

        #expect(textOnly == true)
        #expect(pollQuestionOnly == true)
        #expect(pollOptionOnly == true)
    }
}
