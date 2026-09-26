import Foundation
import VModalSDK

@MainActor
final class AppSession: ObservableObject {
    @Published var token = ""
    @Published var projectID = "demo"
    @Published var collection = ""
    @Published var stream = "camera-a"
    @Published var query = "delivery van"
    @Published private(set) var collections: [String] = []
    @Published private(set) var jobCount = 0
    @Published private(set) var resultCount = 0
    @Published private(set) var uploadPercent = 0
    @Published private(set) var message = "Enter a token to connect."

    private var project: VModalProject?
    private var keys: MutableAPIKeyProvider?
    private var requestToken: CancellationToken?
    private var upload: UploadTask<VideoUploadResponse>?

    func connect() async {
        do {
            let provider = try MutableAPIKeyProvider(token)
            let value = try VModal.configure(projectID: projectID, apiKeyProvider: provider)
            keys = provider
            project = value
            collections = try await value.listCollections()
            if collection.isEmpty { collection = collections.first ?? "field-notes" }
            message = "Connected."
        } catch { message = String(describing: error) }
    }

    func listJobs() async {
        do {
            jobCount = try await scope().listIndexJobs().total
            message = "Loaded \(jobCount) index jobs."
        } catch { message = String(describing: error) }
    }

    func search() async {
        let token = CancellationToken()
        requestToken = token
        do {
            resultCount = try await scope().search(query, cancellation: token).cntActual
            message = "Found \(resultCount) matches."
        } catch { message = String(describing: error) }
        requestToken = nil
    }

    func cancelSearch() {
        let token = requestToken
        Task { await token?.cancel() }
    }

    func upload(_ url: URL) {
        guard upload == nil else { return }
        do {
            let item = try scope().upload(try UploadSource(fileURL: url))
            upload = item
            Task {
                for await update in item.progress { uploadPercent = update.percent }
            }
            Task {
                do {
                    _ = try await item.result
                    message = "Upload complete."
                } catch { message = String(describing: error) }
                upload = nil
            }
        } catch { message = String(describing: error) }
    }

    func cancelUpload() {
        upload?.cancel()
    }

    func rotateKey() async {
        do {
            try await keys?.rotate(token)
            message = "Credential rotated for the next request."
        } catch { message = String(describing: error) }
    }

    func close() async {
        requestToken = nil
        upload?.cancel()
        upload = nil
        await project?.close()
        project = nil
        await keys?.close()
        keys = nil
    }

    private func scope() throws -> VModalScope {
        guard let project else { throw ValidationError("Connect before using a scope") }
        return try project.scope(collectionName: collection, streamName: stream)
    }
}
