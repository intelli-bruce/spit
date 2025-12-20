import Foundation
import Supabase

actor SupabaseService {
    static let shared = SupabaseService()

    private let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }

    // MARK: - Notes

    func createNote(note: Note) async throws -> NoteDTO {
        let dto = NoteDTO(from: note)
        let response: NoteDTO = try await client.from("notes")
            .insert(dto)
            .select()
            .single()
            .execute()
            .value
        return response
    }

    func fetchNotes(limit: Int = 100, includeDeleted: Bool = false) async throws -> [NoteDTO] {
        var query = client.from("notes")
            .select()

        if !includeDeleted {
            query = query.eq("is_deleted", value: false)
        }

        let response: [NoteDTO] = try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return response
    }

    func fetchNote(id: UUID) async throws -> NoteDTO? {
        let response: [NoteDTO] = try await client.from("notes")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return response.first
    }

    func updateNote(id: UUID, isDeleted: Bool? = nil) async throws {
        var updates: [String: AnyEncodable] = [:]

        if let isDeleted = isDeleted {
            updates["is_deleted"] = AnyEncodable(isDeleted)
        }

        guard !updates.isEmpty else { return }

        try await client.from("notes")
            .update(updates)
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteNote(id: UUID) async throws {
        try await updateNote(id: id, isDeleted: true)
    }

    // MARK: - Note Blocks

    func createBlock(block: NoteBlock, noteId: UUID) async throws -> NoteBlockDTO {
        let dto = NoteBlockDTO(from: block, noteId: noteId)
        let response: NoteBlockDTO = try await client.from("note_blocks")
            .insert(dto)
            .select()
            .single()
            .execute()
            .value
        return response
    }

    func fetchBlocks(noteId: UUID) async throws -> [NoteBlockDTO] {
        let response: [NoteBlockDTO] = try await client.from("note_blocks")
            .select()
            .eq("note_id", value: noteId.uuidString)
            .order("position", ascending: true)
            .execute()
            .value

        return response
    }

    func fetchAllBlocks(noteIds: [UUID]) async throws -> [NoteBlockDTO] {
        guard !noteIds.isEmpty else { return [] }

        let ids = noteIds.map { $0.uuidString }
        let response: [NoteBlockDTO] = try await client.from("note_blocks")
            .select()
            .in("note_id", values: ids)
            .order("position", ascending: true)
            .execute()
            .value

        return response
    }

    func updateBlock(id: UUID, content: String? = nil, storagePath: String? = nil, position: Int? = nil) async throws {
        var updates: [String: AnyEncodable] = [:]

        if let content = content {
            updates["content"] = AnyEncodable(content)
        }
        if let storagePath = storagePath {
            updates["storage_path"] = AnyEncodable(storagePath)
        }
        if let position = position {
            updates["position"] = AnyEncodable(position)
        }

        guard !updates.isEmpty else { return }

        try await client.from("note_blocks")
            .update(updates)
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteBlock(id: UUID) async throws {
        try await client.from("note_blocks")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Block History

    func fetchBlockHistory(blockId: UUID) async throws -> [NoteBlockHistoryDTO] {
        let response: [NoteBlockHistoryDTO] = try await client.from("note_block_history")
            .select()
            .eq("block_id", value: blockId.uuidString)
            .order("version", ascending: false)
            .execute()
            .value

        return response
    }

    // MARK: - Tags

    func fetchTags() async throws -> [TagDTO] {
        let response: [TagDTO] = try await client.from("tags")
            .select()
            .order("name", ascending: true)
            .execute()
            .value

        return response
    }

    func createTag(name: String) async throws -> TagDTO {
        let dto = TagDTO(name: name)
        let response: TagDTO = try await client.from("tags")
            .insert(dto)
            .select()
            .single()
            .execute()
            .value
        return response
    }

    func findOrCreateTag(name: String) async throws -> TagDTO {
        let existing: [TagDTO] = try await client.from("tags")
            .select()
            .eq("name", value: name)
            .limit(1)
            .execute()
            .value

        if let tag = existing.first {
            return tag
        }

        return try await createTag(name: name)
    }

    // MARK: - Note Tags

    func addTagToNote(noteId: UUID, tagId: UUID) async throws {
        let dto = NoteTagDTO(note_id: noteId.uuidString, tag_id: tagId.uuidString)
        try await client.from("note_tags")
            .insert(dto)
            .execute()
    }

    func removeTagFromNote(noteId: UUID, tagId: UUID) async throws {
        try await client.from("note_tags")
            .delete()
            .eq("note_id", value: noteId.uuidString)
            .eq("tag_id", value: tagId.uuidString)
            .execute()
    }

    func fetchNoteTags(noteId: UUID) async throws -> [TagDTO] {
        let response: [NoteTagWithTag] = try await client.from("note_tags")
            .select("tag_id, tags(*)")
            .eq("note_id", value: noteId.uuidString)
            .execute()
            .value

        return response.compactMap { $0.tags }
    }

    func fetchAllNoteTags(noteIds: [UUID]) async throws -> [String: [TagDTO]] {
        guard !noteIds.isEmpty else { return [:] }

        let ids = noteIds.map { $0.uuidString }
        let response: [NoteTagWithTagAndNoteId] = try await client.from("note_tags")
            .select("note_id, tag_id, tags(*)")
            .in("note_id", values: ids)
            .execute()
            .value

        var result: [String: [TagDTO]] = [:]
        for item in response {
            if let tag = item.tags {
                result[item.note_id, default: []].append(tag)
            }
        }
        return result
    }

    // MARK: - Storage

    func uploadMedia(data: Data, path: String, contentType: String) async throws -> String {
        try await client.storage
            .from("throw-media")
            .upload(path: path, file: data, options: FileOptions(contentType: contentType))

        return path
    }

    func downloadMedia(path: String) async throws -> Data {
        try await client.storage
            .from("throw-media")
            .download(path: path)
    }

    func deleteMedia(path: String) async throws {
        try await client.storage
            .from("throw-media")
            .remove(paths: [path])
    }

    func getPublicURL(path: String) -> URL? {
        try? client.storage
            .from("throw-media")
            .getPublicURL(path: path)
    }

    // MARK: - Realtime Subscription

    func subscribeToNotes(
        onInsert: @escaping (NoteDTO) -> Void,
        onUpdate: @escaping (NoteDTO) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) async -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("notes")

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "notes"
        )

        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "notes"
        )

        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "notes"
        )

        Task {
            for await insertion in insertions {
                if let dto = try? insertion.decodeRecord(as: NoteDTO.self, decoder: JSONDecoder()) {
                    onInsert(dto)
                }
            }
        }

        Task {
            for await update in updates {
                if let dto = try? update.decodeRecord(as: NoteDTO.self, decoder: JSONDecoder()) {
                    onUpdate(dto)
                }
            }
        }

        Task {
            for await deletion in deletions {
                if let idString = deletion.oldRecord["id"]?.stringValue,
                   let id = UUID(uuidString: idString) {
                    onDelete(id)
                }
            }
        }

        await channel.subscribe()
        return channel
    }

    func subscribeToBlocks(
        onInsert: @escaping (NoteBlockDTO) -> Void,
        onUpdate: @escaping (NoteBlockDTO) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) async -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("note_blocks")

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "note_blocks"
        )

        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "note_blocks"
        )

        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "note_blocks"
        )

        Task {
            for await insertion in insertions {
                if let dto = try? insertion.decodeRecord(as: NoteBlockDTO.self, decoder: JSONDecoder()) {
                    onInsert(dto)
                }
            }
        }

        Task {
            for await update in updates {
                if let dto = try? update.decodeRecord(as: NoteBlockDTO.self, decoder: JSONDecoder()) {
                    onUpdate(dto)
                }
            }
        }

        Task {
            for await deletion in deletions {
                if let idString = deletion.oldRecord["id"]?.stringValue,
                   let id = UUID(uuidString: idString) {
                    onDelete(id)
                }
            }
        }

        await channel.subscribe()
        return channel
    }
}

// MARK: - DTOs

struct NoteDTO: Codable {
    let id: String
    let created_at: String
    let updated_at: String
    let source: String
    let device_id: String?
    let is_deleted: Bool

    init(
        id: String = UUID().uuidString,
        created_at: String = ISO8601DateFormatter().string(from: Date()),
        updated_at: String = ISO8601DateFormatter().string(from: Date()),
        source: String = "mac",
        device_id: String? = Config.deviceId,
        is_deleted: Bool = false
    ) {
        self.id = id
        self.created_at = created_at
        self.updated_at = updated_at
        self.source = source
        self.device_id = device_id
        self.is_deleted = is_deleted
    }

    init(from note: Note) {
        let formatter = ISO8601DateFormatter()
        self.id = note.id.uuidString
        self.created_at = formatter.string(from: note.createdAt)
        self.updated_at = formatter.string(from: note.updatedAt)
        self.source = note.source
        self.device_id = note.deviceId
        self.is_deleted = note.isDeleted
    }

    func toNote() -> Note {
        let formatter = ISO8601DateFormatter()
        return Note(
            id: UUID(uuidString: id) ?? UUID(),
            createdAt: formatter.date(from: created_at) ?? Date(),
            updatedAt: formatter.date(from: updated_at) ?? Date(),
            source: source,
            deviceId: device_id,
            isDeleted: is_deleted,
            syncStatus: .synced
        )
    }
}

struct NoteBlockDTO: Codable {
    let id: String
    let note_id: String
    let parent_id: String?
    let type: String
    let content: String?
    let storage_path: String?
    let position: Int
    let created_at: String
    let updated_at: String
    let version: Int

    init(
        id: String = UUID().uuidString,
        note_id: String,
        parent_id: String? = nil,
        type: String = "text",
        content: String? = nil,
        storage_path: String? = nil,
        position: Int = 0,
        created_at: String = ISO8601DateFormatter().string(from: Date()),
        updated_at: String = ISO8601DateFormatter().string(from: Date()),
        version: Int = 1
    ) {
        self.id = id
        self.note_id = note_id
        self.parent_id = parent_id
        self.type = type
        self.content = content
        self.storage_path = storage_path
        self.position = position
        self.created_at = created_at
        self.updated_at = updated_at
        self.version = version
    }

    init(from block: NoteBlock, noteId: UUID) {
        let formatter = ISO8601DateFormatter()
        self.id = block.id.uuidString
        self.note_id = noteId.uuidString
        self.parent_id = block.parentBlock?.id.uuidString
        self.type = block.type.rawValue
        self.content = block.content
        self.storage_path = block.storagePath
        self.position = block.position
        self.created_at = formatter.string(from: block.createdAt)
        self.updated_at = formatter.string(from: block.updatedAt)
        self.version = block.version
    }

    func toNoteBlock() -> NoteBlock {
        let formatter = ISO8601DateFormatter()
        return NoteBlock(
            id: UUID(uuidString: id) ?? UUID(),
            type: BlockType(rawValue: type) ?? .text,
            content: content,
            storagePath: storage_path,
            position: position,
            createdAt: formatter.date(from: created_at) ?? Date(),
            updatedAt: formatter.date(from: updated_at) ?? Date(),
            version: version,
            syncStatus: .synced
        )
    }
}

struct NoteBlockHistoryDTO: Codable {
    let id: String
    let block_id: String
    let content: String?
    let storage_path: String?
    let version: Int
    let changed_at: String
    let change_type: String
}

struct TagDTO: Codable {
    let id: String
    let name: String
    let created_at: String

    init(
        id: String = UUID().uuidString,
        name: String,
        created_at: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.name = name
        self.created_at = created_at
    }

    func toTag() -> Tag {
        let formatter = ISO8601DateFormatter()
        return Tag(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            createdAt: formatter.date(from: created_at) ?? Date(),
            syncStatus: .synced
        )
    }
}

struct NoteTagDTO: Codable {
    let note_id: String
    let tag_id: String
}

struct NoteTagWithTag: Codable {
    let tag_id: String
    let tags: TagDTO?
}

struct NoteTagWithTagAndNoteId: Codable {
    let note_id: String
    let tag_id: String
    let tags: TagDTO?
}

// MARK: - Helper

struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}
