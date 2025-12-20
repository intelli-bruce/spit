import Foundation

actor JournalSyncService {
    static let shared = JournalSyncService()

    private let supabase = SupabaseService.shared

    enum SyncError: LocalizedError {
        case emptyContent
        case networkError(Error)
        case invalidConfiguration

        var errorDescription: String? {
            switch self {
            case .emptyContent:
                return "내용이 비어있습니다."
            case .networkError(let error):
                return "네트워크 오류: \(error.localizedDescription)"
            case .invalidConfiguration:
                return "Supabase 설정을 확인해주세요."
            }
        }
    }

    func sendMemoToJournal(_ memo: Memo) async throws {
        let content = formatMemoForJournal(memo)

        guard !content.isEmpty else {
            throw SyncError.emptyContent
        }

        guard Config.supabaseURL != "https://YOUR_PROJECT.supabase.co" else {
            throw SyncError.invalidConfiguration
        }

        do {
            try await supabase.appendToJournal(content: content)
        } catch {
            throw SyncError.networkError(error)
        }
    }

    private func formatMemoForJournal(_ memo: Memo) -> String {
        var parts: [String] = []

        // Main memo text
        if !memo.text.isEmpty {
            parts.append(memo.text)
        }

        // Thread contents
        let sortedThreads = memo.threads.sorted { $0.createdAt < $1.createdAt }
        for thread in sortedThreads {
            if let content = thread.content, !content.isEmpty {
                parts.append("- \(content)")
            }
        }

        return parts.joined(separator: "\n\n")
    }

    func formatMemoWithMetadata(_ memo: Memo) -> String {
        var lines: [String] = []

        // Source info
        lines.append("**Source:** Drops iOS")
        lines.append("**Created:** \(memo.createdAt.formatted())")

        // Main content
        if !memo.text.isEmpty {
            lines.append("")
            lines.append(memo.text)
        }

        // Threads
        if !memo.threads.isEmpty {
            lines.append("")
            lines.append("### Threads")

            let sortedThreads = memo.threads.sorted { $0.createdAt < $1.createdAt }
            for thread in sortedThreads {
                if let content = thread.content, !content.isEmpty {
                    let typeEmoji = thread.type == .audio ? "🎤" : "💬"
                    lines.append("- \(typeEmoji) \(content)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}
