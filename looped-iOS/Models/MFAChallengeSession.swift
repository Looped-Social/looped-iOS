import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth

final class MFAChallengeSession: Identifiable {
    let id = UUID()
    let resolver: MultiFactorResolver
    let phoneHints: [PhoneMultiFactorInfo]

    init(resolver: MultiFactorResolver) {
        self.resolver = resolver
        self.phoneHints = resolver.hints.compactMap { $0 as? PhoneMultiFactorInfo }
    }
}
#endif
