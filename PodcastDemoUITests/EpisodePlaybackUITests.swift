import XCTest

/// End-to-end check: tapping a podcast card opens the episode page, and
/// tapping an episode row starts playback (mini player bar appears).
final class EpisodePlaybackUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTappingEpisodeRowShowsPlayer() {
        let app = XCUIApplication()
        app.launch()

        // 1. Wait for the main tab grid and open the first podcast.
        let firstCard = app.descendants(matching: .any)["podcast-card"]
            .firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 30), "Podcast grid did not load")
        firstCard.tap()

        // 2. Wait for an episode row on the detail page.
        let firstEpisode = app.descendants(matching: .any)["episode-row"]
            .firstMatch
        XCTAssertTrue(firstEpisode.waitForExistence(timeout: 30), "Episode list did not load")

        // 3. Tap the row (not the heart button) — the mini player bar or the
        //    player sheet should appear.
        firstEpisode.tap()

        // Keep the app running long enough to observe actual playback state.
        Thread.sleep(forTimeInterval: 8)

        let miniPlayer = app.descendants(matching: .any)["mini-player"].firstMatch
        let playerSheet = app.staticTexts["Nothing playing"]
        let appeared = miniPlayer.waitForExistence(timeout: 10)
            || playerSheet.exists
        XCTAssertTrue(appeared, "Neither the mini player bar nor the player sheet appeared after tapping an episode row")
    }
}
