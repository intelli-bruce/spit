import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = EditorViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        EditorView(
            content: $viewModel.content,
            hasUnsavedChanges: $viewModel.hasUnsavedChanges,
            filePath: Config.journalFilePath,
            onSave: {
                Task {
                    await viewModel.saveContent()
                }
            }
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.addNewEntry()
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Entry (⌘N)")
            }
        }
        .task {
            await viewModel.loadContent()
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error ?? "")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
