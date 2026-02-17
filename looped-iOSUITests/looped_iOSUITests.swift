import XCTest
import CoreGraphics

final class looped_iOSUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testAuthFlow_navigatesToLoginAndShowsFields() throws {
        let app = launchApp(bypassAuth: false, startOnLogin: true)

        let emailField = app.element(withIdentifier: "auth.login.emailField")
        let passwordField = app.element(withIdentifier: "auth.login.passwordField")
        let submitButton = app.element(withIdentifier: "auth.login.submitButton")

        XCTAssertTrue(submitButton.waitForExistence(timeout: 12), app.debugDescription)
        XCTAssertTrue(emailField.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(passwordField.waitForExistence(timeout: 10), app.debugDescription)

        emailField.tapReliably(in: app)
        emailField.typeText("person@example.com")

        passwordField.tapReliably(in: app)
        passwordField.typeText("Password123")

        XCTAssertTrue(submitButton.isEnabled)
    }

    @MainActor
    func testFeedFlow_bypassAuth_showsHomeTabAndFeedScreen() throws {
        let app = launchApp(bypassAuth: true)

        let homeTab = app.buttons["mainTab.home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10), app.debugDescription)
        homeTab.tapReliably(in: app)

        let feedScreen = app.element(withIdentifier: "feed.screen")
        XCTAssertTrue(feedScreen.waitForExistence(timeout: 8), app.debugDescription)
    }

    @MainActor
    func testMessagingFlow_bypassAuth_opensMessagesAndRequestsTabs() throws {
        let app = launchApp(bypassAuth: true)

        let messagesTab = app.buttons["mainTab.messages"]
        XCTAssertTrue(messagesTab.waitForExistence(timeout: 10), app.debugDescription)
        messagesTab.tapReliably(in: app)

        let messagesScreen = app.element(withIdentifier: "messages.screen")
        XCTAssertTrue(messagesScreen.waitForExistence(timeout: 10), app.debugDescription)

        var messagesListTab = app.element(withIdentifier: "messages.tab.messages")
        if !messagesListTab.waitForExistence(timeout: 3) {
            messagesListTab = app.buttons["Messages"]
        }
        XCTAssertTrue(messagesListTab.waitForExistence(timeout: 10), app.debugDescription)

        var requestsTab = app.element(withIdentifier: "messages.tab.requests")
        if !requestsTab.waitForExistence(timeout: 3) {
            requestsTab = app.buttons["Requests"]
        }
        XCTAssertTrue(requestsTab.waitForExistence(timeout: 10), app.debugDescription)
        requestsTab.tapReliably(in: app)

        let emptyRequests = app.staticTexts["No requests yet"]
        let failedRequests = app.staticTexts["Couldn't load requests"]
        XCTAssertTrue(
            emptyRequests.waitForExistence(timeout: 8) || failedRequests.waitForExistence(timeout: 8),
            app.debugDescription
        )
    }

    @MainActor
    private func launchApp(bypassAuth: Bool, startOnLogin: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-didShowFeedDiscovery", "YES",
            "-didShowFeedSearchDiscovery", "YES",
            "-didShowSearchPageDiscovery", "YES",
            "-didShowNotificationPermissionPrompt", "YES",
            "-anonymousMode", "NO"
        ]
        if bypassAuth {
            app.launchEnvironment["LOOPED_UI_TEST_BYPASS_AUTH"] = "1"
            app.launchEnvironment["LOOPED_UI_TEST_DISABLE_NETWORK"] = "1"
        }
        if startOnLogin {
            app.launchEnvironment["LOOPED_UI_TEST_START_ON_LOGIN"] = "1"
        }
        app.launch()
        return app
    }
}

private extension XCUIApplication {
    func element(withIdentifier identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}

private extension XCUIElement {
    func tapReliably(in app: XCUIApplication, timeout: TimeInterval = 10) {
        XCTAssertTrue(waitForExistence(timeout: timeout), app.debugDescription)

        if isHittable {
            tap()
            return
        }

        for _ in 0..<2 {
            app.swipeUp()
            if isHittable {
                tap()
                return
            }
        }

        for _ in 0..<2 {
            app.swipeDown()
            if isHittable {
                tap()
                return
            }
        }

        coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
