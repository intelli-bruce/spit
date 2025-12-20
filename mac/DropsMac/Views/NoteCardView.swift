import SwiftUI

struct NoteCardView: View {
    let note: JournalNote
    let isSelected: Bool
    let isEditing: Bool
    @ObservedObject var vimEngine: VimEngine
    @Binding var editContent: String

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(note.timeString)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Spacer()

                if isEditing {
                    // Vim mode indicator
                    Text(vimEngine.mode.rawValue)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(modeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(modeColor.opacity(0.15))
                        .cornerRadius(3)
                }
            }

            // Content
            if isEditing {
                MarkdownTextView(
                    text: $editContent,
                    vimEngine: vimEngine,
                    fontSize: 13,
                    startInInsertMode: true,
                    onTextChange: {}
                )
                .frame(minHeight: 100)
            } else {
                Text(note.content.isEmpty ? "Empty note - press Enter to edit" : note.content)
                    .font(.system(size: 13))
                    .foregroundStyle(note.content.isEmpty ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(cardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var cardBackground: Color {
        if isEditing {
            return Color(nsColor: .controlBackgroundColor)
        } else if isSelected {
            return Color.accentColor.opacity(0.08)
        } else if isHovering {
            return Color(nsColor: .controlBackgroundColor).opacity(0.5)
        } else {
            return Color.clear
        }
    }

    private var borderColor: Color {
        if isEditing {
            return Color.accentColor
        } else if isSelected {
            return Color.accentColor.opacity(0.6)
        } else {
            return Color.secondary.opacity(0.15)
        }
    }

    private var modeColor: Color {
        switch vimEngine.mode {
        case .normal: return .blue
        case .insert: return .green
        case .visual, .visualLine: return .purple
        case .command: return .orange
        case .operatorPending: return .yellow
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        NoteCardView(
            note: JournalNote(content: "Normal note", timestamp: Date()),
            isSelected: false,
            isEditing: false,
            vimEngine: VimEngine(),
            editContent: .constant("")
        )

        NoteCardView(
            note: JournalNote(content: "Selected note", timestamp: Date()),
            isSelected: true,
            isEditing: false,
            vimEngine: VimEngine(),
            editContent: .constant("")
        )
    }
    .padding()
    .frame(width: 400)
}
