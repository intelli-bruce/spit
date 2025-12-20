import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = EditorViewModel()
    @State private var selectedNoteId: UUID?
    @State private var isEditing = false
    @FocusState private var isFeedFocused: Bool

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
        .focused($isFeedFocused)
        .onKeyPress { keyPress in
            // j/k only work when not editing
            if isEditing { return .ignored }
            return handleKeyPress(keyPress)
        }
        .onAppear {
            isFeedFocused = true
        }
        .onChange(of: isEditing) { _, newValue in
            if !newValue {
                // Return focus to feed when exiting edit mode
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFeedFocused = true
                }
            }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isEditing && isFocused {
                // Block Editor
                BlockEditorView(
                    note: note,
                    isEditing: $isEditing,
                    onSave: saveNote
                )
                .frame(minHeight: 100)
            } else {
                // Display mode - show all blocks
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(note.rootBlocks.sorted { $0.position < $1.position }) { block in
                        BlockPreviewRow(block: block)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if note.rootBlocks.isEmpty {
                    Text("빈 노트")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
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

                // Block count
                Text("\(note.rootBlocks.count) blocks")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

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
    }

    private func saveNote() {
        try? modelContext.save()
        Task {
            await viewModel.syncWithSupabase(context: modelContext)
        }
    }
}

// MARK: - Block Preview Row (for display mode)

struct BlockPreviewRow: View {
    let block: NoteBlock

    var body: some View {
        Group {
            switch block.type {
            case .text:
                if let content = block.content, !content.isEmpty {
                    Text(content)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(nil)
                }
            case .image:
                HStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.caption)
                    Text("Image")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            case .audio:
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption)
                    Text("Audio")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            case .video:
                HStack(spacing: 4) {
                    Image(systemName: "video")
                        .font(.caption)
                    Text("Video")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Note.self, NoteBlock.self, Tag.self], inMemory: true)
}
