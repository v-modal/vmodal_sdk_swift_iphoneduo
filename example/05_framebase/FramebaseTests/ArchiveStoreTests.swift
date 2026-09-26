import Foundation
import XCTest
@testable import Framebase

final class ArchiveStoreTests: XCTestCase {
    func testRestoreFallbackAndApprovedPersistenceRoots() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ArchiveStore(root: root)
        let initial = await store.load()
        XCTAssertEqual(initial.snapshot.clips.count, 3)
        var snapshot = initial.snapshot
        snapshot.events = Array((0 ..< 45).map {
            ArchiveEvent(title: "Event \($0)", detail: "safe", isError: false, time: Date(timeIntervalSince1970: Double($0)))
        }.reversed())
        try await store.save(snapshot)
        let data = try Data(contentsOf: root.appendingPathComponent("archive.json"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), Set(["clips", "pendingJobID", "accountID", "events"]))
        XCTAssertEqual((json["events"] as? [Any])?.count, 40)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("api_key"))
    }

    func testCorruptArchiveRestoresDefaults() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: root.appendingPathComponent("archive.json"))
        let loaded = await ArchiveStore(root: root).load()
        XCTAssertEqual(loaded.snapshot.clips.count, 3)
        XCTAssertNotNil(loaded.notice)
    }
}
