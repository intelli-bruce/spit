import SwiftUI

@main
struct JournalMacApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Entry") {
                    appState.addNewEntry()
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

    private let editorViewModel = EditorViewModel()

    func addNewEntry() {
        editorViewModel.addNewEntry()
    }

    func sync() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await editorViewModel.syncWithSupabase()
            lastSyncTime = Date()
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }
}
