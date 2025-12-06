import SwiftUI

struct ThreadBubble: View {
    let thread: ThreadItem
    @Bindable var viewModel: MemoDetailViewModel

    @State private var localPlayer = AudioPlayer()

    var body: some View {
        HStack {
            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Group {
                    if thread.type == .audio {
                        audioContent
                    } else {
                        textContent
                    }
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(thread.createdAt.relativeTimeString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: 280, alignment: .trailing)
        }
    }

    private var textContent: some View {
        Text(thread.content ?? "")
            .font(.body)
    }

    private var audioContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: localPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }

                StaticWaveformView(audioURL: thread.audioURL, barCount: 20)
                    .frame(width: 100, height: 24)

                Text(localPlayer.isPlaying ? localPlayer.formattedCurrentTime : localPlayer.formattedDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if thread.sttStatus == .completed, let content = thread.content, !content.isEmpty {
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if thread.sttStatus == .processing || thread.sttStatus == .pending {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("변환 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if thread.sttStatus == .failed {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("변환 실패")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func togglePlayback() {
        guard let url = thread.audioURL else { return }

        if !localPlayer.isPlaying && localPlayer.duration == 0 {
            do {
                try localPlayer.load(url: url)
            } catch {
                print("Failed to load audio: \(error)")
                return
            }
        }

        localPlayer.togglePlayPause()
    }
}

#Preview {
    VStack(spacing: 16) {
        ThreadBubble(
            thread: ThreadItem(type: .text, content: "텍스트 메시지입니다."),
            viewModel: MemoDetailViewModel()
        )

        ThreadBubble(
            thread: ThreadItem(type: .audio, audioFileName: "test.m4a", sttStatus: .completed),
            viewModel: MemoDetailViewModel()
        )
    }
    .padding()
}
