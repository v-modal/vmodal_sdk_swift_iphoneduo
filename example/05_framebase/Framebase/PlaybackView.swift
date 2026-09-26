@preconcurrency import AVFoundation
import AVKit
import SwiftUI

struct PlaybackRequest: Identifiable, Equatable {
    let clip: ArchiveClip
    let moments: [FrameMatch]
    let initialSeconds: Double?
    var id: String { clip.id }
}

@MainActor
final class PlaybackSession: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var current = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var ready = false
    @Published private(set) var playing = false
    @Published private(set) var error: String?
    private var observer: Any?
    private var timeSink: PlaybackTimeSink?

    func open(url: URL, initialSeconds: Double?) async {
        close()
        let asset = AVURLAsset(url: url)
        do {
            let playable = try await asset.load(.isPlayable)
            let seconds = try await asset.load(.duration).seconds
            guard playable, seconds.isFinite, seconds > 0 else { throw CocoaError(.fileReadCorruptFile) }
            let value = AVPlayer(playerItem: AVPlayerItem(asset: asset))
            player = value
            duration = seconds
            if let initialSeconds, initialSeconds.isFinite, initialSeconds >= 0, initialSeconds <= seconds {
                await value.seek(to: CMTime(seconds: initialSeconds, preferredTimescale: 600))
                current = initialSeconds
            }
            let sink = PlaybackTimeSink { [weak self] seconds in self?.current = seconds }
            timeSink = sink
            observer = value.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main
            ) { time in
                sink.receive(time.seconds)
            }
            ready = true
        } catch {
            self.error = "This video could not be opened."
        }
    }

    func toggle() {
        guard let player else { return }
        if playing { player.pause() } else { player.play() }
        playing.toggle()
    }

    func seek(_ seconds: Double) {
        guard seconds.isFinite, seconds >= 0, seconds <= duration else { return }
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        current = seconds
    }

    func fail() {
        close()
        error = "This video could not be opened."
    }

    func close() {
        if let observer, let player { player.removeTimeObserver(observer) }
        observer = nil
        timeSink = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        current = 0
        duration = 0
        ready = false
        playing = false
        error = nil
    }
}

private final class PlaybackTimeSink: @unchecked Sendable {
    private let update: @MainActor @Sendable (Double) -> Void

    init(update: @escaping @MainActor @Sendable (Double) -> Void) { self.update = update }

    func receive(_ value: Double) {
        let safe = max(0, value.isFinite ? value : 0)
        Task { @MainActor in update(safe) }
    }
}

struct PlaybackView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var archive: FramebaseSession
    let request: PlaybackRequest
    @StateObject private var playback = PlaybackSession()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(request.clip.title).font(.framebaseTitle(30))
                    Text(request.clip.city).font(.framebaseBody(18)).foregroundStyle(FramebaseTheme.secondary)
                    player
                    if !request.moments.isEmpty { moments }
                }
                .padding(24)
            }
            .background(FramebaseTheme.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityIdentifier("playback.close")
                        .accessibilityLabel("Close playback")
                }
            }
        }
        .task {
            do {
                let url = try await archive.localURL(for: request.clip)
                await playback.open(url: url, initialSeconds: request.initialSeconds)
            } catch {
                playback.fail()
            }
        }
        .onDisappear { playback.close() }
        .preferredColorScheme(.light)
    }

    private var player: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 20).fill(Color.black)
            if let value = playback.player { VideoPlayer(player: value) }
            if !playback.ready {
                ProgressView(playback.error ?? "Loading video…").tint(.white).foregroundStyle(.white)
            }
            if playback.ready {
                HStack(spacing: 12) {
                    Button { playback.toggle() } label: {
                        Image(systemName: playback.playing ? "pause.fill" : "play.fill")
                    }
                    .accessibilityIdentifier("playback.toggle")
                    Slider(
                        value: Binding(get: { playback.current }, set: { playback.seek($0) }),
                        in: 0 ... max(playback.duration, 0.01)
                    ).tint(FramebaseTheme.peach)
                    Text("\(framebaseTimeLabel(playback.current)) / \(framebaseTimeLabel(playback.duration))")
                        .font(.framebaseBody(14)).monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding()
                .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                .padding(12)
            }
        }
        .frame(minHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var moments: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other moments").font(.framebaseTitle(20)).foregroundStyle(FramebaseTheme.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(request.moments) { match in
                        Button { if let seconds = match.seconds { playback.seek(seconds) } } label: {
                            FrameImage(match: match)
                                .frame(width: 180, height: 105)
                                .overlay(alignment: .bottomTrailing) {
                                    Text(framebaseTimeLabel(match.seconds ?? 0)).framebaseBadge()
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(active(match) ? FramebaseTheme.rust : .clear, lineWidth: 3)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("playback.moment.\(match.id)")
                    }
                }
            }
        }
    }

    private func active(_ match: FrameMatch) -> Bool {
        guard let seconds = match.seconds else { return false }
        return abs(playback.current - seconds) <= 3
    }
}
