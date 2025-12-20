import SwiftUI

struct JournalListView: View {
    @StateObject private var coordinator = JournalCoordinator()
    @State private var editContent: String = ""

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(coordinator.dayGroups) { dayGroup in
                        DaySectionView(
                            dayGroup: dayGroup,
                            selectedNoteId: coordinator.selectedNoteId,
                            editingNoteId: coordinator.appMode == .editing ? coordinator.selectedNoteId : nil,
                            vimEngine: coordinator.vimEngine,
                            editContent: $editContent
                        )
                    }
                }
                .padding(24)
            }
            .onChange(of: coordinator.selectedNoteId) { _, newId in
                if let id = newId {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay {
            if coordinator.isLoading {
                ProgressView()
            } else if coordinator.dayGroups.isEmpty {
                emptyState
            }
        }
        .overlay(alignment: .bottom) {
            statusBar
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        await coordinator.addNote()
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("New Note (⌘N)")
            }
        }
        .task {
            await coordinator.loadNotes()
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewNote)) { _ in
            Task {
                await coordinator.addNote()
            }
        }
        .onChange(of: coordinator.appMode) { oldMode, newMode in
            if oldMode == .editing && newMode == .browsing {
                // Save content when exiting edit mode
                if let note = coordinator.allNotes.first(where: { $0.id == coordinator.selectedNoteId }) {
                    Task {
                        await coordinator.updateNote(note, newContent: editContent)
                    }
                }
            } else if newMode == .editing {
                // Load content when entering edit mode
                if let note = coordinator.allNotes.first(where: { $0.id == coordinator.selectedNoteId }) {
                    editContent = note.content
                }
            }
        }
        .alert("Error", isPresented: .constant(coordinator.error != nil)) {
            Button("OK") {
                coordinator.error = nil
            }
        } message: {
            Text(coordinator.error ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No notes yet")
                .foregroundStyle(.secondary)
            Text("Press ⌘N to drop one")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var statusBar: some View {
        HStack {
            // Mode indicator
            Text(coordinator.appMode == .editing ? "EDITING" : "BROWSING")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(coordinator.appMode == .editing ? .green : .blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((coordinator.appMode == .editing ? Color.green : Color.blue).opacity(0.15))
                .cornerRadius(4)

            if coordinator.appMode == .editing {
                Text("ESC: normal → ESC: exit")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Text("j/k: navigate • Enter: edit • ⌘N: new")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(coordinator.allNotes.count) notes")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let addNewNote = Notification.Name("addNewNote")
}

#Preview {
    JournalListView()
        .frame(width: 600, height: 800)
}
