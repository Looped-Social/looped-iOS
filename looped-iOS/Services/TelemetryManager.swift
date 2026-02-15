import Foundation

actor TelemetryManager {
    static let shared = TelemetryManager()

    private struct QueuedTelemetryEvent: Codable, Sendable {
        let sessionId: UUID
        let event: TelemetryEvent
    }

    private struct PersistedQueue: Codable, Sendable {
        let version: Int
        let events: [QueuedTelemetryEvent]
    }

    private enum PauseReason: String, Codable, Sendable {
        case unauthorized
        case onboardingIncomplete
    }

    private enum BackoffKind {
        case rateLimited
        case retryable
    }

    private enum FailurePolicy {
        case splitBatch
        case retry(BackoffKind)
        case pauseUnauthorized
        case pauseOnboarding
        case dropBatch
    }

    private let service: TelemetryServiceProtocol
    private let queueURL: URL
    private let flushThreshold = 25
    private let maxBatchSize = 200
    private let maxQueuedEvents = 2_000
    private let backoffSchedule: [TimeInterval] = [5, 15, 30, 60]
    private let flushIntervalNanoseconds: UInt64 = 10_000_000_000

    private var currentSessionId = UUID()
    private var queue: [QueuedTelemetryEvent]
    private var pauseReason: PauseReason?
    private var nextRetryAt: Date?
    private var retryAttempt = 0
    private var isFlushing = false
    private var flushLoopTask: Task<Void, Never>?

    init(
        service: TelemetryServiceProtocol = TelemetryService(),
        fileManager: FileManager = .default
    ) {
        self.service = service
        queueURL = Self.makeQueueURL(fileManager: fileManager)
        queue = Self.trimmedInitialQueue(
            Self.loadQueue(from: queueURL),
            maxQueuedEvents: 2_000
        )
    }

    func appDidBecomeActive() async {
        ensureFlushLoopStarted()
        currentSessionId = UUID()
        if pauseReason == .unauthorized {
            pauseReason = nil
        }
        await flushIfNeeded(force: true)
    }

    func appDidEnterBackground() async {
        await flushIfNeeded(force: true)
    }

    func updateAuthState(isAuthenticated: Bool, onboardingComplete: Bool) async {
        ensureFlushLoopStarted()
        if !isAuthenticated {
            pauseReason = .unauthorized
            queue.removeAll(keepingCapacity: false)
            retryAttempt = 0
            nextRetryAt = nil
            persistQueue()
            return
        }

        if pauseReason == .unauthorized {
            pauseReason = nil
        }

        if onboardingComplete, pauseReason == .onboardingIncomplete {
            pauseReason = nil
        }

        await flushIfNeeded(force: true)
    }

    func flushNow() async {
        await flushIfNeeded(force: true)
    }

    func track(
        type: TelemetryEventType,
        postId: Int? = nil,
        commentId: Int? = nil,
        communityId: Int? = nil,
        feed: TelemetryFeedContext? = nil,
        data: [String: TelemetryValue]? = nil,
        occurredAtMs: Int64 = TelemetryClock.nowMs
    ) async {
        ensureFlushLoopStarted()
        guard pauseReason == nil else { return }

        let event = TelemetryEvent(
            type: type,
            occurredAtMs: occurredAtMs,
            postId: postId.map(Int64.init),
            commentId: commentId.map(Int64.init),
            communityId: communityId.map(Int64.init),
            feed: feed,
            data: data
        )
        queue.append(QueuedTelemetryEvent(sessionId: currentSessionId, event: event))
        trimQueueToCapIfNeeded()
        persistQueue()

        if queue.count >= flushThreshold {
            await flushIfNeeded(force: false)
        }
    }

    func trackFeedImpression(
        postId: Int,
        feed: TelemetryFeedContext?,
        visibleMs: Int,
        canInteract: Bool?,
        lockReason: String?
    ) async {
        guard visibleMs > 0 else { return }
        var payload: [String: TelemetryValue] = ["visible_ms": .int(visibleMs)]
        if let canInteract {
            payload["can_interact"] = .bool(canInteract)
            if let lockReason {
                payload["lock_reason"] = .string(lockReason)
            } else {
                payload["lock_reason"] = .null
            }
        } else if let lockReason {
            payload["lock_reason"] = .string(lockReason)
        }

        await track(
            type: .feedImpression,
            postId: postId,
            feed: feed,
            data: payload
        )
    }

    func trackPostOpen(
        postId: Int,
        feed: TelemetryFeedContext?,
        entryPoint: String?
    ) async {
        var payload: [String: TelemetryValue]?
        if let entryPoint {
            payload = ["entry_point": .string(entryPoint)]
        }
        await track(
            type: .postOpen,
            postId: postId,
            feed: feed,
            data: payload
        )
    }

    func trackCommentsOpen(postId: Int, feed: TelemetryFeedContext?) async {
        await track(
            type: .commentsOpen,
            postId: postId,
            feed: feed
        )
    }

    func trackInteractionBlocked(
        postId: Int,
        feed: TelemetryFeedContext?,
        action: TelemetryInteractionAction,
        lockReason: String
    ) async {
        await track(
            type: .interactionBlocked,
            postId: postId,
            feed: feed,
            data: [
                "action": .string(action.rawValue),
                "lock_reason": .string(lockReason)
            ]
        )
    }

    func trackCommunityJoinIntent(
        communityId: Int,
        postId: Int?,
        feed: TelemetryFeedContext?
    ) async {
        await track(
            type: .communityJoinIntent,
            postId: postId,
            communityId: communityId,
            feed: feed
        )
    }

    func trackCommunityVerifyIntent(
        communityId: Int,
        postId: Int?,
        feed: TelemetryFeedContext?
    ) async {
        await track(
            type: .communityVerifyIntent,
            postId: postId,
            communityId: communityId,
            feed: feed
        )
    }
}

private extension TelemetryManager {
    private func ensureFlushLoopStarted() {
        guard flushLoopTask == nil else { return }
        let interval = flushIntervalNanoseconds
        flushLoopTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)
                await self.flushIfNeeded(force: true)
            }
        }
    }

    private func flushIfNeeded(force: Bool) async {
        guard !isFlushing else { return }
        guard !queue.isEmpty else { return }
        guard pauseReason == nil else { return }
        if !force && queue.count < flushThreshold { return }
        if let nextRetryAt, Date() < nextRetryAt { return }

        isFlushing = true
        defer { isFlushing = false }

        var batchSize = maxBatchSize
        while !queue.isEmpty {
            guard pauseReason == nil else { return }
            if !force && queue.count < flushThreshold { return }
            if let nextRetryAt, Date() < nextRetryAt { return }

            guard let batch = makeBatch(limit: batchSize) else { return }

            do {
                _ = try await service.sendBatch(
                    sessionId: batch.sessionId,
                    events: batch.events.map(\.event)
                )
                queue.removeFirst(batch.events.count)
                persistQueue()
                retryAttempt = 0
                nextRetryAt = nil
                batchSize = maxBatchSize
            } catch {
                let policy = classifyFailure(error)
                switch policy {
                case .splitBatch:
                    if batch.events.count <= 1 {
                        queue.removeFirst(min(queue.count, 1))
                        persistQueue()
                        batchSize = maxBatchSize
                    } else {
                        batchSize = max(1, batch.events.count / 2)
                    }
                case .retry(let kind):
                    scheduleBackoff(for: kind)
                    return
                case .pauseUnauthorized:
                    pauseReason = .unauthorized
                    queue.removeAll(keepingCapacity: false)
                    retryAttempt = 0
                    nextRetryAt = nil
                    persistQueue()
                    return
                case .pauseOnboarding:
                    pauseReason = .onboardingIncomplete
                    queue.removeAll(keepingCapacity: false)
                    retryAttempt = 0
                    nextRetryAt = nil
                    persistQueue()
                    return
                case .dropBatch:
                    queue.removeFirst(min(queue.count, batch.events.count))
                    persistQueue()
                    batchSize = maxBatchSize
                }
            }
        }
    }

    private func scheduleBackoff(for kind: BackoffKind) {
        let index = min(retryAttempt, backoffSchedule.count - 1)
        let base = backoffSchedule[index]
        retryAttempt += 1
        let jitterUpperBound: Double = kind == .rateLimited ? 2.5 : 1.5
        let jitter = Double.random(in: 0...jitterUpperBound)
        nextRetryAt = Date().addingTimeInterval(base + jitter)
    }

    private func classifyFailure(_ error: Error) -> FailurePolicy {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                return .pauseUnauthorized
            case .networkError:
                return .retry(.retryable)
            case .serverError(let statusCode):
                if statusCode == 413 { return .splitBatch }
                if statusCode == 429 { return .retry(.rateLimited) }
                if statusCode >= 500 { return .retry(.retryable) }
                return .dropBatch
            case .apiError(let statusCode, let code, _):
                if statusCode == 401 { return .pauseUnauthorized }
                if statusCode == 409 {
                    if code == "onboarding_incomplete" || code == "user_not_provisioned" {
                        return .pauseOnboarding
                    }
                    return .dropBatch
                }
                if statusCode == 413 || code == "payload_too_large" {
                    return .splitBatch
                }
                if statusCode == 429 || code == "rate_limited" {
                    return .retry(.rateLimited)
                }
                if statusCode >= 500 || code == "telemetry_unavailable" {
                    return .retry(.retryable)
                }
                if statusCode == 400 || code == "invalid_body" {
                    return .dropBatch
                }
                return .dropBatch
            case .decodingError:
                return .retry(.retryable)
            case .invalidResponse:
                return .retry(.retryable)
            }
        }
        return .retry(.retryable)
    }

    private func makeBatch(limit: Int) -> (sessionId: UUID, events: [QueuedTelemetryEvent])? {
        guard let first = queue.first else { return nil }
        let sessionId = first.sessionId
        let resolvedLimit = max(1, min(limit, maxBatchSize))
        var events: [QueuedTelemetryEvent] = []
        events.reserveCapacity(resolvedLimit)
        for item in queue where item.sessionId == sessionId {
            events.append(item)
            if events.count >= resolvedLimit {
                break
            }
        }
        guard !events.isEmpty else { return nil }
        return (sessionId, events)
    }

    private func trimQueueToCapIfNeeded() {
        guard queue.count > maxQueuedEvents else { return }
        let overflow = queue.count - maxQueuedEvents
        queue.removeFirst(overflow)
    }

    private func persistQueue() {
        let payload = PersistedQueue(version: 1, events: queue)
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(payload)
            try data.write(to: queueURL, options: [.atomic])
        } catch {
            return
        }
    }

    private static func makeQueueURL(fileManager: FileManager) -> URL {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return cachesDirectory.appendingPathComponent("telemetry_queue_v1.json")
    }

    private static func loadQueue(from url: URL) -> [QueuedTelemetryEvent] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()

        if let payload = try? decoder.decode(PersistedQueue.self, from: data) {
            return payload.events
        }

        if let legacyEvents = try? decoder.decode([QueuedTelemetryEvent].self, from: data) {
            return legacyEvents
        }

        return []
    }

    private static func trimmedInitialQueue(
        _ queue: [QueuedTelemetryEvent],
        maxQueuedEvents: Int
    ) -> [QueuedTelemetryEvent] {
        guard queue.count > maxQueuedEvents else { return queue }
        return Array(queue.suffix(maxQueuedEvents))
    }
}
