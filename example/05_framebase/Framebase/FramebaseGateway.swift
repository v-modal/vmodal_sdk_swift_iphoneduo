import Foundation
import VModalSDK

struct GatewayConnection: Sendable, Equatable {
    let accountID: String
    let indexVersion: Int?
}

struct FramebaseUploadHandle: Sendable {
    let progress: AsyncStream<UploadProgress>
    private let resultBlock: @Sendable () async throws -> Bool
    private let cancelBlock: @Sendable () -> Void

    init(
        progress: AsyncStream<UploadProgress>,
        result: @escaping @Sendable () async throws -> Bool,
        cancel: @escaping @Sendable () -> Void
    ) {
        self.progress = progress
        resultBlock = result
        cancelBlock = cancel
    }

    func result() async throws -> Bool { try await resultBlock() }
    func cancel() { cancelBlock() }
}

protocol FramebaseGateway: Sendable {
    func connect(key: String) async throws -> GatewayConnection
    func refreshVersion() async throws -> Int?
    func upload(file: URL, remoteFilename: String) async throws -> FramebaseUploadHandle
    func createIndex(cancellation: CancellationToken) async throws -> String
    func indexStatus(jobID: String, cancellation: CancellationToken) async throws -> String
    func search(
        query: String, maxDistance: Double, generation: Int, cancellation: CancellationToken
    ) async throws -> SearchBatch
    func close() async
}

actor SDKFramebaseGateway: FramebaseGateway {
    private let baseURL: URL?
    private let transport: (any VModalTransport)?
    private let signedTransport: (any SignedUploadTransport)?
    private var provider: MutableAPIKeyProvider?
    private var client: VModalClient?
    private var version: Int?

    init(
        baseURL: URL? = nil,
        transport: (any VModalTransport)? = nil,
        signedUploadTransport: (any SignedUploadTransport)? = nil
    ) {
        self.baseURL = baseURL
        self.transport = transport
        signedTransport = signedUploadTransport
    }

    func connect(key: String) async throws -> GatewayConnection {
        let nextProvider = try MutableAPIKeyProvider(key)
        let config = try SDKConfig(
            baseURL: baseURL, apiKeyProvider: nextProvider,
            requestTimeout: .seconds(60), responseIdleTimeout: .seconds(60), mode: .gateway
        )
        let next = VModalClient(
            config: config, transport: transport, signedUploadTransport: signedTransport
        )
        do {
            let profile = try await next.auth.me()
            guard let raw = profile.userID?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                throw AuthenticationError("Authenticated identity is unavailable")
            }
            let groups = try await next.collections.listGroups(mode: "vid_file")
            let nextVersion = groups.findGroup(framebaseCollection, mode: "vid_file")?.latestLancedbVersion
            let oldClient = client
            let oldProvider = provider
            client = next
            provider = nextProvider
            version = nextVersion
            await oldClient?.close()
            await oldProvider?.close()
            return GatewayConnection(accountID: raw, indexVersion: nextVersion)
        } catch {
            await next.close()
            await nextProvider.close()
            throw error
        }
    }

    func refreshVersion() async throws -> Int? {
        let client = try activeClient()
        let groups = try await client.collections.listGroups(mode: "vid_file")
        version = groups.findGroup(framebaseCollection, mode: "vid_file")?.latestLancedbVersion
        return version
    }

    func upload(file: URL, remoteFilename: String) async throws -> FramebaseUploadHandle {
        let client = try activeClient()
        let source = try UploadSource(fileURL: file, filename: remoteFilename, contentType: "video/mp4")
        let task = client.collections.videoUpload(
            source, collectionName: framebaseCollection, subCollectionName: framebaseStream
        )
        return FramebaseUploadHandle(
            progress: task.progress,
            result: { try await task.result.uploaded },
            cancel: { task.cancel() }
        )
    }

    func createIndex(cancellation: CancellationToken) async throws -> String {
        let request = IndexationSubmitRequest(
            mode: "vid_file", groupName: framebaseCollection, streamName: framebaseStream,
            indexType: "vid_img_emb", modality: "vid_img_emb", reProcess: true
        )
        let result = try await activeClient().indexes.createIndex(request, cancellation: cancellation)
        let job = result.jobID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !job.isEmpty else { throw ValidationError("Index job identifier is unavailable") }
        return job
    }

    func indexStatus(jobID: String, cancellation: CancellationToken) async throws -> String {
        try await activeClient().indexes.indexStatus(jobID, cancellation: cancellation).status
    }

    func search(
        query: String, maxDistance: Double, generation: Int, cancellation: CancellationToken
    ) async throws -> SearchBatch {
        let client = try activeClient()
        let started = Date()
        let response = try await client.searches.searchVideo(
            SearchRequest(
                queryText: query, mode: "vid_file", groupName: framebaseCollection,
                streamName: framebaseStream, searchSources: ["image"], limit: 30,
                imageEmbScoreMin: maxDistance, versionLancedb: version
            ),
            cancellation: cancellation
        )
        let searchMs = Int(Date().timeIntervalSince(started) * 1_000)
        let rows = response.data.compactMap(\.objectValue).filter {
            guard !framebaseFilename($0).isEmpty, let score = $0["score"]?.doubleValue else { return false }
            return score.isFinite && score <= maxDistance
        }
        if rows.isEmpty {
            return SearchBatch(
                matches: [], total: response.cntTotal, serverMilliseconds: response.executionTimeMs,
                roundTripMilliseconds: searchMs, imageMilliseconds: 0
            )
        }

        let candidates = rows.map { row -> [String: JSONValue] in
            let stream = framebaseFirstText(row, ["stream_name", "stream"])
            var item: [String: JSONValue] = [
                "mode": .string("vid_file"), "group_name": .string(framebaseCollection),
                "modality": .string("vid_img"),
                "stream_name": .string(stream.isEmpty ? framebaseStream : stream),
                "filename": .string(framebaseFilename(row)),
            ]
            let stamp = framebaseTimestamp13(row)
            if !stamp.isEmpty { item["ts_unix_13digits"] = .string(stamp) }
            return item
        }
        let resolved = try await client.images.getURLBulk(candidates, cancellation: cancellation)
        var locators: [Int: String] = [:]
        for (position, row) in resolved.records.enumerated() {
            guard framebaseFound(row),
                  let index = framebaseInputIndex(row["input_index"], fallback: position),
                  rows.indices.contains(index), locators[index] == nil,
                  let locator = framebaseLocator(row)
            else { continue }
            locators[index] = locator
        }

        var images: [Int: Data] = [:]
        if !locators.isEmpty {
            let ordered = locators.keys.sorted()
            let urls = ordered.compactMap { locators[$0] }
            let downloaded = try await client.images.getImageBulkFromURLs(urls, cancellation: cancellation)
            var byURL: [String: Data] = [:]
            var byPosition: [Int: Data] = [:]
            for (position, row) in downloaded.records.enumerated() {
                guard let data = framebaseImageData(row) else { continue }
                let locator = framebaseFirstText(row, ["url_pre_signed", "url"])
                if !locator.isEmpty, byURL[locator] == nil { byURL[locator] = data }
                if let index = framebaseInputIndex(row["input_index"], fallback: position), byPosition[index] == nil {
                    byPosition[index] = data
                }
            }
            for (position, index) in ordered.enumerated() {
                guard let locator = locators[index] else { continue }
                images[index] = byURL[locator] ?? byPosition[position]
            }
        }
        try await cancellation.throwIfCanceled()
        let imageMs = max(0, Int(Date().timeIntervalSince(started) * 1_000) - searchMs)
        let matches = rows.enumerated().map { index, row in
            let locator = locators[index]
            let fallback = locator.flatMap { value -> URL? in
                guard value.lowercased().hasPrefix("https://") else { return nil }
                return URL(string: value)
            }
            return FrameMatch(
                id: "\(generation)-\(index)", raw: row, filename: framebaseFilename(row),
                timestamp: framebaseTimestamp13(row), seconds: framebaseSeconds(row),
                imageData: images[index], fallbackURL: fallback
            )
        }
        return SearchBatch(
            matches: matches, total: response.cntTotal, serverMilliseconds: response.executionTimeMs,
            roundTripMilliseconds: searchMs, imageMilliseconds: imageMs
        )
    }

    func close() async {
        let oldClient = client
        let oldProvider = provider
        client = nil
        provider = nil
        version = nil
        await oldClient?.close()
        await oldProvider?.close()
    }

    private func activeClient() throws -> VModalClient {
        guard let client else { throw AuthenticationError("Connect before using Framebase") }
        return client
    }
}

func framebaseInputIndex(_ value: JSONValue?, fallback: Int) -> Int? {
    guard let value else { return fallback }
    switch value {
    case .int(let raw): return Int(exactly: raw)
    case .double(let raw) where raw.isFinite && raw.rounded() == raw: return Int(exactly: raw)
    case .string(let raw): return Int(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    default: return nil
    }
}

func framebaseLocator(_ row: [String: JSONValue]) -> String? {
    let value = framebaseFirstText(row, ["url_pre_signed", "url"])
    guard !value.isEmpty, let parts = URLComponents(string: value) else { return nil }
    if parts.scheme?.lowercased() == "https", parts.host?.isEmpty == false { return value }
    if parts.scheme == nil, parts.host == nil, parts.path == "/api/external/v1/image/get_image" { return value }
    return nil
}

private func framebaseFound(_ row: [String: JSONValue]) -> Bool {
    guard case .bool(let value) = row["found"] else { return true }
    return value
}

private func framebaseImageData(_ row: [String: JSONValue]) -> Data? {
    let value = framebaseFirstText(row, ["content_base64", "img_base64"])
    return value.isEmpty ? nil : Data(base64Encoded: value)
}
