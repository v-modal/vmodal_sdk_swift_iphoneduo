import SwiftUI

@main
struct FramebaseApp: App {
    @StateObject private var session = FramebaseSession()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(session)
                .tint(FramebaseTheme.rust)
                .preferredColorScheme(.light)
        }
    }
}
