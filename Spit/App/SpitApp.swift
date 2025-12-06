import SwiftUI
import SwiftData

@main
struct SpitApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var shouldStartRecording = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Memo.self,
            ThreadItem.self
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
            Group {
                if hasCompletedOnboarding {
                    HomeView(shouldStartRecording: $shouldStartRecording)
                } else {
                    OnboardingView()
                }
            }
            .onOpenURL { url in
                handleURL(url)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "spit" else { return }

        switch url.host {
        case "record":
            shouldStartRecording = true
        default:
            break
        }
    }
}
