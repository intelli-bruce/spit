import Foundation

struct MarkdownParser {
    // MARK: - Parsing

    /// Parse Journal.md content into individual entries
    static func parseEntries(from content: String) -> [ParsedEntry] {
        var entries: [ParsedEntry] = []

        // Split by horizontal rule (---)
        let sections = content.components(separatedBy: "\n---\n")

        for section in sections {
            guard !section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            // Try to extract timestamp from header
            if let entry = parseSection(section) {
                entries.append(entry)
            }
        }

        return entries
    }

    private static func parseSection(_ section: String) -> ParsedEntry? {
        let lines = section.components(separatedBy: "\n")

        var timestamp: Date?
        var contentLines: [String] = []
        var foundHeader = false

        for line in lines {
            // Look for ## YYYY-MM-DD HH:mm:ss pattern
            if line.hasPrefix("## ") {
                let headerContent = String(line.dropFirst(3))
                if let date = parseTimestamp(headerContent) {
                    timestamp = date
                    foundHeader = true
                    continue
                }
            }

            if foundHeader || timestamp == nil {
                contentLines.append(line)
            }
        }

        let content = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // Only include entries with valid timestamp headers
        guard let ts = timestamp else { return nil }

        return ParsedEntry(
            timestamp: ts,
            content: content,
            rawSection: section
        )
    }

    private static func parseTimestamp(_ string: String) -> Date? {
        let formatters = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: string.trimmingCharacters(in: .whitespaces)) {
                return date
            }
        }

        return nil
    }

    // MARK: - Composing

    /// Compose entries back into Journal.md format
    static func composeDocument(entries: [JournalEntry]) -> String {
        var content = "# Journal\n"

        // Sort by timestamp descending (newest first)
        let sorted = entries.sorted { $0.timestamp > $1.timestamp }

        for entry in sorted {
            content += "\n---\n\n"
            content += "## \(formatTimestamp(entry.timestamp))\n\n"
            content += entry.content
            content += "\n"
        }

        return content
    }

    /// Append a single entry to existing content
    static func appendEntry(_ entry: JournalEntry, to content: String) -> String {
        var result = content.trimmingCharacters(in: .whitespacesAndNewlines)

        result += "\n\n---\n\n"
        result += "## \(formatTimestamp(entry.timestamp))\n\n"
        result += entry.content
        result += "\n"

        return result
    }

    private static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Parsed Entry

struct ParsedEntry {
    let timestamp: Date
    let content: String
    let rawSection: String

    func toJournalEntry(source: EntrySource = .manual) -> JournalEntry {
        JournalEntry(
            content: content,
            timestamp: timestamp,
            source: source
        )
    }
}
