import Foundation
import SwiftData

@Model
final class Memo {
    @Attribute(.unique) var id: UUID
    var text: String
    var audioFileName: String?
    var createdAt: Date
    var updatedAt: Date
    var sttStatus: STTStatus

    @Relationship(deleteRule: .cascade, inverse: \ThreadItem.memo)
    var threads: [ThreadItem]

    init(
        id: UUID = UUID(),
        text: String = "",
        audioFileName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sttStatus: STTStatus = .completed,
        threads: [ThreadItem] = []
    ) {
        self.id = id
        self.text = text
        self.audioFileName = audioFileName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sttStatus = sttStatus
        self.threads = threads
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
        if text.isEmpty {
            switch sttStatus {
            case .pending, .processing:
                return "변환 중..."
            case .failed:
                return "텍스트 변환 실패"
            case .completed:
                return "내용 없음"
            }
        }
        return text
    }

    var threadCount: Int {
        threads.count
    }
}

enum STTStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed
}
