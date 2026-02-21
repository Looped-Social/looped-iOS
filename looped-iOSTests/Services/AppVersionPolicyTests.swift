import Testing
@testable import looped_iOS

@Suite
struct AppVersionPolicyTests {
    @Test
    func promptsWhenCurrentVersionIsLowerThanMinimum() {
        #expect(
            AppVersionPolicy.shouldPromptForMinimumSupportedVersion(
                currentVersion: "1.0",
                minimumSupportedVersion: "1.1"
            ) == true
        )
    }

    @Test
    func doesNotPromptWhenCurrentVersionMatchesOrExceedsMinimum() {
        #expect(
            AppVersionPolicy.shouldPromptForMinimumSupportedVersion(
                currentVersion: "1.1",
                minimumSupportedVersion: "1.1"
            ) == false
        )
        #expect(
            AppVersionPolicy.shouldPromptForMinimumSupportedVersion(
                currentVersion: "1.2",
                minimumSupportedVersion: "1.1"
            ) == false
        )
    }

    @Test
    func comparesDottedVersionsWithPadding() {
        #expect(AppVersionPolicy.isVersion("1.0", lessThan: "1.0.1") == true)
        #expect(AppVersionPolicy.isVersion("1.0.3", lessThan: "1.1") == true)
        #expect(AppVersionPolicy.isVersion("1.0.3", lessThan: "1.0.2") == false)
    }

    @Test
    func invalidOrMissingVersionsDoNotPrompt() {
        #expect(
            AppVersionPolicy.shouldPromptForMinimumSupportedVersion(
                currentVersion: "1.0",
                minimumSupportedVersion: nil
            ) == false
        )
        #expect(AppVersionPolicy.isVersion("1.0", lessThan: "bad.version") == false)
        #expect(AppVersionPolicy.isVersion("bad", lessThan: "1.0") == false)
    }
}
