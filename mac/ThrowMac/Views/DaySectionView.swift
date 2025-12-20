import SwiftUI

struct DaySectionView: View {
    let dayGroup: DayGroup
    let selectedNoteId: UUID?
    let editingNoteId: UUID?
    @ObservedObject var vimEngine: VimEngine
    @Binding var editContent: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day header
            HStack(spacing: 8) {
                Text(dayGroup.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 1)
            }

            // Notes in this day
            ForEach(dayGroup.notes) { note in
                NoteCardView(
                    note: note,
                    isSelected: selectedNoteId == note.id,
                    isEditing: editingNoteId == note.id,
                    vimEngine: vimEngine,
                    editContent: $editContent
                )
            }
        }
    }
}

#Preview {
    let notes = [
        JournalNote(content: "First note", timestamp: Date()),
        JournalNote(content: "Second note", timestamp: Date().addingTimeInterval(-3600)),
    ]

    DaySectionView(
        dayGroup: DayGroup(id: "2024-12-19", date: Date(), notes: notes),
        selectedNoteId: nil,
        editingNoteId: nil,
        vimEngine: VimEngine(),
        editContent: .constant("")
    )
    .padding()
    .frame(width: 500)
}
