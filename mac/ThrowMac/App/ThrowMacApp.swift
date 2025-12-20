import SwiftUI
import SwiftData

@main
struct ThrowMacApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Note.self,
            NoteBlock.self,
            Tag.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    NotificationCenter.default.post(name: .addNewNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    NotificationCenter.default.post(name: .saveNote, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Sync Now") {
                    NotificationCenter.default.post(name: .syncNow, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    NotificationCenter.default.post(name: .refreshNotes, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let addNewNote = Notification.Name("addNewNote")
    static let saveNote = Notification.Name("saveNote")
    static let syncNow = Notification.Name("syncNow")
    static let refreshNotes = Notification.Name("refreshNotes")
}
