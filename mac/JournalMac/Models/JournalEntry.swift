import Foundation

struct JournalEntry: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var content: String
    var timestamp: Date
    var source: EntrySource
    var deviceId: String?
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var version: Int

    init(
        id: UUID = UUID(),
        content: String,
        timestamp: Date = Date(),
        source: EntrySource = .mac,
        deviceId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDeleted: Bool = false,
        version: Int = 1
    ) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.source = source
        self.deviceId = deviceId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.version = version
    }
}

enum EntrySource: String, Codable, CaseIterable {
    case mac = "mac"
    case ios = "ios"
    case manual = "manual"

    var displayName: String {
        switch self {
        case .mac: return "Mac"
        case .ios: return "iOS"
        case .manual: return "Manual"
        }
    }
}

struct JournalMetadata: Identifiable, Codable {
    let id: UUID
    var fullContent: String
    var contentHash: String
    var lastSyncAt: Date
    var version: Int

    init(
        id: UUID = UUID(),
        fullContent: String,
        contentHash: String = "",
        lastSyncAt: Date = Date(),
        version: Int = 1
    ) {
        self.id = id
        self.fullContent = fullContent
        self.contentHash = contentHash
        self.lastSyncAt = lastSyncAt
        self.version = version
    }
}
