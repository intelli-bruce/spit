import SwiftUI

struct SidebarView: View {
    let entries: [JournalEntry]
    @Binding var selectedEntry: JournalEntry?

    var body: some View {
        List(selection: $selectedEntry) {
            ForEach(groupedEntries, id: \.key) { group in
                Section(header: Text(group.key)) {
                    ForEach(group.entries) { entry in
                        EntryRow(entry: entry)
                            .tag(entry)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .navigationTitle("Journal")
    }

    private var groupedEntries: [(key: String, entries: [JournalEntry])] {
        let grouped = Dictionary(grouping: entries) { entry in
            formatDateKey(entry.timestamp)
        }

        return grouped.sorted { $0.key > $1.key }
            .map { (key: $0.key, entries: $0.value.sorted { $0.timestamp > $1.timestamp }) }
    }

    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct EntryRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatTime(entry.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                SourceBadge(source: entry.source)
            }

            Text(entry.content.prefix(100))
                .font(.body)
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct SourceBadge: View {
    let source: EntrySource

    var body: some View {
        Text(source.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch source {
        case .mac: return .blue
        case .ios: return .green
        case .manual: return .gray
        }
    }
}

#Preview {
    SidebarView(
        entries: [
            JournalEntry(content: "Test entry 1", source: .mac),
            JournalEntry(content: "Test entry 2", source: .ios),
        ],
        selectedEntry: .constant(nil)
    )
}
