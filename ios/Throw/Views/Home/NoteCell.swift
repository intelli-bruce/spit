import SwiftUI

struct NoteCell: View {
    let note: Note

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if note.hasMedia {
                        Image(systemName: hasAudio ? "waveform" : "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                Text(displayText)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(note.preview.isEmpty ? .secondary : .primary)

                HStack(spacing: 8) {
                    Text(note.createdAt.smartDateString)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if note.hasThreads {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.caption2)
                            Text("\(threadCount)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    if !note.tags.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "tag")
                                .font(.caption2)
                            Text("\(note.tags.count)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }

    private var hasAudio: Bool {
        note.blocks.contains { $0.type == .audio }
    }

    private var isProcessing: Bool {
        note.blocks.contains { $0.type == .audio && $0.content == nil }
    }

    private var displayText: String {
        let textContent = note.preview
        if !textContent.isEmpty {
            return textContent
        }

        if hasAudio {
            if isProcessing {
                return "변환 중..."
            }
            return note.blocks.first(where: { $0.type == .audio })?.content ?? "음성 메모"
        }

        return "새 노트"
    }

    private var threadCount: Int {
        note.blocks.filter { $0.parentBlock != nil }.count
    }
}

#Preview {
    List {
        NoteCell(note: {
            let note = Note()
            let block = NoteBlock(note: note, type: .text, content: "안녕하세요, 이것은 테스트 노트입니다.")
            note.blocks.append(block)
            return note
        }())

        NoteCell(note: {
            let note = Note()
            let block = NoteBlock(note: note, type: .audio, storagePath: "local://test.m4a")
            note.blocks.append(block)
            return note
        }())
    }
    .listStyle(.plain)
}
