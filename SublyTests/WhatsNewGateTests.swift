import XCTest
@testable import Subly

final class WhatsNewGateTests: XCTestCase {

    func testUpdateShowsTheStory() {
        XCTAssertTrue(WhatsNewGate.shouldShow(currentVersion: "1.0.1", lastSeenVersion: "1.0.0", hasPayload: true))
    }

    func testExistingUserWithNoRecordShowsTheStory() {
        // Users from before this feature have no stored version: they updated.
        XCTAssertTrue(WhatsNewGate.shouldShow(currentVersion: "1.0.1", lastSeenVersion: nil, hasPayload: true))
    }

    func testFreshInstallIsStampedAndNeverShows() {
        let store = WhatsNewStore(defaults: makeDefaults())
        store.markSeen(version: "1.0.1")  // what registration does
        XCTAssertFalse(WhatsNewGate.shouldShow(currentVersion: "1.0.1", lastSeenVersion: store.lastSeenVersion, hasPayload: true))
    }

    func testSameVersionRelaunchDoesNotShowAgain() {
        XCTAssertFalse(WhatsNewGate.shouldShow(currentVersion: "1.0.1", lastSeenVersion: "1.0.1", hasPayload: true))
    }

    func testOlderVersionThanSeenDoesNotShow() {
        XCTAssertFalse(WhatsNewGate.shouldShow(currentVersion: "1.0.1", lastSeenVersion: "1.2.0", hasPayload: true))
    }

    func testNoPayloadNeverShows() {
        XCTAssertFalse(WhatsNewGate.shouldShow(currentVersion: "9.9.9", lastSeenVersion: nil, hasPayload: false))
    }

    func testVersionComparisonIsNumeric() {
        XCTAssertEqual(WhatsNewGate.compare("1.10.0", "1.9.2"), .orderedDescending)
        XCTAssertEqual(WhatsNewGate.compare("1.0", "1.0.0"), .orderedSame)
        XCTAssertEqual(WhatsNewGate.compare("2.0", "10.0"), .orderedAscending)
    }

    func testStoreRoundTrip() {
        let store = WhatsNewStore(defaults: makeDefaults())
        XCTAssertNil(store.lastSeenVersion)
        store.markSeen(version: "1.0.1")
        XCTAssertEqual(store.lastSeenVersion, "1.0.1")
        store.reset()
        XCTAssertNil(store.lastSeenVersion)
    }

    func testReleaseSwitchOffKeepsTheStoryDormant() {
        // Flip `WhatsNewPayload.isEnabled` only for a release; between
        // releases the payload is a template and nothing shows.
        let wasForced = WhatsNewPayload.isForcedOnForQA
        WhatsNewPayload.isForcedOnForQA = false
        defer { WhatsNewPayload.isForcedOnForQA = wasForced }
        if WhatsNewPayload.isEnabled {
            XCTAssertNotNil(WhatsNewPayload.active)
        } else {
            XCTAssertNil(WhatsNewPayload.active)
        }
        XCTAssertNotNil(WhatsNewPayload.payload(for: "1.0.1"), "The template payload stays in the bundle")
    }

    func testBundledPayloadMatchesTheRunningVersionAndHasSixCards() {
        let payload = WhatsNewPayload.payload(for: "1.0.1")
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.cards.count, 6)
        if case .intro(let features)? = payload?.cards.first {
            XCTAssertEqual(features.map(\.number), [1, 2, 3, 4, 5])
        } else {
            XCTFail("First card must be the intro")
        }
        if case .recapFinale? = payload?.cards.last {} else { XCTFail("Last card must be the recap finale") }
    }

    private func makeDefaults() -> UserDefaults {
        let name = "WhatsNewGateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
