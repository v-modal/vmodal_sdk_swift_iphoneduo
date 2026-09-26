import Foundation
import XCTest
@testable import Framebase

@MainActor
final class PlaybackSessionTests: XCTestCase {
    func testMissingLocalMovieFailsWithoutRemoteFallback() async {
        let player = PlaybackSession()
        await player.open(
            url: FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).mp4"),
            initialSeconds: 10
        )
        XCTAssertFalse(player.ready)
        XCTAssertEqual(player.error, "This video could not be opened.")
        player.close()
        XCTAssertNil(player.player)
    }

    func testOutOfRangeSeekDoesNotChangeTime() {
        let player = PlaybackSession()
        player.seek(10)
        XCTAssertEqual(player.current, 0)
    }
}
