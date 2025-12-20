import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        JournalListView()
            .alert("Error", isPresented: .constant(appState.syncError != nil)) {
                Button("OK") {
                    appState.syncError = nil
                }
            } message: {
                Text(appState.syncError ?? "")
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
