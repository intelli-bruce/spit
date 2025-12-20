import Foundation
import SwiftData
import Combine
import Supabase

@MainActor
@Observable
class EditorViewModel {
    var notes: [Note] = []
    var selectedNote: Note?
    var isLoading = false
    var isSyncing = false
    var error: String?
    var searchText = ""
    var selectedTagFilter: Tag?

    private var realtimeChannels: [RealtimeChannelV2] = []
    private let supabase = SupabaseService.shared

    // MARK: - Filtered Notes

    var filteredNotes: [Note] {
        var result = notes.filter { !$0.isDeleted }

        if !searchText.isEmpty {
            result = result.filter { note in
                note.preview.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let tag = selectedTagFilter {
            result = result.filter { note in
                note.tags.contains { $0.id == tag.id }
            }
        }

        return result.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Loading

    func loadNotes(context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        // Load from local SwiftData first
        let descriptor = FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        if let localNotes = try? context.fetch(descriptor) {
            notes = localNotes
            print("[DEBUG] Loaded \(localNotes.count) notes from local DB")
        } else {
            print("[DEBUG] Failed to load notes from local DB")
        }

        // Then sync with Supabase
        await syncWithSupabase(context: context)
        print("[DEBUG] After sync, notes count: \(notes.count), filtered: \(filteredNotes.count)")
    }

    // MARK: - CRUD

    func createNote(context: ModelContext) -> Note {
        let note = Note()
        context.insert(note)

        let textBlock = NoteBlock(note: note, type: .text, content: "", position: 0)
        context.insert(textBlock)
        note.blocks.append(textBlock)

        do {
            try context.save()
            print("[DEBUG] Saved note successfully")
        } catch {
            print("[DEBUG] Failed to save note: \(error)")
        }

        notes.insert(note, at: 0)
        selectedNote = note

        print("[DEBUG] Created note: \(note.id), blocks: \(note.blocks.count), total notes: \(notes.count)")

        // Sync to Supabase
        Task {
            await syncNote(note, context: context)
        }

        return note
    }

    func deleteNote(_ note: Note, context: ModelContext) {
        note.isDeleted = true
        note.updatedAt = Date()
        note.syncStatus = .pending

        try? context.save()

        // Sync deletion
        Task {
            try? await supabase.deleteNote(id: note.id)
            note.syncStatus = .synced
            try? context.save()
        }
    }

    func updateNoteContent(_ note: Note, content: String, context: ModelContext) {
        guard let textBlock = note.rootBlocks.first(where: { $0.type == .text }) else { return }

        textBlock.content = content
        textBlock.updatedAt = Date()
        textBlock.version += 1
        textBlock.syncStatus = .pending

        note.updatedAt = Date()
        note.syncStatus = .pending

        try? context.save()
    }

    // MARK: - Tags

    func addTag(_ tagName: String, to note: Note, context: ModelContext) async {
        // Find or create tag locally
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate { $0.name == tagName }
        )

        var tag: Tag
        if let existingTag = try? context.fetch(descriptor).first {
            tag = existingTag
        } else {
            tag = Tag(name: tagName)
            context.insert(tag)
        }

        if !note.tags.contains(where: { $0.id == tag.id }) {
            note.tags.append(tag)
            note.updatedAt = Date()
            note.syncStatus = .pending
            try? context.save()
        }

        // Sync to Supabase
        Task {
            do {
                let remoteTag = try await supabase.findOrCreateTag(name: tagName)
                try await supabase.addTagToNote(noteId: note.id, tagId: UUID(uuidString: remoteTag.id) ?? tag.id)
            } catch {
                print("Tag sync failed: \(error)")
            }
        }
    }

    func removeTag(_ tag: Tag, from note: Note, context: ModelContext) {
        note.tags.removeAll { $0.id == tag.id }
        note.updatedAt = Date()
        note.syncStatus = .pending
        try? context.save()

        Task {
            try? await supabase.removeTagFromNote(noteId: note.id, tagId: tag.id)
        }
    }

    // MARK: - Sync

    func syncWithSupabase(context: ModelContext) async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            // Fetch remote notes
            let remoteNotes = try await supabase.fetchNotes()
            let noteIds = remoteNotes.compactMap { UUID(uuidString: $0.id) }

            // Fetch blocks for all notes
            let remoteBlocks = try await supabase.fetchAllBlocks(noteIds: noteIds)

            // Fetch tags
            let remoteNoteTags = try await supabase.fetchAllNoteTags(noteIds: noteIds)

            // Merge with local
            for dto in remoteNotes {
                let noteId = UUID(uuidString: dto.id) ?? UUID()

                // Check if exists locally
                let descriptor = FetchDescriptor<Note>(
                    predicate: #Predicate { $0.id == noteId }
                )

                if let existingNote = try? context.fetch(descriptor).first {
                    // Update if remote is newer
                    let formatter = ISO8601DateFormatter()
                    if let remoteDate = formatter.date(from: dto.updated_at),
                       remoteDate > existingNote.updatedAt {
                        existingNote.isDeleted = dto.is_deleted
                        existingNote.updatedAt = remoteDate
                        existingNote.syncStatus = .synced
                    }
                } else {
                    // Insert new note
                    let note = dto.toNote()
                    context.insert(note)

                    // Add blocks
                    let noteBlocks = remoteBlocks.filter { $0.note_id == dto.id }
                    for blockDTO in noteBlocks {
                        let block = blockDTO.toNoteBlock()
                        block.note = note
                        note.blocks.append(block)
                    }

                    // Add tags
                    if let tagDTOs = remoteNoteTags[dto.id] {
                        for tagDTO in tagDTOs {
                            let tag = tagDTO.toTag()
                            let tagName = tag.name
                            // Check if tag exists
                            let tagDescriptor = FetchDescriptor<Tag>(
                                predicate: #Predicate { $0.name == tagName }
                            )
                            if let existingTag = try? context.fetch(tagDescriptor).first {
                                note.tags.append(existingTag)
                            } else {
                                context.insert(tag)
                                note.tags.append(tag)
                            }
                        }
                    }
                }
            }

            // Upload pending local changes
            let allDescriptor = FetchDescriptor<Note>()
            if let allNotes = try? context.fetch(allDescriptor) {
                let pendingNotes = allNotes.filter { $0.syncStatus == .pending }
                print("[DEBUG] Found \(pendingNotes.count) pending notes to sync")
                for note in pendingNotes {
                    await syncNote(note, context: context)
                }
            }

            try? context.save()

            // Reload notes
            let reloadDescriptor = FetchDescriptor<Note>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            if let reloadedNotes = try? context.fetch(reloadDescriptor) {
                notes = reloadedNotes
            }

            error = nil
        } catch {
            self.error = "Sync failed: \(error.localizedDescription)"
        }
    }

    private func syncNote(_ note: Note, context: ModelContext) async {
        do {
            print("[DEBUG] Syncing note: \(note.id)")
            // Create or update note
            _ = try await supabase.createNote(note: note)
            note.syncStatus = .synced
            print("[DEBUG] Note synced successfully: \(note.id)")

            // Sync blocks
            let pendingBlocks = note.blocks.filter { $0.syncStatus == .pending }
            print("[DEBUG] Syncing \(pendingBlocks.count) pending blocks")
            for block in pendingBlocks {
                _ = try await supabase.createBlock(block: block, noteId: note.id)
                block.syncStatus = .synced
            }

            try? context.save()
        } catch {
            print("[ERROR] Note sync failed: \(error)")
        }
    }

    // MARK: - Realtime

    func setupRealtime(context: ModelContext) async {
        // Subscribe to notes
        let notesChannel = await supabase.subscribeToNotes(
            onInsert: { [weak self] dto in
                Task { @MainActor in
                    self?.handleRemoteNoteInsert(dto, context: context)
                }
            },
            onUpdate: { [weak self] dto in
                Task { @MainActor in
                    self?.handleRemoteNoteUpdate(dto, context: context)
                }
            },
            onDelete: { [weak self] id in
                Task { @MainActor in
                    self?.handleRemoteNoteDelete(id, context: context)
                }
            }
        )
        realtimeChannels.append(notesChannel)

        // Subscribe to blocks
        let blocksChannel = await supabase.subscribeToBlocks(
            onInsert: { [weak self] dto in
                Task { @MainActor in
                    self?.handleRemoteBlockInsert(dto, context: context)
                }
            },
            onUpdate: { [weak self] dto in
                Task { @MainActor in
                    self?.handleRemoteBlockUpdate(dto, context: context)
                }
            },
            onDelete: { [weak self] id in
                Task { @MainActor in
                    self?.handleRemoteBlockDelete(id, context: context)
                }
            }
        )
        realtimeChannels.append(blocksChannel)
    }

    private func handleRemoteNoteInsert(_ dto: NoteDTO, context: ModelContext) {
        let noteId = UUID(uuidString: dto.id) ?? UUID()

        // Check if already exists
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.id == noteId }
        )
        guard (try? context.fetch(descriptor).first) == nil else { return }

        let note = dto.toNote()
        context.insert(note)
        try? context.save()

        notes.insert(note, at: 0)
    }

    private func handleRemoteNoteUpdate(_ dto: NoteDTO, context: ModelContext) {
        let noteId = UUID(uuidString: dto.id) ?? UUID()

        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.id == noteId }
        )
        guard let note = try? context.fetch(descriptor).first else { return }

        let formatter = ISO8601DateFormatter()
        note.isDeleted = dto.is_deleted
        note.updatedAt = formatter.date(from: dto.updated_at) ?? Date()
        note.syncStatus = .synced

        try? context.save()
    }

    private func handleRemoteNoteDelete(_ id: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.id == id }
        )
        guard let note = try? context.fetch(descriptor).first else { return }

        note.isDeleted = true
        note.syncStatus = .synced
        try? context.save()
    }

    private func handleRemoteBlockInsert(_ dto: NoteBlockDTO, context: ModelContext) {
        let noteId = UUID(uuidString: dto.note_id) ?? UUID()
        let blockId = UUID(uuidString: dto.id) ?? UUID()

        // Check if block already exists
        let blockDescriptor = FetchDescriptor<NoteBlock>(
            predicate: #Predicate { $0.id == blockId }
        )
        guard (try? context.fetch(blockDescriptor).first) == nil else { return }

        // Find parent note
        let noteDescriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.id == noteId }
        )
        guard let note = try? context.fetch(noteDescriptor).first else { return }

        let block = dto.toNoteBlock()
        block.note = note
        note.blocks.append(block)

        try? context.save()
    }

    private func handleRemoteBlockUpdate(_ dto: NoteBlockDTO, context: ModelContext) {
        let blockId = UUID(uuidString: dto.id) ?? UUID()

        let descriptor = FetchDescriptor<NoteBlock>(
            predicate: #Predicate { $0.id == blockId }
        )
        guard let block = try? context.fetch(descriptor).first else { return }

        let formatter = ISO8601DateFormatter()
        block.content = dto.content
        block.storagePath = dto.storage_path
        block.position = dto.position
        block.version = dto.version
        block.updatedAt = formatter.date(from: dto.updated_at) ?? Date()
        block.syncStatus = .synced

        try? context.save()
    }

    private func handleRemoteBlockDelete(_ id: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<NoteBlock>(
            predicate: #Predicate { $0.id == id }
        )
        guard let block = try? context.fetch(descriptor).first else { return }

        context.delete(block)
        try? context.save()
    }

    // MARK: - History

    func fetchBlockHistory(block: NoteBlock) async -> [NoteBlockHistoryDTO] {
        do {
            return try await supabase.fetchBlockHistory(blockId: block.id)
        } catch {
            print("Failed to fetch history: \(error)")
            return []
        }
    }
}
