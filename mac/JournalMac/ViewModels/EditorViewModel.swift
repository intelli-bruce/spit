import Foundation
import Combine
import Supabase

@MainActor
class EditorViewModel: ObservableObject {
    @Published var content: String = ""
    @Published var entries: [JournalEntry] = []
    @Published var selectedEntry: JournalEntry?
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var error: String?
    @Published var hasUnsavedChanges = false

    private var cancellables = Set<AnyCancellable>()
    private var saveTask: Task<Void, Never>?
    private var realtimeChannel: RealtimeChannelV2?

    private let supabase = SupabaseService.shared
    private let localFile = LocalFileService.shared

    init() {
        setupAutoSave()
        setupFileWatching()
    }

    // MARK: - Loading

    func loadContent() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 1. Supabase에서 먼저 가져오기
            let remoteEntries = try await supabase.fetchEntries()
            entries = remoteEntries.sorted { $0.timestamp > $1.timestamp }

            // 2. Journal.md 생성/업데이트
            if entries.isEmpty {
                content = "# Journal\n\n---\n"
            } else {
                content = MarkdownParser.composeDocument(entries: entries)
            }

            // 3. 로컬 파일에 저장
            try await localFile.writeJournal(content)

            error = nil
        } catch {
            // Supabase 실패시 로컬 파일 시도
            do {
                content = try await localFile.readJournal()
                let parsed = MarkdownParser.parseEntries(from: content)
                entries = parsed.map { $0.toJournalEntry() }
            } catch {
                // 둘 다 실패시 빈 저널 생성
                content = "# Journal\n\n---\n"
                entries = []
                try? await localFile.writeJournal(content)
            }
            self.error = "Offline mode: \(error.localizedDescription)"
        }
    }

    // MARK: - Saving

    private func setupAutoSave() {
        $content
            .debounce(for: .seconds(Config.debounceDelay), scheduler: RunLoop.main)
            .sink { [weak self] newContent in
                self?.saveTask?.cancel()
                self?.saveTask = Task {
                    await self?.saveToFile()
                }
            }
            .store(in: &cancellables)
    }

    private func saveToFile() async {
        guard hasUnsavedChanges else { return }

        do {
            try await localFile.writeJournal(content)
            hasUnsavedChanges = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    func contentDidChange() {
        hasUnsavedChanges = true
    }

    // MARK: - New Entry

    func addNewEntry() {
        let timestamp = formatTimestamp(Date())
        let newSection = "\n\n---\n\n## \(timestamp)\n\n"

        content += newSection

        // Move cursor to end (handled by view)
        hasUnsavedChanges = true
    }

    // MARK: - Sync

    func syncWithSupabase() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            // Fetch remote entries
            let remoteEntries = try await supabase.fetchEntries()

            // Merge with local entries (append-only strategy)
            let merged = mergeEntries(local: entries, remote: remoteEntries)

            // Update local state
            entries = merged

            // Recompose document
            content = MarkdownParser.composeDocument(entries: merged)

            // Save to file
            try await localFile.writeJournal(content)

            error = nil
        } catch {
            self.error = "Sync failed: \(error.localizedDescription)"
        }
    }

    private func mergeEntries(local: [JournalEntry], remote: [JournalEntry]) -> [JournalEntry] {
        var merged: [UUID: JournalEntry] = [:]

        // Add local entries
        for entry in local {
            merged[entry.id] = entry
        }

        // Merge remote entries (newer wins)
        for entry in remote {
            if let existing = merged[entry.id] {
                if entry.updatedAt > existing.updatedAt {
                    merged[entry.id] = entry
                }
            } else {
                merged[entry.id] = entry
            }
        }

        // Sort by timestamp descending
        return Array(merged.values).sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Realtime

    func setupRealtime() async {
        realtimeChannel = await supabase.subscribeToEntries(
            onInsert: { [weak self] entry in
                Task { @MainActor in
                    self?.handleRemoteInsert(entry)
                }
            },
            onUpdate: { [weak self] entry in
                Task { @MainActor in
                    self?.handleRemoteUpdate(entry)
                }
            },
            onDelete: { [weak self] id in
                Task { @MainActor in
                    self?.handleRemoteDelete(id)
                }
            }
        )
    }

    private func handleRemoteInsert(_ entry: JournalEntry) {
        guard !entries.contains(where: { $0.id == entry.id }) else { return }

        entries.append(entry)
        entries.sort { $0.timestamp > $1.timestamp }
        content = MarkdownParser.composeDocument(entries: entries)

        Task {
            try? await localFile.writeJournal(content)
        }
    }

    private func handleRemoteUpdate(_ entry: JournalEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }

        entries[index] = entry
        content = MarkdownParser.composeDocument(entries: entries)

        Task {
            try? await localFile.writeJournal(content)
        }
    }

    private func handleRemoteDelete(_ id: UUID) {
        entries.removeAll { $0.id == id }
        content = MarkdownParser.composeDocument(entries: entries)

        Task {
            try? await localFile.writeJournal(content)
        }
    }

    // MARK: - File Watching

    private func setupFileWatching() {
        localFile.startWatching { [weak self] in
            Task { @MainActor in
                await self?.handleFileChange()
            }
        }
    }

    private func handleFileChange() async {
        do {
            guard try await localFile.hasFileChanged() else { return }

            let newContent = try await localFile.readJournal()

            // Only update if different
            if newContent != content {
                content = newContent
                entries = MarkdownParser.parseEntries(from: content).map { $0.toJournalEntry() }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
