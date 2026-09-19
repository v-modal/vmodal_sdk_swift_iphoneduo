import Foundation

public let vmodalSDKVersion = "1.2.5"

public final class VModalClient: Sendable {
    public let config: SDKConfig
    public let transport: any VModalTransport
    public let signedUploadTransport: any SignedUploadTransport
    public let http: HTTPClient
    public let auth: AuthResource
    public let searches: SearchesResource
    public let collections: CollectionsResource
    public let indexes: IndexesResource
    public let admin: AdminResource
    public let r2: R2Resource
    public let images: ImagesResource
    public let gdrive = GDriveResource()
    public let sql = SQLResource()
    private let closeState = ClientCloseState()

    public init(
        config: SDKConfig,
        transport: (any VModalTransport)? = nil,
        signedUploadTransport: (any SignedUploadTransport)? = nil
    ) {
        self.config = config
        self.transport = transport ?? URLSessionVModalTransport()
        self.signedUploadTransport = signedUploadTransport ?? URLSessionSignedUploadTransport()
        http = HTTPClient(config: config, transport: self.transport)
        auth = AuthResource(http: http); searches = SearchesResource(http: http)
        collections = CollectionsResource(http: http, signedUploadTransport: self.signedUploadTransport); indexes = IndexesResource(http: http)
        admin = AdminResource(http: http); r2 = R2Resource(http: http); images = ImagesResource(http: http)
    }

    public func health(cancellation: CancellationToken? = nil) async throws -> HealthResponse { try await auth.health(cancellation: cancellation) }
    public func authCheck(cancellation: CancellationToken? = nil) async throws -> Bool { try await auth.authCheck(cancellation: cancellation) }

    public static func fromEnvironment(
        _ env: [String: String], transport: (any VModalTransport)? = nil,
        signedUploadTransport: (any SignedUploadTransport)? = nil,
        resolveIdentity: Bool = true
    ) async throws -> VModalClient {
        let config = try SDKConfig.fromEnvironment(env)
        let client = VModalClient(config: config, transport: transport, signedUploadTransport: signedUploadTransport)
        guard resolveIdentity, config.userID == nil else { return client }
        do {
            let profile = try await client.auth.me()
            guard let userID = profile.userID?.trimmingCharacters(in: .whitespacesAndNewlines), !userID.isEmpty else {
                throw AuthenticationError("auth/me returned no user_id")
            }
            let resolved = try SDKConfig(
                baseURL: config.usersAPIBaseURL, userID: userID, tenantID: profile.tenantID,
                email: profile.email, apiKeyProvider: config.apiKeyProvider,
                requestTimeout: config.requestTimeout, responseIdleTimeout: config.responseIdleTimeout,
                mode: config.mode, maxRetries: config.maxRetries
            )
            return VModalClient(config: resolved, transport: client.transport, signedUploadTransport: client.signedUploadTransport)
        } catch {
            await client.close()
            throw error
        }
    }

    public static func unsafeDirect(
        baseURL: URL, userID: String, tenantID: String? = nil, email: String? = nil,
        apiKeyProvider: (any APIKeyProvider)? = nil, timeout: Duration = .seconds(30),
        maxRetries: Int = 1, transport: (any VModalTransport)? = nil,
        signedUploadTransport: (any SignedUploadTransport)? = nil
    ) throws -> VModalClient {
        let config = try SDKConfig(baseURL: baseURL, userID: userID, tenantID: tenantID, email: email, apiKeyProvider: apiKeyProvider, requestTimeout: timeout, mode: .direct, maxRetries: maxRetries)
        return VModalClient(config: config, transport: transport, signedUploadTransport: signedUploadTransport)
    }

    public func close() async {
        guard await closeState.begin() else { return }
        await transport.close(); await signedUploadTransport.close()
    }
}

private actor ClientCloseState {
    private var closed = false
    func begin() -> Bool { guard !closed else { return false }; closed = true; return true }
}
