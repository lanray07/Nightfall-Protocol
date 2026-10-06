import StoreKitTest
import XCTest

@MainActor
final class ReleaseEvidenceTests: XCTestCase {
    private let productID = "com.nightfallprotocol.subscription.premium.monthly"

    func testPlayableMemoryMissionAndExtraction() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launchEnvironment["NF_GAMEPLAY_TEST"] = "memory"
        app.launch()
        let instruction = app.staticTexts["mission-instruction"]
        XCTAssertTrue(instruction.waitForExistence(timeout: 60))
        XCTAssertTrue(instruction.label.contains("station 1"))
        let arena = app.otherElements["mission-arena"]
        XCTAssertTrue(arena.waitForExistence(timeout: 15))
        func move(_ x: CGFloat, _ y: CGFloat) {
            let width = arena.frame.width, height = arena.frame.height
            let pointX = 24 + max(120, width - 48) * x
            let pointY = height - (210 + max(160, height - 550) * y)
            arena.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: pointX, dy: pointY)).tap()
            // Actual operator movement, not a test teleport.
            Thread.sleep(forTimeInterval: 6)
        }
        capture("mission-start-real-gameplay", app: app)
        app.buttons["Extract"].tap()
        XCTAssertFalse(app.staticTexts["Extraction Complete"].exists)
        move(0.2, 0.7)
        app.buttons["Interact"].tap()
        let decodedTask = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "mission-instruction", "station 2")).firstMatch
        XCTAssertTrue(decodedTask.waitForExistence(timeout: 5))
        capture("memory-recovered-next-task", app: app)
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(decodedTask.exists)
        capture("mission-progress-preserved-landscape", app: app)
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(decodedTask.exists)
        move(0.75, 0.3)
        app.buttons["Interact"].tap()
        let completed = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "mission-instruction", "Mission complete")).firstMatch
        XCTAssertTrue(completed.waitForExistence(timeout: 15))
        capture("memory-decoded-real-gameplay", app: app)
        move(0.86, 0.82)
        app.buttons["Extract"].tap()
        XCTAssertTrue(app.buttons["Return to Hub"].waitForExistence(timeout: 15))
        capture("mission-extracted-real-result", app: app)
        for _ in 0..<3 where !app.buttons["Return to Hub"].isHittable { app.swipeUp() }
        app.buttons["Return to Hub"].tap()
        XCTAssertTrue(app.buttons["Signal Campaign"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Co-op Placeholder"].exists)
        XCTAssertFalse(app.buttons["Endless"].exists)
        app.buttons["Signal Campaign"].tap()
        XCTAssertTrue(app.staticTexts["01 / The Broken Transmission"].waitForExistence(timeout: 10))
        capture("campaign-first-chapter-real-selection", app: app)
    }

    func testLegalLinksOpenTheirDestinations() {
        continueAfterFailure = false
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()
        if safari.buttons["Continue"].waitForExistence(timeout: 5) { safari.buttons["Continue"].tap() }
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 60))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Privacy Policy"].waitForExistence(timeout: 15))
        capture("legal-links-from-settings", app: app)
        app.buttons["Privacy Policy"].tap()
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 30))
        let privacy = safari.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "Nightfall Protocol Privacy Policy")).firstMatch
        XCTAssertTrue(privacy.waitForExistence(timeout: 75))
        capture("privacy-policy-opened-in-browser", app: safari)
        print(safari.debugDescription)
        app.activate()
        XCTAssertTrue(app.buttons["Terms of Use"].waitForExistence(timeout: 15))
        app.buttons["Terms of Use"].tap()
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 30))
        let terms = safari.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "LICENSED APPLICATION END USER LICENSE AGREEMENT")).firstMatch
        XCTAssertTrue(terms.waitForExistence(timeout: 75))
        capture("apple-eula-opened-in-browser", app: safari)
        print(safari.debugDescription)
        app.activate()
    }

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
        XCTAssertTrue(app.buttons["Purchase"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["Owned"].exists)
        capture("expired-subscription-updated-without-relaunch", app: app)
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
