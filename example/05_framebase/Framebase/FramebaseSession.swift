import Combine
import Foundation
import VModalSDK

typealias FramebaseDelay = @Sendable (Duration) async throws -> Void

@MainActor
final class FramebaseSession: ObservableObject {
    @Published private(set) var state = FramebaseState()

    private let store: ArchiveStore
    private let gateway: any FramebaseGateway
    private let delay: FramebaseDelay
    private var accountID = ""
    private var restoreTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var workToken: CancellationToken?
    private var searchToken: CancellationToken?
    private var activeUpload: FramebaseUploadHandle?
    private var searchGeneration = 0
    private var closed = false

    init(
        store: ArchiveStore = ArchiveStore(),
        gateway: any FramebaseGateway = SDKFramebaseGateway(),
        delay: @escaping FramebaseDelay = { try await Task.sleep(for: $0) }
    ) {
        self.store = store
        self.gateway = gateway
        self.delay = delay
        restoreTask = Task { await restore() }
    }

    var groupedMatches: [MatchGroup] { framebaseGroups(state.batch?.matches ?? []) }

    func waitForRestore() async { await restoreTask?.value }

    func connect(key: String) async -> Bool {
        guard !state.preparing, state.connection != .connecting else { return false }
        let previous = state.connection
        state.connection = .connecting
        state.notice = ""
        do {
            let connected = try await gateway.connect(key: key)
            guard !closed else { await gateway.close(); return false }
            invalidateSearch()
            if !accountID.isEmpty, accountID != connected.accountID {
                for index in state.clips.indices { state.clips[index].uploaded = false }
                state.pendingJobID = ""
                state.events = []
            }
            accountID = connected.accountID
            state.indexVersion = connected.indexVersion
            state.connection = connected.indexVersion == nil ? .connected : .ready
            record(
                "Connected",
                connected.indexVersion.map { "Authenticated · street index v\($0) available" }
                    ?? "Authenticated. No street index yet."
            )
            await saveOptional()
            return true
        } catch {
            state.connection = previous == .connecting ? .disconnected : previous
            state.notice = "Authentication failed. Check your API key and beta access."
            record("Connection failed", state.notice, isError: true)
            return false
        }
    }

    func disconnect() async {
        guard !state.preparing, state.connection != .connecting else { return }
        invalidateSearch()
        await gateway.close()
        state.connection = .disconnected
        state.indexVersion = nil
        state.notice = "Disconnected. Recordings remain on this device."
    }

    func importMovie(_ url: URL) async {
        guard !state.preparing else { return }
        do {
            let clip = try await store.importMovie(url)
            state.clips.append(clip)
            invalidateSearch()
            await saveOptional()
            record("Recording added", "\(clip.title) · stored on device only")
        } catch {
            state.notice = "Choose a playable MP4 smaller than 100 MB."
            record("Import failed", state.notice, isError: true)
        }
    }

    func localURL(for clip: ArchiveClip) async throws -> URL {
        let url = try await store.localURL(for: clip)
        if let index = state.clips.firstIndex(where: { $0.id == clip.id }),
           state.clips[index].localRelativePath == nil,
           let relative = await store.relativePath(for: url)
        {
            state.clips[index].localRelativePath = relative
            await saveOptional()
        }
        return url
    }

    func startPreparation() {
        guard state.connected, !state.preparing, preparationTask == nil else { return }
        preparationTask = Task { await prepare() }
    }

    func stopPreparation() {
        preparationTask?.cancel()
        activeUpload?.cancel()
        let token = workToken
        Task { await token?.cancel() }
    }

    func updateQuery(_ value: String) {
        guard value != state.query else { return }
        state.query = value
        invalidateSearch()
    }

    func updateLooserMatches(_ value: Bool) {
        guard value != state.looserMatches else { return }
        state.looserMatches = value
        invalidateSearch()
    }

    func submitSearch(_ query: String? = nil) {
        if let query { state.query = query }
        let clean = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard state.ready, !state.preparing, !clean.isEmpty else { return }
        invalidateSearch()
        let generation = searchGeneration
        let token = CancellationToken()
        searchToken = token
        state.searching = true
        state.notice = ""
        let cutoff = state.looserMatches ? 1.5 : 0.85
        searchTask = Task {
            do {
                let value = try await gateway.search(
                    query: clean, maxDistance: cutoff, generation: generation, cancellation: token
                )
                guard !Task.isCancelled, generation == searchGeneration, !closed else { return }
                state.batch = value
                record(
                    "Search complete",
                    "“\(clean)” · \(value.matches.count) returned · \(value.roundTripMilliseconds) ms request · \(Int(value.serverMilliseconds)) ms server"
                )
            } catch is CancellationError {
                // A newer search generation owns the screen.
            } catch is OperationCanceledError {
                // A newer search generation owns the screen.
            } catch {
                guard generation == searchGeneration else { return }
                state.notice = framebaseSafeError(error)
                record("Search failed", state.notice, isError: true)
            }
            if generation == searchGeneration { state.searching = false }
        }
    }

    func cancelSearch() { invalidateSearch() }

    func showNotice(_ value: String) { state.notice = value }

    func shutdown() async {
        guard !closed else { return }
        closed = true
        invalidateSearch()
        let activePreparation = preparationTask
        stopPreparation()
        await activePreparation?.value
        await gateway.close()
    }

    private func restore() async {
        let loaded = await store.load()
        state.clips = loaded.snapshot.clips
        state.pendingJobID = loaded.snapshot.pendingJobID
        state.events = loaded.snapshot.events
        state.notice = loaded.notice ?? ""
        accountID = loaded.snapshot.accountID
        state.initialized = true
    }

    private func prepare() async {
        guard !state.preparing else { return }
        state.preparing = true
        state.notice = ""
        invalidateSearch()
        let token = CancellationToken()
        workToken = token
        do {
            if state.pendingJobID.isEmpty {
                try await uploadPending(token)
                try await token.throwIfCanceled()
                state.phase = "Creating visual index"
                state.progress = nil
                state.pendingJobID = try await gateway.createIndex(cancellation: token)
                await saveOptional()
                record("Index queued", "Visual index · \(state.clips.count) recordings")
            }
            try await pollIndex(token)
        } catch is CancellationError {
            stoppedNotice()
        } catch is OperationCanceledError {
            stoppedNotice()
        } catch {
            state.notice = framebaseSafeError(error)
            record("Processing failed", state.notice, isError: true)
        }
        state.preparing = false
        state.phase = ""
        state.progress = nil
        workToken = nil
        activeUpload = nil
        preparationTask = nil
    }

    private func uploadPending(_ token: CancellationToken) async throws {
        for index in state.clips.indices where !state.clips[index].uploaded {
            try Task.checkCancellation()
            try await token.throwIfCanceled()
            let clip = state.clips[index]
            state.phase = "Uploading \(clip.title)"
            state.progress = 0
            let file = try await localURL(for: clip)
            let handle = try await gateway.upload(file: file, remoteFilename: clip.remoteFilename)
            activeUpload = handle
            let progressTask = Task { @MainActor [weak self] in
                for await item in handle.progress {
                    self?.state.progress = item.totalBytes > 0
                        ? Double(item.uploadedBytes) / Double(item.totalBytes) : nil
                }
            }
            let started = Date()
            defer { progressTask.cancel(); activeUpload = nil }
            guard try await handle.result() else { throw ValidationError("Upload did not complete") }
            state.clips[index].uploaded = true
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            record(
                "Uploaded",
                String(format: "%@ · %.1f MB · %.1f s", clip.title, Double(size) / 1_048_576, Date().timeIntervalSince(started))
            )
            await saveOptional()
        }
    }

    private func pollIndex(_ token: CancellationToken) async throws {
        let started = Date()
        for _ in 0 ..< 120 {
            try Task.checkCancellation()
            try await token.throwIfCanceled()
            let status = try await gateway.indexStatus(jobID: state.pendingJobID, cancellation: token)
            if framebaseIndexDone(status) {
                let version = try await gateway.refreshVersion()
                state.indexVersion = version
                state.connection = version == nil ? .connected : .ready
                state.pendingJobID = ""
                await saveOptional()
                state.notice = "Visual index is ready. Search the street archive."
                record(
                    "Index ready",
                    "v\(version.map(String.init) ?? "—") · \(String(format: "%.1f", Date().timeIntervalSince(started))) s waiting time"
                )
                return
            }
            if framebaseIndexFailed(status) {
                state.pendingJobID = ""
                await saveOptional()
                throw ValidationError("Server index job failed")
            }
            state.phase = "Index \(status) · \(Int(Date().timeIntervalSince(started)))s"
            state.progress = nil
            try await delay(.seconds(4))
        }
        state.notice = "Still processing. Use Resume to check the server job again."
    }

    private func stoppedNotice() {
        if state.pendingJobID.isEmpty {
            state.notice = "Upload canceled. Completed uploads are kept."
        } else {
            state.notice = "Stopped waiting. Indexing continues on the server; use Resume."
        }
        record("Operation stopped", state.notice)
    }

    private func invalidateSearch() {
        searchGeneration += 1
        searchTask?.cancel()
        searchTask = nil
        let token = searchToken
        searchToken = nil
        Task { await token?.cancel() }
        state.searching = false
        state.batch = nil
    }

    private func record(_ title: String, _ detail: String, isError: Bool = false) {
        state.events.insert(ArchiveEvent(title: title, detail: detail, isError: isError, time: Date()), at: 0)
        state.events = Array(state.events.prefix(40))
        Task { await saveOptional() }
    }

    private func saveOptional() async {
        let snapshot = ArchiveSnapshot(
            clips: state.clips, pendingJobID: state.pendingJobID,
            accountID: accountID, events: state.events
        )
        try? await store.save(snapshot)
    }
}
