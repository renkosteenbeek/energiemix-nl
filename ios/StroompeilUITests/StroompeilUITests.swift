import XCTest

@MainActor
final class StroompeilUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testDashboardInteractions() throws {
        let app = XCUIApplication()
        app.launch()

        let hero = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "procent duurzame stroom")).firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 30), "Hero met percentage verschijnt")
        let story = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "(?s).{60,}")).firstMatch
        _ = story.waitForExistence(timeout: 20)
        capture("01-dashboard")

        app.buttons["Over deze app"].tap()
        XCTAssertTrue(app.buttons["Sluiten"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.links["Privacybeleid"].exists)
        capture("02-over")
        app.buttons["Sluiten"].tap()
        XCTAssertTrue(app.buttons["Over deze app"].waitForExistence(timeout: 5))

        let rhythm = app.descendants(matching: .any)["Dagritme"].firstMatch
        XCTAssertTrue(rhythm.exists)
        let rhythmTop = rhythm.frame.minY
        rhythm.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: rhythm.coordinate(withNormalizedOffset: CGVector(dx: 0.52, dy: -2.5)))
        XCTAssertLessThan(rhythm.frame.minY, rhythmTop - 40, "Verticaal vegen op de tijdlijn scrollt de pagina")
        XCTAssertFalse(app.buttons["Terug naar nu"].exists, "Verticaal vegen kiest geen ander uur")
        app.swipeDown()
        app.swipeDown()

        let from = rhythm.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.4))
        let to = rhythm.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
        from.press(forDuration: 0.15, thenDragTo: to)
        let backToNow = app.buttons["Terug naar nu"]
        XCTAssertTrue(backToNow.waitForExistence(timeout: 5), "Nu-knop verschijnt na scrubben")
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        capture("03-scrub")

        app.buttons["Dag eerder"].tap()
        XCTAssertTrue(app.buttons["Dag later"].isEnabled)
        capture("04-dag-eerder")

        backToNow.tap()
        XCTAssertFalse(app.buttons["Dag later"].isEnabled)

        rhythm.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
        XCTAssertTrue(backToNow.waitForExistence(timeout: 5), "Tikken op een staaf kiest dat uur")
        backToNow.tap()

        app.swipeUp()
        XCTAssertFalse(app.buttons["Terug naar nu"].exists)
        let allSources = app.buttons["Alle bronnen"]
        XCTAssertTrue(allSources.waitForExistence(timeout: 5))
        if allSources.value as? String == "Ingeklapt" {
            allSources.tap()
        }
        XCTAssertEqual(allSources.value as? String, "Uitgeklapt")
        app.swipeUp()
        capture("05-alle-bronnen")
    }

    func testDeepLinkReturnsToNow() throws {
        let app = XCUIApplication()
        app.launch()
        let hero = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "procent duurzame stroom")).firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 30))

        app.buttons["Dag eerder"].tap()
        XCTAssertTrue(app.buttons["Terug naar nu"].waitForExistence(timeout: 5))

        app.open(URL(string: "stroompeil://nu")!)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        let nowGone = NSPredicate(format: "exists == false")
        expectation(for: nowGone, evaluatedWith: app.buttons["Terug naar nu"])
        waitForExpectations(timeout: 10)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
