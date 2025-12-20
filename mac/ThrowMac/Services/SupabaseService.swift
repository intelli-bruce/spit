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

    // MARK: - Journal Entries

    func fetchEntries() async throws -> [JournalEntry] {
        let response: [JournalEntryDTO] = try await client.from("journal_entries")
            .select()
            .eq("is_deleted", value: false)
            .order("timestamp", ascending: false)
            .execute()
            .value

        return response.map { $0.toModel() }
    }

    func insertEntry(_ entry: JournalEntry) async throws {
        let dto = JournalEntryDTO(from: entry)
        try await client.from("journal_entries")
            .insert(dto)
            .execute()
    }

    func updateEntry(_ entry: JournalEntry) async throws {
        let dto = JournalEntryDTO(from: entry)
        try await client.from("journal_entries")
            .update(dto)
            .eq("id", value: entry.id.uuidString)
            .execute()
    }

    func deleteEntry(id: UUID) async throws {
        try await client.from("journal_entries")
            .update(["is_deleted": true])
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Journal Metadata (Full Document)

    func fetchMetadata() async throws -> JournalMetadata? {
        let response: [JournalMetadataDTO] = try await client.from("journal_metadata")
            .select()
            .limit(1)
            .execute()
            .value

        return response.first?.toModel()
    }

    func updateMetadata(_ metadata: JournalMetadata) async throws {
        let dto = JournalMetadataDTO(from: metadata)
        try await client.from("journal_metadata")
            .update(dto)
            .eq("id", value: metadata.id.uuidString)
            .execute()
    }

    // MARK: - Realtime Subscription

    func subscribeToEntries(
        onInsert: @escaping (JournalEntry) -> Void,
        onUpdate: @escaping (JournalEntry) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) async -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("journal_entries")

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "journal_entries"
        )

        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "journal_entries"
        )

        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "journal_entries"
        )

        Task {
            for await insertion in insertions {
                if let dto = try? insertion.decodeRecord(as: JournalEntryDTO.self, decoder: JSONDecoder()) {
                    onInsert(dto.toModel())
                }
            }
        }

        Task {
            for await update in updates {
                if let dto = try? update.decodeRecord(as: JournalEntryDTO.self, decoder: JSONDecoder()) {
                    onUpdate(dto.toModel())
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

private struct JournalEntryDTO: Codable {
    let id: String
    let content: String
    let timestamp: String
    let source: String
    let device_id: String?
    let created_at: String
    let updated_at: String
    let is_deleted: Bool
    let version: Int

    init(from entry: JournalEntry) {
        let formatter = ISO8601DateFormatter()
        self.id = entry.id.uuidString
        self.content = entry.content
        self.timestamp = formatter.string(from: entry.timestamp)
        self.source = entry.source.rawValue
        self.device_id = entry.deviceId
        self.created_at = formatter.string(from: entry.createdAt)
        self.updated_at = formatter.string(from: entry.updatedAt)
        self.is_deleted = entry.isDeleted
        self.version = entry.version
    }

    func toModel() -> JournalEntry {
        let formatter = ISO8601DateFormatter()
        return JournalEntry(
            id: UUID(uuidString: id) ?? UUID(),
            content: content,
            timestamp: formatter.date(from: timestamp) ?? Date(),
            source: EntrySource(rawValue: source) ?? .manual,
            deviceId: device_id,
            createdAt: formatter.date(from: created_at) ?? Date(),
            updatedAt: formatter.date(from: updated_at) ?? Date(),
            isDeleted: is_deleted,
            version: version
        )
    }
}

private struct JournalMetadataDTO: Codable {
    let id: String
    let full_content: String
    let content_hash: String
    let last_sync_at: String
    let version: Int

    init(from metadata: JournalMetadata) {
        let formatter = ISO8601DateFormatter()
        self.id = metadata.id.uuidString
        self.full_content = metadata.fullContent
        self.content_hash = metadata.contentHash
        self.last_sync_at = formatter.string(from: metadata.lastSyncAt)
        self.version = metadata.version
    }

    func toModel() -> JournalMetadata {
        let formatter = ISO8601DateFormatter()
        return JournalMetadata(
            id: UUID(uuidString: id) ?? UUID(),
            fullContent: full_content,
            contentHash: content_hash,
            lastSyncAt: formatter.date(from: last_sync_at) ?? Date(),
            version: version
        )
    }
}
