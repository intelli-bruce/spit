import SwiftUI

struct MemoCell: View {
    let memo: Memo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if memo.hasAudio {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if memo.sttStatus == .processing || memo.sttStatus == .pending {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    if memo.sttStatus == .failed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Text(memo.displayText)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(memo.text.isEmpty ? .secondary : .primary)

                HStack(spacing: 8) {
                    Text(memo.createdAt.smartDateString)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if memo.threadCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.caption2)
                            Text("\(memo.threadCount)")
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
}

#Preview {
    List {
        MemoCell(memo: Memo(text: "안녕하세요, 이것은 테스트 메모입니다.", audioFileName: "test.m4a"))
        MemoCell(memo: Memo(text: "", audioFileName: "test.m4a", sttStatus: .processing))
        MemoCell(memo: Memo(text: "", audioFileName: "test.m4a", sttStatus: .failed))
        MemoCell(memo: Memo(text: "짧은 메모"))
    }
    .listStyle(.plain)
}
