import Foundation
import VModalSDK

let framebaseCollection = "framebase_streets"
let framebaseStream = "street_study"

struct ArchiveClip: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let location: String
    let durationSeconds: Double
    let videoResource: String?
    let posterResource: String?
    var localRelativePath: String?
    var uploaded: Bool
    let bundled: Bool

    var remoteFilename: String { "\(id).mp4" }
    var city: String { location.components(separatedBy: " · ").first ?? location }
}

struct ArchiveEvent: Codable, Identifiable, Sendable, Equatable {
    let title: String
    let detail: String
    let isError: Bool
    let time: Date
    var id: String { "\(time.timeIntervalSince1970)-\(title)" }
}

struct FrameMatch: Identifiable, Sendable, Equatable {
    let id: String
    let raw: [String: JSONValue]
    let filename: String
    let timestamp: String
    let seconds: Double?
    let imageData: Data?
    let fallbackURL: URL?

    var distance: Double? { raw["score"]?.doubleValue }
}

struct SearchBatch: Sendable, Equatable {
    let matches: [FrameMatch]
    let total: Int
    let serverMilliseconds: Double
    let roundTripMilliseconds: Int
    let imageMilliseconds: Int
}

struct MatchGroup: Identifiable, Sendable, Equatable {
    let filename: String
    let matches: [FrameMatch]
    var id: String { filename.lowercased() }
}

enum ConnectionState: String, Sendable {
    case disconnected, connecting, connected, ready
}

struct FramebaseState: Sendable {
    var initialized = false
    var clips = framebaseDefaultClips()
    var events: [ArchiveEvent] = []
    var pendingJobID = ""
    var connection: ConnectionState = .disconnected
    var indexVersion: Int?
    var notice = ""
    var phase = ""
    var progress: Double?
    var preparing = false
    var searching = false
    var query = ""
    var looserMatches = false
    var batch: SearchBatch?

    var connected: Bool { connection == .connected || connection == .ready }
    var ready: Bool { connection == .ready && indexVersion != nil }
    var hasPendingUploads: Bool { clips.contains { !$0.uploaded } }
}

struct ArchiveSnapshot: Codable, Sendable, Equatable {
    var clips: [ArchiveClip]
    var pendingJobID: String
    var accountID: String
    var events: [ArchiveEvent]

    func bounded() -> ArchiveSnapshot {
        var copy = self
        copy.events = Array(events.prefix(40))
        return copy
    }
}

func framebaseDefaultClips() -> [ArchiveClip] {
    [
        ArchiveClip(
            id: "neighborhood_crossing", title: "Neighborhood crossing",
            location: "San Francisco · Daylight", durationSeconds: 55.2,
            videoResource: "neighborhood_crossing", posterResource: "neighborhood_crossing",
            localRelativePath: nil, uploaded: false, bundled: true
        ),
        ArchiveClip(
            id: "downtown_traffic", title: "Downtown traffic",
            location: "Singapore · Afternoon", durationSeconds: 15.8,
            videoResource: "downtown_traffic", posterResource: "downtown_traffic",
            localRelativePath: nil, uploaded: false, bundled: true
        ),
        ArchiveClip(
            id: "evening_junction", title: "Evening junction",
            location: "Mexico City · Dusk", durationSeconds: 75,
            videoResource: "evening_junction", posterResource: "evening_junction",
            localRelativePath: nil, uploaded: false, bundled: true
        ),
    ]
}

func framebaseTimeLabel(_ seconds: Double) -> String {
    let safe = seconds.isFinite ? min(max(Int(seconds), 0), 86_400) : 0
    return String(format: "%02d:%02d", safe / 60, safe % 60)
}

func framebaseFirstText(_ row: [String: JSONValue], _ fields: [String]) -> String {
    for field in fields {
        let text: String
        switch row[field] {
        case .string(let value): text = value
        case .int(let value): text = String(value)
        case .double(let value): text = String(value)
        default: text = ""
        }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { return clean }
    }
    return ""
}

func framebaseBasename(_ path: String) -> String {
    path.replacingOccurrences(of: "\\", with: "/").split(separator: "/").last.map(String.init) ?? ""
}

func framebaseFilename(_ row: [String: JSONValue]) -> String {
    let name = framebaseFirstText(row, [
        "filename", "filename_sanitized", "video_filename", "video", "source_path", "path", "title",
    ])
    if !name.isEmpty { return framebaseBasename(name) }
    var item = framebaseFirstText(row, ["item_id"])
    let stream = framebaseFirstText(row, ["stream", "stream_name"])
    let time = framebaseFirstText(row, ["ts_unix", "ts_unix_13digits"])
    if !stream.isEmpty, item.hasPrefix("\(stream)-") { item.removeFirst(stream.count + 1) }
    if !time.isEmpty, item.hasSuffix("-\(time)") { item.removeLast(time.count + 1) }
    return framebaseBasename(item)
}

func framebaseTimestamp13(_ row: [String: JSONValue]) -> String {
    let text = framebaseFirstText(row, ["ts_unix_13digits", "ts_unix", "timestamp_ms"])
    guard let number = Double(text), number.isFinite, number >= 0, number <= Double(Int64.max) else { return "" }
    let value = Int64(number)
    let digits = String(value)
    if digits.count >= 13 { return String(digits.prefix(13)) }
    if digits.count == 10 { return String(value * 1_000) }
    return String(repeating: "0", count: 13 - digits.count) + digits
}

func framebaseSeconds(_ row: [String: JSONValue]) -> Double? {
    for field in [
        "video_time_seconds", "timestamp_seconds", "time_seconds", "start_seconds",
        "offset_seconds", "seconds", "time_sec",
    ] {
        if let value = row[field]?.doubleValue, value.isFinite, value >= 0 { return value }
    }
    let text = framebaseFirstText(row, ["ts_unix_13digits", "ts_unix", "timestamp_ms"])
    guard let value = Double(text), value.isFinite, value >= 0, value < 86_400_000 else { return nil }
    return value / 1_000
}

func framebaseIndexDone(_ value: String) -> Bool {
    ["success", "succeeded", "done", "completed", "ok"].contains(value.lowercased())
}

func framebaseIndexFailed(_ value: String) -> Bool {
    ["failed", "failure", "error", "cancelled", "canceled"].contains(value.lowercased())
}

func framebaseClip(_ filename: String, in clips: [ArchiveClip]) -> ArchiveClip? {
    let clean = framebaseBasename(filename).lowercased()
    return clips.first {
        clean == $0.id.lowercased() || clean == $0.remoteFilename.lowercased()
            || clean.hasPrefix("\($0.id.lowercased()).")
    }
}

func framebaseGroups(_ matches: [FrameMatch]) -> [MatchGroup] {
    var order: [String] = []
    var values: [String: [FrameMatch]] = [:]
    for match in matches {
        let key = match.filename.lowercased()
        if values[key] == nil { order.append(key); values[key] = [] }
        let seconds = match.seconds
        let near = values[key, default: []].contains {
            guard let left = $0.seconds, let right = seconds else { return false }
            return abs(left - right) < 6
        }
        if !near { values[key, default: []].append(match) }
    }
    return order.map { MatchGroup(filename: values[$0]?.first?.filename ?? $0, matches: values[$0] ?? []) }
}

func framebaseSafeError(_ error: Error) -> String {
    if error is AuthenticationError || error is ValidationError {
        return "Authentication failed. Check your API key and beta access."
    }
    if error is CocoaError { return "The local video could not be read. Import it again." }
    return "The operation could not finish. Check the connection and try again."
}
