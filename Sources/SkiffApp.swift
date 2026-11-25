import SwiftUI

@main
struct SkiffApp: App {
    @StateObject private var store = TabStore()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            BrowserView(tab: store.current)
                .id(store.current.id)
                .environmentObject(store)
        }
        .onChange(of: phase) { if $0 != .active { store.save() } }
    }
}
