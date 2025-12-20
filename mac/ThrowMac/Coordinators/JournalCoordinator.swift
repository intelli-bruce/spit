import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - App Mode

enum AppMode: Equatable {
    case browsing   // Navigate between notes with j/k, Enter to edit
    case editing    // VimEngine handles all input
}

// MARK: - Journal Coordinator

@MainActor
class JournalCoordinator: ObservableObject {
    // MARK: - Published State

    @Published var appMode: AppMode = .browsing
    @Published var dayGroups: [DayGroup] = []
    @Published var selectedNoteId: UUID?
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Vim Engine (Single Instance)

    let vimEngine = VimEngine()

    // MARK: - Private

    private let localFile = LocalFileService.shared
    private var rawContent: String = ""
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed

    var allNotes: [JournalNote] {
        dayGroups.flatMap { $0.notes }
    }

    var editingNote: JournalNote? {
        guard appMode == .editing, let id = selectedNoteId else { return nil }
        return allNotes.first { $0.id == id }
    }

    // MARK: - Initialization

    init() {
        setupVimEngineCallbacks()
        setupKeyboardHandler()
    }

    deinit {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Setup

    private func setupVimEngineCallbacks() {
        vimEngine.onEscapeInNormalMode = { [weak self] in
            self?.exitEditMode()
        }

        vimEngine.onSave = { [weak self] in
            Task { @MainActor in
                await self?.saveCurrentNote()
            }
        }
    }

    private func setupKeyboardHandler() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            return self.handleKeyEvent(event)
        }
    }

    // MARK: - Keyboard Handling

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        switch appMode {
        case .browsing:
            return handleBrowsingKey(event)
        case .editing:
            // VimEngine handles via MarkdownTextView's monitor
            // But we catch ESC here as backup
            return event
        }
    }

    private func handleBrowsingKey(_ event: NSEvent) -> NSEvent? {
        let keyCode = event.keyCode

        switch keyCode {
        case 125, 38: // Down arrow, j
            selectNextNote()
            return nil

        case 126, 40: // Up arrow, k
            selectPreviousNote()
            return nil

        case 36: // Enter
            if selectedNoteId != nil {
                enterEditMode()
                return nil
            }

        case 51: // Backspace - delete selected note
            if let note = allNotes.first(where: { $0.id == selectedNoteId }) {
                Task {
                    await deleteNote(note)
                }
                return nil
            }

        default:
            // ⌘N handled by SwiftUI keyboard shortcut
            break
        }

        return event
    }

    // MARK: - Mode Transitions

    func enterEditMode() {
        guard selectedNoteId != nil else { return }
        appMode = .editing
        vimEngine.enterInsertMode()
    }

    func exitEditMode() {
        appMode = .browsing
    }

    // MARK: - Navigation

    private func selectNextNote() {
        let notes = allNotes
        guard !notes.isEmpty else { return }

        if let currentId = selectedNoteId,
           let currentIndex = notes.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = min(currentIndex + 1, notes.count - 1)
            selectedNoteId = notes[nextIndex].id
        } else {
            selectedNoteId = notes.first?.id
        }
    }

    private func selectPreviousNote() {
        let notes = allNotes
        guard !notes.isEmpty else { return }

        if let currentId = selectedNoteId,
           let currentIndex = notes.firstIndex(where: { $0.id == currentId }) {
            let prevIndex = max(currentIndex - 1, 0)
            selectedNoteId = notes[prevIndex].id
        } else {
            selectedNoteId = notes.first?.id
        }
    }

    // MARK: - Data Operations

    func loadNotes() async {
        isLoading = true
        defer { isLoading = false }

        do {
            rawContent = try await localFile.readJournal()
            parseNotes()

            // Select first note if none selected
            if selectedNoteId == nil, let first = allNotes.first {
                selectedNoteId = first.id
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func parseNotes() {
        let entries = JournalMarkdownParser.parseEntries(from: rawContent)

        var groups: [String: [JournalNote]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for entry in entries {
            let dateKey = dateFormatter.string(from: entry.timestamp)
            if groups[dateKey] == nil {
                groups[dateKey] = []
            }
            groups[dateKey]?.append(entry)
        }

        dayGroups = groups.map { key, notes in
            let date = dateFormatter.date(from: key) ?? Date()
            return DayGroup(
                id: key,
                date: date,
                notes: notes.sorted { $0.timestamp > $1.timestamp }
            )
        }.sorted { $0.date > $1.date }
    }

    func addNote() async {
        let now = Date()
        let timestamp = formatTimestamp(now)

        let newSection = "\n---\n\n## \(timestamp)\n\n"
        rawContent += newSection

        do {
            try await localFile.writeJournal(rawContent)
            parseNotes()

            // Find and select the new note
            for group in dayGroups {
                if let note = group.notes.first(where: { formatTimestamp($0.timestamp) == timestamp }) {
                    selectedNoteId = note.id
                    enterEditMode()
                    break
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateNote(_ note: JournalNote, newContent: String) async {
        let oldTimestamp = formatTimestamp(note.timestamp)
        let pattern = "## \(oldTimestamp)\n\n[\\s\\S]*?(?=\n---|\n## |$)"

        if let range = rawContent.range(of: pattern, options: .regularExpression) {
            let replacement = "## \(oldTimestamp)\n\n\(newContent)"
            rawContent.replaceSubrange(range, with: replacement)

            do {
                try await localFile.writeJournal(rawContent)
                parseNotes()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func deleteNote(_ note: JournalNote) async {
        let timestamp = formatTimestamp(note.timestamp)
        let pattern = "\n---\n\n## \(timestamp)\n\n[\\s\\S]*?(?=\n---|\n## |$)"

        if let range = rawContent.range(of: pattern, options: .regularExpression) {
            rawContent.removeSubrange(range)

            do {
                try await localFile.writeJournal(rawContent)

                // Select next note before parsing
                let notes = allNotes
                if let currentIndex = notes.firstIndex(where: { $0.id == note.id }) {
                    let nextIndex = min(currentIndex, notes.count - 2)
                    if nextIndex >= 0 && nextIndex < notes.count - 1 {
                        // Will select after parse, find by position
                    }
                }

                parseNotes()

                // Select first note if current was deleted
                if !allNotes.contains(where: { $0.id == selectedNoteId }) {
                    selectedNoteId = allNotes.first?.id
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func saveCurrentNote() async {
        // Called from :w in vim
        // Content is already synced via binding
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
