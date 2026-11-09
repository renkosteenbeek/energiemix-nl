import XCTest

@MainActor
final class AppStoreScreenshots: XCTestCase {
    private struct Point: Decodable {
        let time: String
        let greenPct: Double
        let forecast: Bool?
    }

    private var environment: [String: String] { ProcessInfo.processInfo.environment }

    override func setUp() async throws {
        continueAfterFailure = false
        try XCTSkipUnless(environment["STROOMPEIL_SCREENSHOTS"] == "1", "Alleen voor het maken van App Store-screenshots")
    }

    func testCaptureScreenshots() async throws {
        let appearance = environment["STROOMPEIL_APPEARANCE"] ?? "light"
        let target = try await greenestRecentHour()

        let app = XCUIApplication()
        app.launch()
        let hero = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "procent duurzame stroom")).firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 30))

        if appearance == "light" {
            waitForStory(in: app)
            capture("03-nu-met-verwachting")
        }

        for _ in 0..<target.pans {
            app.buttons["Dag eerder"].tap()
            sleep(1)
        }
        let rhythm = app.descendants(matching: .any)["Tijdlijn per uur"].firstMatch
        let x = (CGFloat(target.index) + 0.5) / 73
        rhythm.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.35)).tap()
        sleep(2)
        waitForStory(in: app)
        capture("01-dashboard-\(appearance)")
        guard appearance == "light" else { return }

        app.buttons["Jaar"].tap()
        let greenest = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Groenste dag")).firstMatch
        XCTAssertTrue(greenest.waitForExistence(timeout: 30))
        greenest.tap()
        sleep(2)
        waitForStory(in: app)
        capture("07-jaaroverzicht")
        app.buttons["Dag"].tap()
        sleep(2)

        app.buttons["Over deze app"].tap()
        sleep(1)
        capture("04-over-stroompeil")
        app.buttons["Sluiten"].tap()
        sleep(1)

        app.swipeUp()
        let allSources = app.buttons["Alle bronnen"]
        XCTAssertTrue(allSources.waitForExistence(timeout: 5))
        if allSources.value as? String == "Ingeklapt" { allSources.tap() }
        sleep(1)
        app.swipeUp()
        sleep(1)
        capture("02-alle-bronnen")
    }

    private func greenestRecentHour() async throws -> (pans: Int, index: Int) {
        let base = environment["STROOMPEIL_SCREENSHOT_API"] ?? "http://127.0.0.1:3000"
        let (data, _) = try await URLSession.shared.data(from: URL(string: "\(base)/api/timeline")!)
        let points = try JSONDecoder().decode([Point].self, from: data)
        let parser = ISO8601DateFormatter()
        let now = Date()
        let nowHour = Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / 3600).rounded(.down) * 3600)
        let candidates = points.compactMap { point -> (hoursFromNow: Int, pct: Double)? in
            guard point.forecast != true, let date = parser.date(from: point.time) else { return nil }
            let hours = Int((date.timeIntervalSince(nowHour) / 3600).rounded())
            guard hours <= -2, hours >= -48 - 24 * 6 else { return nil }
            return (hours, point.greenPct)
        }
        let best = try XCTUnwrap(candidates.max { $0.pct < $1.pct })
        let pans = max(0, Int((Double(-48 - best.hoursFromNow) / 24).rounded(.up)))
        return (pans, best.hoursFromNow + 48 + 24 * pans)
    }

    private func waitForStory(in app: XCUIApplication) {
        let story = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "(?s).{60,}")).firstMatch
        _ = story.waitForExistence(timeout: 30)
        sleep(1)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
