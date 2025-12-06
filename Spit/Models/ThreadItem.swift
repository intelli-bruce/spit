import Foundation
import SwiftData

@Model
final class ThreadItem {
    @Attribute(.unique) var id: UUID
    var type: ThreadItemType
    var content: String?
    var audioFileName: String?
    var createdAt: Date
    var sttStatus: STTStatus

    var memo: Memo?

    init(
        id: UUID = UUID(),
        type: ThreadItemType,
        content: String? = nil,
        audioFileName: String? = nil,
        createdAt: Date = Date(),
        sttStatus: STTStatus = .completed
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.audioFileName = audioFileName
        self.createdAt = createdAt
        self.sttStatus = sttStatus
    }

    var hasAudio: Bool {
        audioFileName != nil
    }

    var audioURL: URL? {
        guard let fileName = audioFileName else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    var displayText: String {
        if let content = content, !content.isEmpty {
            return content
        }
        switch sttStatus {
        case .pending, .processing:
            return "변환 중..."
        case .failed:
            return "텍스트 변환 실패"
        case .completed:
            return "내용 없음"
        }
    }
}

enum ThreadItemType: String, Codable {
    case text
    case audio
}
