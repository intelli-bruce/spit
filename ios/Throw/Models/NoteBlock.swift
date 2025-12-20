import Foundation
import SwiftData

@Model
final class NoteBlock {
    @Attribute(.unique) var id: UUID
    var note: Note?
    var parentBlock: NoteBlock?
    var type: BlockType
    var content: String?
    var storagePath: String?
    var position: Int
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var syncStatus: SyncStatus

    @Relationship(deleteRule: .cascade, inverse: \NoteBlock.parentBlock)
    var childBlocks: [NoteBlock]

    init(
        id: UUID = UUID(),
        note: Note? = nil,
        parentBlock: NoteBlock? = nil,
        type: BlockType = .text,
        content: String? = nil,
        storagePath: String? = nil,
        position: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        version: Int = 1,
        syncStatus: SyncStatus = .pending,
        childBlocks: [NoteBlock] = []
    ) {
        self.id = id
        self.note = note
        self.parentBlock = parentBlock
        self.type = type
        self.content = content
        self.storagePath = storagePath
        self.position = position
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.syncStatus = syncStatus
        self.childBlocks = childBlocks
    }

    // MARK: - Computed Properties

    /// Thread 여부
    var isThread: Bool {
        parentBlock != nil
    }

    /// 미디어 파일 로컬 URL
    var localMediaURL: URL? {
        guard let path = storagePath, type != .text else { return nil }

        // 로컬 임시 파일
        if path.hasPrefix("local://") {
            let fileName = path.replacingOccurrences(of: "local://", with: "")
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)
        }

        // Supabase Storage 경로 → 로컬 캐시
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cacheDir.appendingPathComponent(path)
    }

    /// Supabase Storage URL
    var remoteMediaURL: URL? {
        guard let path = storagePath, type != .text, !path.hasPrefix("local://") else {
            return nil
        }
        // Config.supabaseURL + /storage/v1/object/public/throw-media/ + path
        return URL(string: "\(Config.supabaseURL)/storage/v1/object/public/throw-media/\(path)")
    }

    /// 정렬된 child 블록
    var sortedChildBlocks: [NoteBlock] {
        childBlocks.sorted { $0.position < $1.position }
    }

    /// 텍스트 미리보기 (첫 줄)
    var preview: String {
        guard type == .text, let content = content else {
            return type.displayName
        }
        return content.components(separatedBy: .newlines).first ?? ""
    }
}

// MARK: - BlockType

enum BlockType: String, Codable, CaseIterable {
    case text
    case image
    case audio
    case video

    var displayName: String {
        switch self {
        case .text: return "텍스트"
        case .image: return "이미지"
        case .audio: return "오디오"
        case .video: return "비디오"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "video"
        }
    }
}
