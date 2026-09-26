import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var session: FramebaseSession
    @State private var showImporter = false
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var showHistory = false
    @State private var confirmPrepare = false
    @State private var playback: PlaybackRequest?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Street footage").font(.framebaseTitle(28))
                        Spacer()
                        Text("\(session.state.clips.count) videos")
                            .font(.framebaseBody(20)).foregroundStyle(FramebaseTheme.secondary)
                    }
                    ForEach(session.state.clips) { clip in clipCard(clip) }
                    if session.state.preparing { preparationStatus }
                    if !session.state.notice.isEmpty {
                        Text(session.state.notice).font(.framebaseBody(15)).foregroundStyle(FramebaseTheme.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
            .background(FramebaseTheme.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 10) {
                        FramebaseMark()
                        Text("Framebase").font(.framebaseTitle(27)).foregroundStyle(FramebaseTheme.ink)
                    }
                }
                ToolbarItemGroup(placement: .automatic) {
                    Button { showImporter = true } label: { Image(systemName: "plus") }
                        .accessibilityIdentifier("library.add")
                        .accessibilityLabel("Add recording")
                    Menu {
                        Button("Search settings") { showSettings = true }
                        Button(session.state.ready && session.state.hasPendingUploads ? "Prepare added videos" : "Prepare videos for search") {
                            prepareTapped()
                        }
                        Button("Sync history") { showHistory = true }
                    } label: { Image(systemName: "ellipsis.vertical") }
                    .accessibilityIdentifier("library.menu")
                    .accessibilityLabel("Framebase menu")
                }
            }
            .safeAreaInset(edge: .bottom) { searchDock }
            .navigationDestination(isPresented: $showSearch) { SearchView() }
            .navigationDestination(isPresented: $showHistory) { HistoryView() }
        }
        .tint(FramebaseTheme.rust)
        .sheet(isPresented: $showSettings) { ConnectionView() }
        .sheet(item: $playback) { PlaybackView(request: $0) }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.mpeg4Movie]) { result in
            if case .success(let url) = result { Task { await session.importMovie(url) } }
        }
        .confirmationDialog("Prepare videos for search?", isPresented: $confirmPrepare) {
            Button("Prepare") { session.startPreparation() }
            Button("Cancel", role: .cancel) {}
        } message: {
            let count = session.state.clips.filter { !$0.uploaded }.count
            Text("Upload \(count) recording\(count == 1 ? "" : "s") and rebuild the visual index.")
        }
        .preferredColorScheme(.light)
    }

    private func clipCard(_ clip: ArchiveClip) -> some View {
        Button {
            playback = PlaybackRequest(clip: clip, moments: [], initialSeconds: 0)
        } label: {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let poster = clip.posterResource {
                        Image(poster).resizable().scaledToFill()
                    } else {
                        ZStack {
                            FramebaseTheme.field
                            Image(systemName: "film").font(.system(size: 44)).foregroundStyle(FramebaseTheme.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity).aspectRatio(1.8, contentMode: .fit).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 3) {
                    Text(clip.title).font(.framebaseTitle(25)).lineLimit(2)
                    Text(clip.city).font(.framebaseBody(17))
                }
                .foregroundStyle(.white).padding(18)
                HStack {
                    Spacer()
                    Image(systemName: "play.fill").font(.title2).foregroundStyle(.white)
                        .frame(width: 58, height: 58).background(.black.opacity(0.48), in: Circle())
                }.padding(16)
                VStack { HStack { Spacer(); Text(framebaseTimeLabel(clip.durationSeconds)).framebaseBadge() }; Spacer() }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("library.clip.\(clip.id)")
        .accessibilityLabel("Play \(clip.title), \(clip.city), \(framebaseTimeLabel(clip.durationSeconds))")
    }

    private var searchDock: some View {
        Button { showSearch = true } label: {
            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                Text("Search your videos").font(.framebaseTitle(20))
                Spacer()
                Image(systemName: "arrow.right").frame(width: 52, height: 52)
                    .background(FramebaseTheme.peach, in: RoundedRectangle(cornerRadius: 17))
                    .foregroundStyle(FramebaseTheme.ink)
            }
            .foregroundStyle(.white).padding(12)
            .background(FramebaseTheme.ink.opacity(0.96), in: RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 20).padding(.bottom, 8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("library.search")
        .accessibilityLabel("Search your videos")
    }

    private var preparationStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.state.phase).font(.framebaseTitle(18))
            if let value = session.state.progress { ProgressView(value: value) } else { ProgressView() }
            Button(session.state.pendingJobID.isEmpty ? "Cancel" : "Stop waiting", role: .cancel) {
                session.stopPreparation()
            }
            .accessibilityIdentifier("preparation.cancel")
        }.framebaseCard()
    }

    private func prepareTapped() {
        guard session.state.connected else { showSettings = true; return }
        if !session.state.pendingJobID.isEmpty { session.startPreparation() }
        else { confirmPrepare = true }
    }
}
