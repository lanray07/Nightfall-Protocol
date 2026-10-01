import StoreKitTest
import XCTest

@MainActor
final class ReleaseEvidenceTests: XCTestCase {
    private let productID = "com.nightfallprotocol.subscription.premium.monthly"

    func testPurchaseRestoreExpiryAndLegalLinks() throws {
        continueAfterFailure = false
        let session = try SKTestSession(configurationFileNamed: "NightfallProtocol")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()

        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 60))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["Sound"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.switches["Music"].exists)
        XCTAssertTrue(app.switches["Haptics"].exists)
        XCTAssertTrue(app.buttons["Privacy Policy"].exists)
        XCTAssertTrue(app.buttons["Terms of Use"].exists)
        capture("settings-labels-and-legal-links", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.buttons["Store"].waitForExistence(timeout: 15))
        app.buttons["Store"].tap()
        XCTAssertTrue(app.buttons["Purchase"].waitForExistence(timeout: 45))
        XCTAssertTrue(app.staticTexts["Premium Pass"].exists)
        XCTAssertTrue(app.buttons["Privacy Policy"].exists)
        XCTAssertTrue(app.buttons["Terms of Use"].exists)
        capture("premium-pass-live-storekit-test", app: app)
        app.buttons["Purchase"].tap()
        XCTAssertTrue(app.buttons["Owned"].waitForExistence(timeout: 30))
        capture("verified-purchase-entitlement", app: app)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Store"].waitForExistence(timeout: 45))
        app.buttons["Store"].tap()
        XCTAssertTrue(app.buttons["Owned"].waitForExistence(timeout: 30))
        app.buttons["Restore Purchases"].tap()
        if app.buttons["Close"].waitForExistence(timeout: 10) { app.buttons["Close"].tap() }
        XCTAssertTrue(app.buttons["Owned"].exists)
        capture("restored-subscription", app: app)

        try session.expireSubscription(productIdentifier: productID)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Store"].waitForExistence(timeout: 45))
        app.buttons["Store"].tap()
        XCTAssertTrue(app.buttons["Purchase"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["Owned"].exists)
        capture("expired-subscription-no-premium-access", app: app)
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
