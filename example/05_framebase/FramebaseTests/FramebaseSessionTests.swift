import Foundation
import XCTest
import VModalSDK
@testable import Framebase

actor FakeGateway: FramebaseGateway {
    var accountID = "account-1"
    var version: Int? = 2
    var statuses = ["completed"]
    private(set) var connectCount = 0
    private(set) var createCount = 0
    private(set) var closeCount = 0

    func connect(key: String) -> GatewayConnection {
        connectCount += 1
        return GatewayConnection(accountID: accountID, indexVersion: version)
    }

    func refreshVersion() -> Int? { version }

    func upload(file: URL, remoteFilename: String) -> FramebaseUploadHandle {
        let stream = AsyncStream<UploadProgress> { continuation in
            continuation.yield(.init(uploadedBytes: 1, totalBytes: 1))
            continuation.finish()
        }
        return FramebaseUploadHandle(progress: stream, result: { true }, cancel: {})
    }

    func createIndex(cancellation: CancellationToken) -> String {
        createCount += 1
        return "job-new"
    }

    func indexStatus(jobID: String, cancellation: CancellationToken) -> String {
        statuses.isEmpty ? "running" : statuses.removeFirst()
    }

    func search(
        query: String, maxDistance: Double, generation: Int, cancellation: CancellationToken
    ) -> SearchBatch {
        SearchBatch(matches: [], total: 0, serverMilliseconds: 0, roundTripMilliseconds: 0, imageMilliseconds: 0)
    }

    func close() { closeCount += 1 }
}

@MainActor
final class FramebaseSessionTests: XCTestCase {
    func testLaunchRestoresWithoutNetworkWork() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let gateway = FakeGateway()
        let session = FramebaseSession(store: ArchiveStore(root: root), gateway: gateway)
        await initialized(session)
        XCTAssertEqual(session.state.clips.count, 3)
        XCTAssertEqual(session.state.connection, .disconnected)
        let count = await gateway.connectCount
        XCTAssertEqual(count, 0)
        await session.shutdown()
    }

    func testAccountChangeResetsRemoteBoundState() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var clips = framebaseDefaultClips()
        for index in clips.indices { clips[index].uploaded = true }
        let snapshot = ArchiveSnapshot(
            clips: clips, pendingJobID: "old-job", accountID: "old-account",
            events: [ArchiveEvent(title: "Old", detail: "Old", isError: false, time: Date())]
        )
        let store = ArchiveStore(root: root)
        try await store.save(snapshot)
        let gateway = FakeGateway()
        let session = FramebaseSession(store: store, gateway: gateway)
        await initialized(session)
        let connected = await session.connect(key: "runtime-only")
        XCTAssertTrue(connected)
        XCTAssertTrue(session.state.clips.allSatisfy { !$0.uploaded })
        XCTAssertTrue(session.state.pendingJobID.isEmpty)
        XCTAssertFalse(session.state.events.contains { $0.title == "Old" })
        XCTAssertFalse(String(describing: session.state).contains("runtime-only"))
        await session.shutdown()
    }

    func testResumeSkipsUploadAndClearsCompletedJob() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshot = ArchiveSnapshot(
            clips: framebaseDefaultClips(), pendingJobID: "job-existing", accountID: "account-1", events: []
        )
        let store = ArchiveStore(root: root)
        try await store.save(snapshot)
        let gateway = FakeGateway()
        let session = FramebaseSession(store: store, gateway: gateway, delay: { _ in })
        await initialized(session)
        let connected = await session.connect(key: "runtime-only")
        XCTAssertTrue(connected)
        session.startPreparation()
        for _ in 0 ..< 200 where !session.state.pendingJobID.isEmpty { await Task.yield() }
        XCTAssertTrue(session.state.pendingJobID.isEmpty)
        XCTAssertTrue(session.state.ready)
        let creates = await gateway.createCount
        XCTAssertEqual(creates, 0)
        await session.shutdown()
    }

    private func initialized(_ session: FramebaseSession) async {
        await session.waitForRestore()
        XCTAssertTrue(session.state.initialized)
    }
}
