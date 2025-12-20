import SwiftUI

@main
struct DropsMacApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    NotificationCenter.default.post(name: .addNewNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .saveItem) {
                Button("Sync Now") {
                    Task {
                        await appState.sync()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?

    func sync() async {
        isSyncing = true
        defer { isSyncing = false }

        // TODO: Implement sync
        lastSyncTime = Date()
    }
}
