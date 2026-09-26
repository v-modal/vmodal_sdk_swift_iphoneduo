import XCTest
import VModalSDK
@testable import Framebase

final class FramebaseMappingTests: XCTestCase {
    func testDefaultsAndFormatting() {
        let clips = framebaseDefaultClips()
        XCTAssertEqual(clips.map(\.id), ["neighborhood_crossing", "downtown_traffic", "evening_junction"])
        XCTAssertEqual(clips.map(\.city), ["San Francisco", "Singapore", "Mexico City"])
        XCTAssertEqual(framebaseTimeLabel(75), "01:15")
        XCTAssertEqual(framebaseTimeLabel(.nan), "00:00")
    }

    func testFilenameAndTimestampNormalization() {
        XCTAssertEqual(framebaseFilename(["path": .string(#"C:\clips\bus.mp4"#)]), "bus.mp4")
        XCTAssertEqual(framebaseFilename([
            "item_id": .string("street_study-evening_junction.mp4-0000000006000"),
            "stream": .string("street_study"), "ts_unix": .string("0000000006000"),
        ]), "evening_junction.mp4")
        XCTAssertEqual(framebaseTimestamp13(["ts_unix": .string("1234567890")]), "1234567890000")
        XCTAssertEqual(framebaseTimestamp13(["timestamp_ms": .int(6000)]), "0000000006000")
        XCTAssertEqual(framebaseTimestamp13(["timestamp_ms": .double(-1)]), "")
    }

    func testPlaybackAndGroupingPreserveRank() {
        XCTAssertEqual(framebaseSeconds(["ts_unix": .string("0000000006000")]), 6)
        XCTAssertNil(framebaseSeconds(["ts_unix": .string("1710000000000")]))
        let rows = [0.0, 4.0, 9.0].enumerated().map { index, seconds in
            FrameMatch(
                id: "0-\(index)", raw: [:], filename: "a.mp4", timestamp: "",
                seconds: seconds, imageData: nil, fallbackURL: nil
            )
        }
        XCTAssertEqual(framebaseGroups(rows).first?.matches.map(\.id), ["0-0", "0-2"])
    }

    func testImageJoinValidation() {
        XCTAssertEqual(framebaseInputIndex(.double(2), fallback: 0), 2)
        XCTAssertEqual(framebaseInputIndex(.string("3"), fallback: 0), 3)
        XCTAssertNil(framebaseInputIndex(.double(2.5), fallback: 0))
        XCTAssertEqual(framebaseLocator(["url_pre_signed": .string("/api/external/v1/image/get_image?k=x")]), "/api/external/v1/image/get_image?k=x")
        XCTAssertNil(framebaseLocator(["url_pre_signed": .string("http://example.test/image")]))
    }
}
