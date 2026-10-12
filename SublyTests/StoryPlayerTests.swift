import XCTest
@testable import Subly

@MainActor
final class StoryPlayerTests: XCTestCase {

    func testAdvancesAfterTheCardDuration() {
        let player = StoryPlayer(count: 3, cardDuration: 7)
        var indices: [Int] = []
        player.onSnapshot = { indices.append($0.index) }
        player.start()
        player.advance(by: 6.9)
        XCTAssertEqual(player.index, 0)
        player.advance(by: 0.2)
        XCTAssertEqual(player.index, 1)
        XCTAssertEqual(indices, [0, 1])
        player.stop()
    }

    func testLastCardDoesNotAutoAdvanceOrFinish() {
        let player = StoryPlayer(count: 2, cardDuration: 7, lastCardAutoAdvances: false)
        var finished = false
        player.onFinishedPlaying = { finished = true }
        player.start()
        player.next()
        XCTAssertTrue(player.isLastCard)
        var progress: Double = -1
        player.onProgress = { progress = $0 }
        player.advance(by: 60)
        XCTAssertEqual(player.index, 1)
        XCTAssertFalse(finished)
        XCTAssertEqual(progress, -1, "The last card's bar must not fill")
        player.stop()
    }

    func testPauseStopsTheClock() {
        let player = StoryPlayer(count: 3, cardDuration: 7)
        player.start()
        player.setPaused(true)
        player.advance(by: 20)
        XCTAssertEqual(player.index, 0)
        player.setPaused(false)
        player.advance(by: 7)
        XCTAssertEqual(player.index, 1)
        player.stop()
    }

    func testPreviousClampsAtTheFirstCard() {
        let player = StoryPlayer(count: 3, cardDuration: 7)
        player.start()
        player.previous()
        XCTAssertEqual(player.index, 0)
        player.next()
        player.previous()
        XCTAssertEqual(player.index, 0)
        player.stop()
    }
}
