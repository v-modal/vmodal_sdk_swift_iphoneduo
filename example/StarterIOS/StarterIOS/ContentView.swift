import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showImporter = false

    var body: some View {
        NavigationSplitView {
            Form {
                Section("Authentication") {
                    SecureField("Bearer token", text: $session.token)
                        .textContentType(.password)
                    TextField("Project", text: $session.projectID)
                    Button("Connect") { Task { await session.connect() } }
                    Button("Rotate credential") { Task { await session.rotateKey() } }
                }
                Section("Collections") {
                    ForEach(session.collections, id: \.self) { name in
                        Button(name) { session.collection = name }
                    }
                }
            }
            .navigationTitle("VModal")
        } detail: {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                    GroupBox("Scope") {
                        TextField("Collection", text: $session.collection)
                        TextField("Stream", text: $session.stream)
                        Button("List index jobs") { Task { await session.listJobs() } }
                        Text("Jobs: \(session.jobCount)")
                    }
                    GroupBox("Search") {
                        TextField("Query", text: $session.query)
                        HStack {
                            Button("Search") { Task { await session.search() } }
                            Button("Cancel", role: .cancel) { session.cancelSearch() }
                        }
                        Text("Results: \(session.resultCount)")
                    }
                    GroupBox("Upload") {
                        ProgressView(value: Double(session.uploadPercent), total: 100)
                        HStack {
                            Button("Choose video") { showImporter = true }
                            Button("Cancel", role: .cancel) { session.cancelUpload() }
                        }
                    }
                        Text(session.message)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("SDK status: \(session.message)")
                        Text(horizontalSizeClass == .compact ? "Compact layout" : "Expanded layout")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: min(geometry.size.width, 720), alignment: .leading)
                    .padding()
                }
            }
            .navigationTitle(session.collection.isEmpty ? "Workspace" : session.collection)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.movie]) { result in
            if case .success(let url) = result { session.upload(url) }
        }
    }
}
