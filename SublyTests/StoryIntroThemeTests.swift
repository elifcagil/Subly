import XCTest
@testable import Subly

final class StoryIntroThemeTests: XCTestCase {

    func testDarkResolvesToGraphiteAndLightToPaper() {
        XCTAssertEqual(StoryIntroTheme.resolve(.dark), .graphite)
        XCTAssertEqual(StoryIntroTheme.resolve(.light), .paper)
        XCTAssertEqual(StoryIntroTheme.resolve(.unspecified), .paper)
    }

    func testRecapTotalCardFollowsTheThemeButTheShareTileStaysLime() {
        let dark = RecapPalette.palette(for: .total, theme: .graphite)
        let light = RecapPalette.palette(for: .total, theme: .paper)
        XCTAssertEqual(dark.ink, UIColor(hex: "#F4F5F7"))
        XCTAssertEqual(light.ink, UIColor(hex: "#1D1B16"))
        XCTAssertEqual(dark.accent, UIColor(hex: "#C8F169"))
        XCTAssertEqual(light.accent, UIColor(hex: "#1D1B16"))
        XCTAssertTrue(dark.prefersLightStatusBar)
        XCTAssertFalse(light.prefersLightStatusBar)
        if case .solid(let color) = RecapPalette.limeTotal.background {
            XCTAssertEqual(color, UIColor(hex: "#C8F169"))
        } else {
            XCTFail("The share tile must stay lime")
        }
    }

    func testOtherRecapCardsIgnoreTheTheme() {
        let a = RecapPalette.palette(for: .mostExpensive, theme: .graphite)
        let b = RecapPalette.palette(for: .mostExpensive, theme: .paper)
        XCTAssertEqual(a.ink, b.ink)
        XCTAssertEqual(a.secondary, b.secondary)
    }

    @MainActor
    func testFirstRecapDateFormatting() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14))!
        XCTAssertEqual(WhatsNewViewModel.formatFirstRecapDate(date, calendar: calendar, locale: Locale(identifier: "en_US")), "Sep 14")
        XCTAssertEqual(WhatsNewViewModel.formatFirstRecapDate(date, calendar: calendar, locale: Locale(identifier: "tr_TR")), "14 Eyl")
    }
}
