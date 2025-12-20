import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = EditorViewModel()
    @State private var selectedNoteId: UUID?
    @State private var isEditing = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.filteredNotes) { note in
                        NoteFeedCard(
                            note: note,
                            viewModel: viewModel,
                            isFocused: selectedNoteId == note.id,
                            isEditing: $isEditing
                        )
                        .id(note.id)
                        .onTapGesture {
                            selectedNoteId = note.id
                            viewModel.selectedNote = note
                            isEditing = true
                        }
                    }
                }
                .padding()
            }
            .onChange(of: selectedNoteId) { _, newId in
                if let id = newId {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .focusable()
        .onKeyPress { keyPress in
            // j/k only work when not editing
            if isEditing { return .ignored }
            return handleKeyPress(keyPress)
        }
        .task {
            await viewModel.loadNotes(context: modelContext)
            await viewModel.setupRealtime(context: modelContext)
            // Select first note
            if let first = viewModel.filteredNotes.first {
                viewModel.selectedNote = first
                selectedNoteId = first.id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewNote)) { _ in
            let note = viewModel.createNote(context: modelContext)
            selectedNoteId = note.id
            isEditing = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveNote)) { _ in
            try? modelContext.save()
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncNow)) { _ in
            Task {
                await viewModel.syncWithSupabase(context: modelContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshNotes)) { _ in
            Task {
                await viewModel.loadNotes(context: modelContext)
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    // MARK: - Keyboard Navigation

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        let notes = viewModel.filteredNotes
        guard !notes.isEmpty else { return .ignored }

        switch keyPress.characters {
        case "j":
            selectNextNote()
            return .handled
        case "k":
            selectPreviousNote()
            return .handled
        case "\r", "i": // Enter or i - start editing
            isEditing = true
            return .handled
        default:
            return .ignored
        }
    }

    private func selectNextNote() {
        let notes = viewModel.filteredNotes
        guard !notes.isEmpty else { return }

        if let currentId = selectedNoteId,
           let idx = notes.firstIndex(where: { $0.id == currentId }) {
            let nextIdx = min(idx + 1, notes.count - 1)
            selectedNoteId = notes[nextIdx].id
            viewModel.selectedNote = notes[nextIdx]
        } else {
            selectedNoteId = notes.first?.id
            viewModel.selectedNote = notes.first
        }
    }

    private func selectPreviousNote() {
        let notes = viewModel.filteredNotes
        guard !notes.isEmpty else { return }

        if let currentId = selectedNoteId,
           let idx = notes.firstIndex(where: { $0.id == currentId }) {
            let prevIdx = max(idx - 1, 0)
            selectedNoteId = notes[prevIdx].id
            viewModel.selectedNote = notes[prevIdx]
        } else {
            selectedNoteId = notes.first?.id
            viewModel.selectedNote = notes.first
        }
    }
}

// MARK: - Note Feed Card

struct NoteFeedCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var note: Note
    @Bindable var viewModel: EditorViewModel
    var isFocused: Bool
    @Binding var isEditing: Bool

    @State private var vimEngine = VimEngine()
    @State private var editingContent: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isEditing && isFocused {
                // Vim Editor
                VimEditorView(
                    text: $editingContent,
                    vimEngine: vimEngine,
                    onSave: saveNote,
                    onEscape: exitEditing
                )
                .frame(minHeight: 150)

                // Vim mode indicator
                HStack {
                    Text(vimEngine.mode.rawValue)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(modeColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(modeColor)

                    Spacer()
                }
            } else {
                // Display mode
                Text(note.preview.isEmpty ? "빈 노트" : note.preview)
                    .font(.body)
                    .foregroundStyle(note.preview.isEmpty ? .secondary : .primary)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Metadata
            HStack(spacing: 12) {
                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if !note.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(note.tags.prefix(3)) { tag in
                            Text("#\(tag.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if note.tags.count > 3 {
                            Text("+\(note.tags.count - 3)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                if note.hasMedia {
                    Image(systemName: "paperclip")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Sync status
                Circle()
                    .fill(note.syncStatus == .pending ? .orange : .green)
                    .frame(width: 6, height: 6)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(isFocused ? 0.15 : 0.05), radius: isFocused ? 8 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onAppear {
            if let block = note.rootBlocks.first(where: { $0.type == .text }) {
                editingContent = block.content ?? ""
            }
        }
        .onChange(of: editingContent) { _, newValue in
            if let block = note.rootBlocks.first(where: { $0.type == .text }) {
                block.content = newValue
                block.updatedAt = Date()
                block.syncStatus = .pending
                note.updatedAt = Date()
                note.syncStatus = .pending
            }
        }
    }

    private func saveNote() {
        try? modelContext.save()
        Task {
            await viewModel.syncWithSupabase(context: modelContext)
        }
    }

    private func exitEditing() {
        saveNote()
        isEditing = false
    }

    private var modeColor: Color {
        switch vimEngine.mode {
        case .normal: return .blue
        case .insert: return .green
        case .visual, .visualLine: return .purple
        case .command: return .orange
        case .operatorPending: return .yellow
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Note.self, NoteBlock.self, Tag.self], inMemory: true)
}
