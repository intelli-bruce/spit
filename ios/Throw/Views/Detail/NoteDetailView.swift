import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var note: Note
    @State private var viewModel = NoteDetailViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        mainNoteSection

                        if note.hasThreads {
                            threadSection
                        }
                    }
                    .padding()
                }
                .onChange(of: note.blocks.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            NoteInputBar(viewModel: viewModel, note: note)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await viewModel.syncNote(note, context: modelContext)
                    }
                } label: {
                    if viewModel.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: viewModel.syncSuccess ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(viewModel.isSyncing)
            }
        }
        .alert("동기화 실패", isPresented: .constant(viewModel.syncError != nil)) {
            Button("확인") {
                viewModel.resetSyncState()
            }
        } message: {
            Text(viewModel.syncError ?? "")
        }
        .onDisappear {
            viewModel.stopPlayback()
        }
    }

    private var mainNoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(note.rootBlocks) { block in
                BlockView(block: block, viewModel: viewModel)
            }

            Text(note.createdAt.relativeTimeString)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !note.tags.isEmpty {
                tagsView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tagsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(note.tags) { tag in
                    Text("#\(tag.name)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.2), in: Capsule())
                }
            }
        }
    }

    private var threadSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(note.blocks.filter { $0.parentBlock != nil }.sorted(by: { $0.createdAt < $1.createdAt })) { block in
                ThreadBlockView(block: block, viewModel: viewModel)
                    .padding(.vertical, 8)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.deleteBlock(block, from: note, context: modelContext)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
            }

            Color.clear
                .frame(height: 1)
                .id("bottom")
        }
        .padding(.top, 8)
    }
}

// MARK: - Block View

struct BlockView: View {
    let block: NoteBlock
    let viewModel: NoteDetailViewModel

    var body: some View {
        switch block.type {
        case .text:
            Text(block.content ?? "")
                .font(.body)

        case .audio:
            AudioBlockView(block: block, viewModel: viewModel)

        case .image:
            if let url = block.localMediaURL ?? block.remoteMediaURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                } placeholder: {
                    ProgressView()
                }
                .frame(maxHeight: 200)
            }

        case .video:
            // Video player placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.2))
                .frame(height: 150)
                .overlay {
                    Image(systemName: "play.circle")
                        .font(.largeTitle)
                }
        }
    }
}

struct AudioBlockView: View {
    let block: NoteBlock
    let viewModel: NoteDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    if let url = block.localMediaURL {
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

                StaticWaveformView(audioURL: block.localMediaURL)
                    .frame(height: 30)

                Button {
                    viewModel.cyclePlaybackRate()
                } label: {
                    Text("\(String(format: "%.1f", viewModel.playbackRate))x")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if let content = block.content, !content.isEmpty {
                Text(content)
                    .font(.body)
                    .foregroundStyle(.primary)
            } else {
                Text("변환 중...")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ThreadBlockView: View {
    let block: NoteBlock
    let viewModel: NoteDetailViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 4) {
                BlockView(block: block, viewModel: viewModel)

                Text(block.createdAt.relativeTimeString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.leading, 12)
    }
}

// MARK: - Input Bar

struct NoteInputBar: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: NoteDetailViewModel
    let note: Note

    var body: some View {
        HStack(spacing: 12) {
            TextField("추가 메모...", text: $viewModel.textInput, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)

            if viewModel.isRecordingThread {
                Button {
                    viewModel.cancelRecordingThread()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }

                Text(viewModel.formattedRecordingTime)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.red)

                Button {
                    Task {
                        await viewModel.stopRecordingThread(to: note, context: modelContext)
                    }
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title2)
                }
            } else {
                Button {
                    viewModel.startRecordingThread()
                } label: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(Color.accentColor)
                }

                Button {
                    viewModel.addTextBlock(to: note, context: modelContext)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.textInput.isEmpty ? .secondary : Color.accentColor)
                }
                .disabled(viewModel.textInput.isEmpty)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

#Preview {
    NavigationStack {
        NoteDetailView(note: {
            let note = Note()
            let block = NoteBlock(note: note, type: .text, content: "테스트 노트입니다.")
            note.blocks.append(block)
            return note
        }())
    }
    .modelContainer(for: [Note.self, NoteBlock.self, Tag.self], inMemory: true)
}
