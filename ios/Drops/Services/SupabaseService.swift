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

    func appendToJournal(content: String) async throws {
        let entry = JournalEntryDTO(
            content: content,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            source: "ios",
            device_id: Config.deviceId
        )

        try await client.from("journal_entries")
            .insert(entry)
            .execute()
    }

    func fetchEntries(limit: Int = 50) async throws -> [JournalEntryDTO] {
        let response: [JournalEntryDTO] = try await client.from("journal_entries")
            .select()
            .eq("is_deleted", value: false)
            .order("timestamp", ascending: false)
            .limit(limit)
            .execute()
            .value

        return response
    }
}

// MARK: - DTO

struct JournalEntryDTO: Codable {
    var id: String?
    let content: String
    let timestamp: String
    let source: String
    let device_id: String?

    init(
        id: String? = nil,
        content: String,
        timestamp: String,
        source: String,
        device_id: String? = nil
    ) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.source = source
        self.device_id = device_id
    }
}
