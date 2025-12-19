import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = EditorViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        EditorView(content: $viewModel.content, hasUnsavedChanges: $viewModel.hasUnsavedChanges)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        viewModel.addNewEntry()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("New Entry (⌘N)")

                    if viewModel.hasUnsavedChanges {
                        Circle()
                            .fill(.orange)
                            .frame(width: 8, height: 8)
                            .help("Unsaved changes")
                    }
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
