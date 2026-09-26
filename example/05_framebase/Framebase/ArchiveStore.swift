@preconcurrency import AVFoundation
import Foundation

struct ArchiveLoad: Sendable {
    let snapshot: ArchiveSnapshot
    let notice: String?
}

actor ArchiveStore {
    private let files = FileManager.default
    private let root: URL
    private let bundle: Bundle

    init(root: URL? = nil, bundle: Bundle = .main) {
        self.bundle = bundle
        if let root {
            self.root = root
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.root = support.appendingPathComponent("Framebase", isDirectory: true)
        }
    }

    func load() -> ArchiveLoad {
        do {
            try ensureRoot()
            let data = try Data(contentsOf: archiveURL)
            var value = try JSONDecoder.framebase.decode(ArchiveSnapshot.self, from: data).bounded()
            value.clips = value.clips.filter(validClip)
            if value.clips.isEmpty {
                value.clips = framebaseDefaultClips()
                return ArchiveLoad(snapshot: value, notice: restoreNotice)
            }
            return ArchiveLoad(snapshot: value, notice: nil)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return ArchiveLoad(snapshot: defaults, notice: nil)
        } catch {
            return ArchiveLoad(snapshot: defaults, notice: restoreNotice)
        }
    }

    func save(_ snapshot: ArchiveSnapshot) throws {
        try ensureRoot()
        let data = try JSONEncoder.framebase.encode(snapshot.bounded())
        let temp = root.appendingPathComponent(".archive.\(UUID().uuidString).tmp")
        do {
            try data.write(to: temp, options: [.atomic])
            if files.fileExists(atPath: archiveURL.path) {
                _ = try files.replaceItemAt(archiveURL, withItemAt: temp)
            } else {
                try files.moveItem(at: temp, to: archiveURL)
            }
        } catch {
            try? files.removeItem(at: temp)
            throw error
        }
    }

    func localURL(for clip: ArchiveClip) throws -> URL {
        if let relative = cleanRelative(clip.localRelativePath) {
            let url = root.appendingPathComponent(relative)
            if files.fileExists(atPath: url.path) { return url }
            if !clip.bundled { throw CocoaError(.fileReadNoSuchFile) }
        }
        guard clip.bundled, let name = clip.videoResource,
              let source = bundle.url(forResource: name, withExtension: "mp4")
        else { throw CocoaError(.fileReadNoSuchFile) }
        try ensureRoot()
        let relative = "Media/\(clip.remoteFilename)"
        let destination = root.appendingPathComponent(relative)
        try files.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !files.fileExists(atPath: destination.path) { try files.copyItem(at: source, to: destination) }
        return destination
    }

    func relativePath(for url: URL) -> String? {
        let base = root.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(base) else { return nil }
        return cleanRelative(String(path.dropFirst(base.count)))
    }

    func importMovie(_ source: URL, now: Date = Date()) async throws -> ArchiveClip {
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .nameKey])
        guard source.pathExtension.lowercased() == "mp4", values.isRegularFile == true,
              let size = values.fileSize, size > 0, size <= 100 * 1_024 * 1_024
        else { throw ArchiveImportError.invalidMovie }
        let asset = AVURLAsset(url: source)
        let playable = try await asset.load(.isPlayable)
        let duration = try await asset.load(.duration).seconds
        guard playable, duration.isFinite, duration > 0 else { throw ArchiveImportError.invalidMovie }
        try ensureRoot()
        let id = "street_\(Int64((now.timeIntervalSince1970 * 1_000).rounded()))"
        let relative = "Media/\(id).mp4"
        let destination = root.appendingPathComponent(relative)
        try files.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try files.copyItem(at: source, to: destination)
        return ArchiveClip(
            id: id, title: values.name ?? source.lastPathComponent, location: "Imported recording",
            durationSeconds: duration, videoResource: nil, posterResource: nil,
            localRelativePath: relative, uploaded: false, bundled: false
        )
    }

    private var defaults: ArchiveSnapshot {
        ArchiveSnapshot(clips: framebaseDefaultClips(), pendingJobID: "", accountID: "", events: [])
    }

    private var archiveURL: URL { root.appendingPathComponent("archive.json") }
    private var restoreNotice: String { "Local archive could not be restored. Built-in clips are available." }

    private func ensureRoot() throws {
        try files.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private func validClip(_ clip: ArchiveClip) -> Bool {
        guard !clip.id.isEmpty, clip.durationSeconds.isFinite, clip.durationSeconds >= 0 else { return false }
        if clip.bundled { return true }
        guard let relative = cleanRelative(clip.localRelativePath) else { return false }
        return files.fileExists(atPath: root.appendingPathComponent(relative).path)
    }

    private func cleanRelative(_ value: String?) -> String? {
        guard let value, !value.isEmpty, !value.hasPrefix("/"), !value.contains("..") else { return nil }
        return value
    }
}

enum ArchiveImportError: Error { case invalidMovie }

private extension JSONEncoder {
    static var framebase: JSONEncoder {
        let value = JSONEncoder()
        value.dateEncodingStrategy = .iso8601
        value.outputFormatting = [.prettyPrinted, .sortedKeys]
        return value
    }
}

private extension JSONDecoder {
    static var framebase: JSONDecoder {
        let value = JSONDecoder()
        value.dateDecodingStrategy = .iso8601
        return value
    }
}
