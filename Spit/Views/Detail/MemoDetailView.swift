import SwiftUI
import SwiftData

struct MemoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var memo: Memo
    @State private var viewModel = MemoDetailViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        mainMemoSection

                        if !memo.threads.isEmpty {
                            threadSection
                        }
                    }
                    .padding()
                }
                .onChange(of: memo.threads.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            Divider()

            InputBar(viewModel: viewModel, memo: memo)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            viewModel.stopPlayback()
        }
    }

    private var mainMemoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if memo.hasAudio {
                audioPlayerView
            }

            if memo.sttStatus == .failed {
                retryButton
            } else {
                Text(memo.displayText)
                    .font(.body)
                    .foregroundStyle(memo.text.isEmpty ? .secondary : .primary)
            }

            Text(memo.createdAt.relativeTimeString)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var audioPlayerView: some View {
        HStack(spacing: 12) {
            Button {
                if let url = memo.audioURL {
                    if !viewModel.isPlaying {
                        viewModel.loadAudio(url: url)
                    }
                    viewModel.togglePlayback()
                }
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
            }

            StaticWaveformView(audioURL: memo.audioURL)
                .frame(height: 30)

            Button {
                viewModel.cyclePlaybackRate()
            } label: {
                Text("\(String(format: "%.1f", viewModel.playbackRate))x")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var retryButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("텍스트 변환 실패")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            Button {
                Task {
                    await viewModel.retrySTT(for: memo, context: modelContext)
                }
            } label: {
                Label("다시 시도", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
            }
        }
    }

    private var threadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(memo.threads.sorted(by: { $0.createdAt < $1.createdAt })) { thread in
                ThreadBubble(thread: thread, viewModel: viewModel)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteThread(thread, from: memo, context: modelContext)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
            }

            Color.clear
                .frame(height: 1)
                .id("bottom")
        }
    }
}

#Preview {
    NavigationStack {
        MemoDetailView(memo: Memo(text: "테스트 메모입니다.", audioFileName: "test.m4a"))
    }
    .modelContainer(for: [Memo.self, ThreadItem.self], inMemory: true)
}
