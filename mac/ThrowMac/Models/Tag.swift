import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String
    var createdAt: Date
    var syncStatus: SyncStatus

    var notes: [Note]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        syncStatus: SyncStatus = .pending,
        notes: [Note] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.syncStatus = syncStatus
        self.notes = notes
    }

    // MARK: - Computed Properties

    var noteCount: Int {
        notes.count
    }

    /// 태그 이름 정규화 (소문자, 공백 제거)
    var normalizedName: String {
        name.lowercased().trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Tag Utilities

extension Tag {
    /// 텍스트에서 #태그 추출
    static func extractTags(from text: String) -> [String] {
        let pattern = "#([\\w가-힣]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        return matches.compactMap { match -> String? in
            guard let tagRange = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[tagRange])
        }
    }
}
