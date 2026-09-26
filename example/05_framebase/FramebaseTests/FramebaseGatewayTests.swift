import Foundation
import XCTest
import VModalSDK
@testable import Framebase

actor QueueTransport: VModalTransport {
    private var responses: [[String: JSONValue]]
    private(set) var requests: [VModalRequest] = []
    private(set) var closed = false

    init(_ responses: [[String: JSONValue]]) { self.responses = responses }

    func send(_ request: VModalRequest) async throws -> VModalResponse {
        try await request.cancellation.throwIfCanceled()
        guard !responses.isEmpty else { throw QueueError.empty }
        requests.append(request)
        let data = try JSONEncoder().encode(JSONValue.object(responses.removeFirst()))
        return VModalResponse(statusCode: 200, declaredLength: Int64(data.count), body: .one(data))
    }

    func close() { closed = true }
}

private enum QueueError: Error { case empty }

private extension AsyncThrowingStream where Element == Data, Failure == Error {
    static func one(_ data: Data) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(data)
            continuation.finish()
        }
    }
}

final class FramebaseGatewayTests: XCTestCase {
    func testConnectUsesIdentityThenRawCollection() async throws {
        let transport = QueueTransport([
            ["user_id": .string("account-1")],
            ["total": .int(1), "data": .array([.object([
                "mode": .string("vid_file"), "group_name": .string(framebaseCollection),
                "lancedb_versions": .array([.string("v2"), .string("v4")]),
            ])])],
        ])
        let gateway = SDKFramebaseGateway(transport: transport)
        let value = try await gateway.connect(key: "test-only-placeholder")
        XCTAssertEqual(value, GatewayConnection(accountID: "account-1", indexVersion: 4))
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[1].url.query, "mode=vid_file")
        await gateway.close()
        let closed = await transport.closed
        XCTAssertTrue(closed)
    }

    func testRankedImageJoinKeepsPartialMatches() async throws {
        let route = "/api/external/v1/image/get_image"
        let transport = QueueTransport([
            ["user_id": .string("account-1")],
            ["total": .int(1), "data": .array([.object([
                "mode": .string("vid_file"), "group_name": .string(framebaseCollection),
                "lancedb_versions": .array([.string("v2")]),
            ])])],
            [
                "data": .array([
                    .object(["title": .string("first"), "ts_unix": .string("0000000006000"), "score": .double(0.71)]),
                    .object(["title": .string("second"), "ts_unix": .string("0000000008000"), "score": .double(0.76)]),
                    .object(["title": .string("missing"), "ts_unix": .string("0000000010000"), "score": .double(0.80)]),
                ]),
                "cnt_total": .int(3), "execution_time_ms": .double(42.5),
            ],
            ["records": .array([
                .object(["input_index": .double(1), "found": .bool(true), "url_pre_signed": .string("\(route)?id=second")]),
                .object(["input_index": .string("0"), "found": .bool(true), "url_pre_signed": .string("\(route)?id=first")]),
                .object(["input_index": .int(2), "found": .bool(false)]),
                .object(["input_index": .int(-1), "found": .bool(true), "url_pre_signed": .string("http://bad.test")]),
            ])],
            ["records": .array([
                .object(["url_pre_signed": .string("\(route)?id=first"), "content_base64": .string(Data([1, 2, 3]).base64EncodedString())]),
                .object(["url_pre_signed": .string("\(route)?id=second"), "content_base64": .string(Data([4, 5, 6]).base64EncodedString())]),
            ])],
        ])
        let gateway = SDKFramebaseGateway(transport: transport)
        _ = try await gateway.connect(key: "test-only-placeholder")
        let batch = try await gateway.search(
            query: "crosswalk", maxDistance: 0.85, generation: 7, cancellation: CancellationToken()
        )
        XCTAssertEqual(batch.matches.map(\.filename), ["first", "second", "missing"])
        XCTAssertEqual(batch.matches.map(\.id), ["7-0", "7-1", "7-2"])
        XCTAssertEqual(batch.matches[0].imageData, Data([1, 2, 3]))
        XCTAssertEqual(batch.matches[1].imageData, Data([4, 5, 6]))
        XCTAssertNil(batch.matches[2].imageData)
        XCTAssertEqual(batch.total, 3)
        let requests = await transport.requests
        let search = try XCTUnwrap(requests[2].jsonBody?.objectValue)
        XCTAssertEqual(search["group_name"], .string(framebaseCollection))
        XCTAssertEqual(search["stream_name"], .string(framebaseStream))
        XCTAssertEqual(search["search_sources"], .array([.string("image")]))
        XCTAssertEqual(search["image_emb_score_min"], .double(0.85))
        await gateway.close()
    }

    func testCutoffSkipsImageCallsAndPreservesServerTotal() async throws {
        let transport = QueueTransport([
            ["user_id": .string("account-1")],
            ["total": .int(0), "data": .array([])],
            ["data": .array([.object(["title": .string("street"), "score": .double(0.926)])]), "cnt_total": .int(1)],
        ])
        let gateway = SDKFramebaseGateway(transport: transport)
        _ = try await gateway.connect(key: "test-only-placeholder")
        let batch = try await gateway.search(
            query: "bus", maxDistance: 0.85, generation: 1, cancellation: CancellationToken()
        )
        XCTAssertTrue(batch.matches.isEmpty)
        XCTAssertEqual(batch.total, 1)
        let requestCount = await transport.requests.count
        XCTAssertEqual(requestCount, 3)
        await gateway.close()
    }
}
