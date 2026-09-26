import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var session: FramebaseSession

    var body: some View {
        List {
            if session.state.preparing {
                Section("Active work") {
                    Label(session.state.phase, systemImage: "arrow.triangle.2.circlepath")
                }
            }
            if session.state.events.isEmpty {
                Text("No uploads or searches yet.").foregroundStyle(FramebaseTheme.secondary)
            } else {
                ForEach(session.state.events) { event in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: event.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(event.isError ? .red : FramebaseTheme.rust)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title).font(.framebaseTitle(17))
                            Text(event.detail).font(.framebaseBody(14)).foregroundStyle(FramebaseTheme.secondary)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(FramebaseTheme.paper)
        .navigationTitle("Sync history")
    }
}
