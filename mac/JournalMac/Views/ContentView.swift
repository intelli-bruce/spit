import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = EditorViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView(entries: viewModel.entries, selectedEntry: $viewModel.selectedEntry)
        } detail: {
            EditorView(content: $viewModel.content, hasUnsavedChanges: $viewModel.hasUnsavedChanges)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.addNewEntry()
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Entry (⌘N)")

                Spacer()

                if viewModel.isSyncing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button {
                        Task {
                            await viewModel.syncWithSupabase()
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .help("Sync (⇧⌘S)")
                }

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
            await viewModel.setupRealtime()
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
