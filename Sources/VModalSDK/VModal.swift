import Foundation

public enum VModal {
    public static func configure(
        projectID: String, apiKeyProvider: any APIKeyProvider, baseURL: URL? = nil,
        timeout: Duration = .seconds(30), mode: SDKMode = .gateway, maxRetries: Int = 1
    ) throws -> VModalProject {
        let project = try ContentScope.project(projectID)
        let config = try SDKConfig(baseURL: baseURL, apiKeyProvider: apiKeyProvider, requestTimeout: timeout, mode: mode, maxRetries: maxRetries)
        return VModalProject(projectID: project, client: VModalClient(config: config))
    }

    public static func fromClient(projectID: String, client: VModalClient) throws -> VModalProject {
        VModalProject(projectID: try ContentScope.project(projectID), client: client)
    }
}

public final class VModalProject: Sendable {
    public let projectID: String
    private let client: VModalClient
    private let closeState = ProjectCloseState()
    init(projectID: String, client: VModalClient) { self.projectID = projectID; self.client = client }

    public func scope(collectionName: String, streamName: String) throws -> VModalScope {
        VModalScope(scope: try ContentScope(projectID: projectID, collectionName: collectionName, streamName: streamName), client: client)
    }

    public func listCollections(mode: String? = nil, cancellation: CancellationToken? = nil) async throws -> [String] {
        let groups = try await client.collections.listGroups(mode: mode, cancellation: cancellation)
        var seen = Set<String>(); var result: [String] = []
        for item in groups.data {
            if let name = try ContentScope.decodeCollection(projectID: projectID, backendName: item.groupName), seen.insert(name).inserted { result.append(name) }
        }
        return result
    }

    public func close() async {
        guard await closeState.begin() else { return }
        await client.close()
    }
}
private actor ProjectCloseState { private var closed = false; func begin() -> Bool { guard !closed else { return false }; closed = true; return true } }

public struct VModalScope: Sendable {
    private let scope: ContentScope
    private let client: VModalClient
    public var projectID: String { scope.projectID }
    public var collectionName: String { scope.collectionName }
    public var streamName: String { scope.streamName }
    init(scope: ContentScope, client: VModalClient) { self.scope = scope; self.client = client }

    public func upload(_ source: UploadSource, options: ScopedUploadOptions = .init()) -> UploadTask<VideoUploadResponse> {
        client.collections.videoUpload(source, collectionName: scope.backendCollectionName, subCollectionName: streamName, mode: options.mode, modality: options.modality, ttl: options.ttl, options: options.uploadOptions)
    }
    public func uploadMetadata(_ part: VModalFilePart, options: ScopedMetadataOptions = .init(), cancellation: CancellationToken? = nil) async throws -> MetadataParquetUploadResponse {
        try await client.collections.uploadMetadataJSONL(part, mode: options.mode, groupName: scope.backendCollectionName, streamName: streamName, writeMode: options.writeMode, allowOverlap: options.allowOverlap, cancellation: cancellation)
    }
    public func search(_ query: String, options: ScopedSearchOptions = .init(), cancellation: CancellationToken? = nil) async throws -> SearchResponse {
        try await client.searches.searchVideo(SearchRequest(queryText: query, queryMetadata: options.queryMetadata, queryMetadataText: options.queryMetadataText, imageQuery: options.imageQuery, mode: options.mode, groupName: scope.backendCollectionName, streamName: streamName, searchSources: options.searchSources, searchCombineMode: options.searchCombineMode, startDate: options.startDate, endDate: options.endDate, offset: options.offset, limit: options.limit, textEmbScoreMin: options.textEmbScoreMin, imageEmbScoreMin: options.imageEmbScoreMin, versionLancedb: options.versionLancedb), cancellation: cancellation)
    }
    public func addAssets(collectionID: String, assetIDs: [String], options: ScopedAddAssetsOptions = .init(), cancellation: CancellationToken? = nil) async throws -> CollectionAddAssetsResponse {
        try await client.collections.addAssets(collectionID: collectionID, assetIDs: assetIDs, mode: options.mode, groupName: scope.backendCollectionName, streamName: streamName, cancellation: cancellation)
    }
    public func updateAsset(filename: String, changes: ScopedAssetChanges, cancellation: CancellationToken? = nil) async throws -> CollectionDescriptionUpdateResponse {
        let clean = filename.trimmingCharacters(in: .whitespacesAndNewlines); guard !clean.isEmpty else { throw ValidationError("filename is required") }
        guard !changes.mode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ValidationError("mode is required") }
        return try await client.collections.updateDescription(groupName: scope.backendCollectionName, mode: changes.mode, streamName: streamName, filenameSanitized: clean, description: changes.description, tag: changes.tags, cancellation: cancellation)
    }
    public func createIndex(options: ScopedCreateIndexOptions = .init(), cancellation: CancellationToken? = nil) async throws -> IndexationSubmitResponse {
        try await client.indexes.createIndex(IndexationSubmitRequest(mode: options.mode, groupName: scope.backendCollectionName, streamName: streamName, indexType: options.indexType, modality: options.modality, insertMode: options.insertMode, createIndex: options.createIndex, version: options.version, startDate: options.startDate, endDate: options.endDate, embeddingModel: options.embeddingModel, reProcess: options.reProcess, dryRun: options.dryRun), cancellation: cancellation)
    }
    public func listIndexJobs(options: ScopedIndexJobsOptions = .init(), cancellation: CancellationToken? = nil) async throws -> IndexationJobsListResponse { try await client.indexes.jobsList(status: options.status, mode: options.mode, groupName: scope.backendCollectionName, limit: options.limit, cancellation: cancellation) }
    public func indexStatus(jobID: String, cancellation: CancellationToken? = nil) async throws -> IndexationStatusResponse { try await client.indexes.indexStatus(jobID, cancellation: cancellation) }
    public func deleteIndex(version: String, options: ScopedDeleteIndexOptions = .init(), cancellation: CancellationToken? = nil) async throws -> IndexationDeleteResponse { try await client.indexes.deleteIndex(IndexationDeleteRequest(mode: options.mode, groupName: scope.backendCollectionName, version: version, modality: options.modality, dryRun: options.dryRun, confirm: options.confirm), cancellation: cancellation) }
    public func deleteCollection(options: ScopedDeleteCollectionOptions = .init(), cancellation: CancellationToken? = nil) async throws -> DeleteCollectionResponse { try await client.collections.delete(groupName: scope.backendCollectionName, mode: options.mode, scope: options.scope, dryRun: options.dryRun, confirm: options.confirm, cancellation: cancellation) }
}

public struct ScopedUploadOptions: Sendable { public let mode: String; public let modality: String; public let ttl: Int; public let uploadOptions: VideoUploadOptions; public init(mode: String = "vid_file", modality: String = "vid_raw", ttl: Int = 12_600, uploadOptions: VideoUploadOptions = .init()) { self.mode = mode; self.modality = modality; self.ttl = ttl; self.uploadOptions = uploadOptions } }
public struct ScopedMetadataOptions: Sendable { public let mode: String; public let writeMode: String; public let allowOverlap: Bool; public init(mode: String = "img_file", writeMode: String = "append", allowOverlap: Bool = false) { self.mode = mode; self.writeMode = writeMode; self.allowOverlap = allowOverlap } }
public struct ScopedSearchOptions: Sendable {
    public let queryMetadata: [String: JSONValue]?; public let queryMetadataText, imageQuery: String?; public let mode: String; public let searchSources: [String]; public let searchCombineMode: String; public let startDate, endDate: String?; public let offset, limit: Int; public let textEmbScoreMin, imageEmbScoreMin: Double; public let versionLancedb: Int?
    public init(queryMetadata: [String: JSONValue]? = nil, queryMetadataText: String? = nil, imageQuery: String? = nil, mode: String = "vid_file", searchSources: [String] = ["image"], searchCombineMode: String = "union", startDate: String? = nil, endDate: String? = nil, offset: Int = 0, limit: Int = 50, textEmbScoreMin: Double = 0.90, imageEmbScoreMin: Double = 1.5, versionLancedb: Int? = nil) { self.queryMetadata = queryMetadata; self.queryMetadataText = queryMetadataText; self.imageQuery = imageQuery; self.mode = mode; self.searchSources = searchSources; self.searchCombineMode = searchCombineMode; self.startDate = startDate; self.endDate = endDate; self.offset = offset; self.limit = limit; self.textEmbScoreMin = textEmbScoreMin; self.imageEmbScoreMin = imageEmbScoreMin; self.versionLancedb = versionLancedb }
}
public struct ScopedAddAssetsOptions: Sendable { public let mode: String; public init(mode: String = "vid_file") { self.mode = mode } }
public struct ScopedAssetChanges: Sendable { public let mode: String; public let description: String?; public let tags: [String]?; public init(mode: String = "vid_file", description: String? = nil, tags: [String]? = nil) { self.mode = mode; self.description = description; self.tags = tags } }
public struct ScopedCreateIndexOptions: Sendable { public let mode: String; public let indexType, modality: String?; public let insertMode: String; public let createIndex: Bool; public let version: String; public let startDate, endDate, embeddingModel: String?; public let reProcess, dryRun: Bool; public init(mode: String = "vid_file", indexType: String? = nil, modality: String? = nil, insertMode: String = "append", createIndex: Bool = true, version: String = "new_version", startDate: String? = nil, endDate: String? = nil, embeddingModel: String? = nil, reProcess: Bool = false, dryRun: Bool = false) { self.mode = mode; self.indexType = indexType; self.modality = modality; self.insertMode = insertMode; self.createIndex = createIndex; self.version = version; self.startDate = startDate; self.endDate = endDate; self.embeddingModel = embeddingModel; self.reProcess = reProcess; self.dryRun = dryRun } }
public struct ScopedIndexJobsOptions: Sendable { public let status, mode: String?; public let limit: Int; public init(status: String? = nil, mode: String? = nil, limit: Int = 200) { self.status = status; self.mode = mode; self.limit = limit } }
public struct ScopedDeleteIndexOptions: Sendable { public let mode: String; public let modality: String?; public let dryRun, confirm: Bool; public init(mode: String = "vid_file", modality: String? = nil, dryRun: Bool = false, confirm: Bool = false) { self.mode = mode; self.modality = modality; self.dryRun = dryRun; self.confirm = confirm } }
public struct ScopedDeleteCollectionOptions: Sendable { public let mode, scope: String; public let dryRun, confirm: Bool; public init(mode: String = "vid_file", scope: String = "all", dryRun: Bool = false, confirm: Bool = false) { self.mode = mode; self.scope = scope; self.dryRun = dryRun; self.confirm = confirm } }
