import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: FramebaseSession
    @State private var showSettings = false
    @State private var showDetails = false
    @State private var expanded: Set<String> = []
    @State private var playback: PlaybackRequest?

    private let suggestions = [
        "People crossing the street",
        "A bus on a city street",
        "Cars at an intersection",
    ]

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    searchBar
                    content(columns: geometry.size.width >= 600 ? 3 : 2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .background(FramebaseTheme.paper.ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showSettings) { ConnectionView() }
        .sheet(isPresented: $showDetails) { SearchDetailsView() }
        .sheet(item: $playback) { PlaybackView(request: $0) }
        .preferredColorScheme(.light)
    }

    private var searchBar: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: { Image(systemName: "arrow.left") }
                .accessibilityIdentifier("search.back")
                .accessibilityLabel("Back to library")
            TextField("Describe a moment", text: Binding(
                get: { session.state.query }, set: { session.updateQuery($0) }
            ))
            .font(.framebaseBody(19))
            .submitLabel(.search)
            .onSubmit { submit() }
            .accessibilityIdentifier("search.query")
            Button {
                session.state.searching ? session.cancelSearch() : submit()
            } label: {
                Image(systemName: session.state.searching ? "xmark" : "magnifyingglass")
            }
            .accessibilityIdentifier("search.submit")
            .accessibilityLabel(session.state.searching ? "Cancel search" : "Search")
            Menu {
                Toggle("Include looser matches", isOn: Binding(
                    get: { session.state.looserMatches }, set: { session.updateLooserMatches($0) }
                ))
                Button("Search details") { showDetails = true }
                    .disabled(session.state.batch == nil)
            } label: { Image(systemName: "ellipsis.vertical") }
            .accessibilityIdentifier("search.menu")
        }
        .font(.title2)
        .foregroundStyle(FramebaseTheme.ink)
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(FramebaseTheme.field, in: RoundedRectangle(cornerRadius: 26))
    }

    @ViewBuilder
    private func content(columns: Int) -> some View {
        if session.state.searching {
            ProgressView("Searching moments…").frame(maxWidth: .infinity).padding(.top, 60)
        } else if let batch = session.state.batch {
            if batch.matches.isEmpty {
                VStack(spacing: 12) {
                    Text("No matching moments").font(.framebaseTitle(26))
                    Text("Try a different description.").foregroundStyle(FramebaseTheme.secondary)
                    if !session.state.looserMatches {
                        Button("Include looser matches") {
                            session.updateLooserMatches(true)
                            session.submitSearch()
                        }
                    }
                }.frame(maxWidth: .infinity).padding(.top, 60)
            } else {
                Text("\(session.groupedMatches.count) videos")
                    .font(.framebaseBody(20)).foregroundStyle(FramebaseTheme.secondary)
                ForEach(session.groupedMatches) { group in matchGroup(group, columns: columns) }
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text("Search the street archive").font(.framebaseTitle(28))
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        session.updateQuery(suggestion)
                        submit()
                    }
                    .font(.framebaseBody(18))
                    .foregroundStyle(FramebaseTheme.rust)
                    .accessibilityIdentifier("search.suggestion.\(suggestion)")
                }
                if !session.state.notice.isEmpty {
                    Text(session.state.notice).foregroundStyle(FramebaseTheme.secondary)
                }
            }.padding(.top, 20)
        }
    }

    private func matchGroup(_ group: MatchGroup, columns: Int) -> some View {
        let clip = framebaseClip(group.filename, in: session.state.clips)
        let shown = expanded.contains(group.id) ? group.matches : Array(group.matches.prefix(2))
        return VStack(alignment: .leading, spacing: 14) {
            Text(clip?.title ?? group.filename).font(.framebaseTitle(26))
            Text(clip?.city ?? "Not stored on this device")
                .font(.framebaseBody(18)).foregroundStyle(FramebaseTheme.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: columns), spacing: 14) {
                ForEach(shown) { match in
                    Button { open(match, group: group, clip: clip) } label: {
                        FrameImage(match: match)
                            .aspectRatio(1.65, contentMode: .fit)
                            .overlay(alignment: .bottomTrailing) {
                                Text(framebaseTimeLabel(match.seconds ?? 0)).framebaseBadge()
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("search.match.\(match.id)")
                    .accessibilityLabel("Open \(clip?.title ?? group.filename) at \(framebaseTimeLabel(match.seconds ?? 0))")
                }
            }
            if group.matches.count > 2 {
                Button(expanded.contains(group.id) ? "Show fewer moments" : "Show \(group.matches.count - 2) more moments") {
                    if expanded.contains(group.id) { expanded.remove(group.id) } else { expanded.insert(group.id) }
                }
                .font(.framebaseBody(17)).foregroundStyle(FramebaseTheme.rust)
            }
        }
    }

    private func submit() {
        guard session.state.connected else { showSettings = true; return }
        guard session.state.ready else { session.startPreparation(); return }
        session.submitSearch()
    }

    private func open(_ match: FrameMatch, group: MatchGroup, clip: ArchiveClip?) {
        guard let clip else {
            session.showNotice("This recording is not stored on this device.")
            return
        }
        playback = PlaybackRequest(clip: clip, moments: group.matches, initialSeconds: match.seconds)
    }
}

struct SearchDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: FramebaseSession

    var body: some View {
        NavigationStack {
            List {
                if let batch = session.state.batch {
                    detail("Server results", "\(batch.total)")
                    detail("Accepted moments", "\(batch.matches.count)")
                    detail("Request time", "\(batch.roundTripMilliseconds) ms")
                    detail("Server execution", "\(Int(batch.serverMilliseconds)) ms")
                    detail("Frame retrieval", "\(batch.imageMilliseconds) ms")
                    Section {
                        Text("Distance is similarity distance. Nearby moments within one recording are grouped without changing relevance order.")
                    }
                }
            }
            .navigationTitle("Search details")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).foregroundStyle(FramebaseTheme.secondary) }
    }
}
