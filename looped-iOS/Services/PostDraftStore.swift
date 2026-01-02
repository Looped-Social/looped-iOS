import Foundation

final class PostDraftStore: ObservableObject {
    @Published private(set) var drafts: [PostDraft] = []

    private let storageKey = "postDrafts"
    private let storage: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(storage: UserDefaults = .standard) {
        self.storage = storage
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
        load()
    }

    func reload() {
        load()
    }

    @discardableResult
    func upsertDraft(
        id: UUID? = nil,
        content: String,
        communityId: Int?,
        communityName: String?
    ) -> PostDraft {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id, let index = drafts.firstIndex(where: { $0.id == id }) {
            drafts[index].content = trimmed
            drafts[index].communityId = communityId
            drafts[index].communityName = communityName
            drafts[index].updatedAt = Date()
            persist()
            return drafts[index]
        }

        let draft = PostDraft(
            content: trimmed,
            communityId: communityId,
            communityName: communityName,
            createdAt: Date(),
            updatedAt: Date()
        )
        drafts.insert(draft, at: 0)
        persist()
        return draft
    }

    func delete(_ draft: PostDraft) {
        delete(id: draft.id)
    }

    func delete(id: UUID) {
        drafts.removeAll { $0.id == id }
        persist()
    }

    func clearAll() {
        drafts = []
        persist()
    }

    private func load() {
        guard let data = storage.data(forKey: storageKey) else {
            drafts = []
            return
        }
        do {
            drafts = try decoder.decode([PostDraft].self, from: data)
                .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            drafts = []
        }
    }

    private func persist() {
        drafts.sort { $0.updatedAt > $1.updatedAt }
        guard let data = try? encoder.encode(drafts) else { return }
        storage.set(data, forKey: storageKey)
    }
}
