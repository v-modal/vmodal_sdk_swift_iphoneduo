import SwiftUI

struct ConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: FramebaseSession
    @State private var key = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(session.state.connected
                        ? "Framebase is connected. Your API key stays only in memory for this session."
                        : "Connect to prepare and search the fixed Framebase street archive.")
                        .font(.framebaseBody(17))
                    if !session.state.connected {
                        SecureField("API key", text: $key)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("settings.apiKey")
                    }
                    if session.state.connected {
                        Button("Disconnect", role: .destructive) {
                            Task { await session.disconnect(); dismiss() }
                        }
                        .accessibilityIdentifier("settings.disconnect")
                    } else {
                        Button(session.state.connection == .connecting ? "Connecting…" : "Connect") {
                            let submitted = key
                            key = ""
                            Task { if await session.connect(key: submitted) { dismiss() } }
                        }
                        .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.state.connection == .connecting)
                        .accessibilityIdentifier("settings.connect")
                    }
                    if !session.state.notice.isEmpty {
                        Text(session.state.notice).foregroundStyle(FramebaseTheme.secondary)
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(24)
            }
            .background(FramebaseTheme.paper.ignoresSafeArea())
            .navigationTitle("Search settings")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .interactiveDismissDisabled(session.state.connection == .connecting)
        .preferredColorScheme(.light)
    }
}
