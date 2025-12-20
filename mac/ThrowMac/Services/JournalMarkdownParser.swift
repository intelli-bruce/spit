import Foundation

/// Parser for converting Journal.md content to JournalNote objects
struct JournalMarkdownParser {
    /// Parse Journal.md content into JournalNote array
    static func parseEntries(from content: String) -> [JournalNote] {
        let parsed = MarkdownParser.parseEntries(from: content)
        return parsed.map { entry in
            JournalNote(
                content: entry.content,
                timestamp: entry.timestamp,
                rawMarkdown: entry.rawSection
            )
        }
    }

    /// Compose JournalNote array back to markdown
    static func compose(notes: [JournalNote]) -> String {
        var content = "# Journal\n"

        // Sort by timestamp descending (newest first)
        let sorted = notes.sorted { $0.timestamp > $1.timestamp }

        for note in sorted {
            content += "\n---\n\n"
            content += "## \(formatTimestamp(note.timestamp))\n\n"
            content += note.content
            content += "\n"
        }

        return content
    }

    private static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
