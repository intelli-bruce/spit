import Foundation
import SwiftData

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var source: String
    var deviceId: String?
    var isDeleted: Bool
    var syncStatus: SyncStatus

    @Relationship(deleteRule: .cascade, inverse: \NoteBlock.note)
    var blocks: [NoteBlock]

    @Relationship(inverse: \Tag.notes)
    var tags: [Tag]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: String = "ios",
        deviceId: String? = nil,
        isDeleted: Bool = false,
        syncStatus: SyncStatus = .pending,
        blocks: [NoteBlock] = [],
        tags: [Tag] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.deviceId = deviceId
        self.isDeleted = isDeleted
        self.syncStatus = syncStatus
        self.blocks = blocks
        self.tags = tags
    }

    // MARK: - Computed Properties

    /// 본문 블록만 (thread 제외)
    var rootBlocks: [NoteBlock] {
        blocks
            .filter { $0.parentBlock == nil }
            .sorted { $0.position < $1.position }
    }

    /// 첫 번째 텍스트 블록의 내용 (미리보기용)
    var preview: String {
        rootBlocks
            .first { $0.type == .text }?
            .content ?? ""
    }

    /// 첫 줄만 추출
    var title: String {
        let firstLine = preview.components(separatedBy: .newlines).first ?? ""
        return firstLine.isEmpty ? "새 노트" : firstLine
    }

    /// Thread가 있는지
    var hasThreads: Bool {
        blocks.contains { $0.parentBlock != nil }
    }

    /// 미디어 블록이 있는지
    var hasMedia: Bool {
        blocks.contains { $0.type != .text }
    }
}

// MARK: - Enums

enum SyncStatus: String, Codable {
    case pending
    case synced
    case conflict
}
