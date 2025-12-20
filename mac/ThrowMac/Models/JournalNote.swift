import Foundation

/// A single note entry parsed from the journal markdown
struct JournalNote: Identifiable, Equatable {
    let id: UUID
    var content: String
    var timestamp: Date
    var rawMarkdown: String

    init(id: UUID = UUID(), content: String, timestamp: Date, rawMarkdown: String = "") {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.rawMarkdown = rawMarkdown.isEmpty ? content : rawMarkdown
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: timestamp)
    }

    var preview: String {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return lines.first ?? ""
    }
}

/// A group of notes for a single day
struct DayGroup: Identifiable {
    let id: String  // yyyy-MM-dd format
    let date: Date
    var notes: [JournalNote]

    var displayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"  // Day name
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd (EEE)"
            return formatter.string(from: date)
        }
    }
}
