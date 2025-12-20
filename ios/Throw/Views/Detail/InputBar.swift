import SwiftUI
import SwiftData

struct InputBar: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: MemoDetailViewModel
    let memo: Memo

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isRecordingThread {
                recordingView
            } else {
                textInputView
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var textInputView: some View {
        HStack(spacing: 16) {
            TextField("메모 추가...", text: $viewModel.textInput, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isTextFieldFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendTextMessage()
                }

            if viewModel.textInput.isEmpty {
                Button {
                    startRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 56, height: 56)

                        Image(systemName: "mic.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .accentColor.opacity(0.3), radius: 8)
                }
            } else {
                Button {
                    sendTextMessage()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 56, height: 56)

                        Image(systemName: "arrow.up")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .accentColor.opacity(0.3), radius: 8)
                }
            }
        }
    }

    private var recordingView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                WaveformView(levels: viewModel.audioRecorder.audioLevels)
                    .frame(height: 40)

                Text(viewModel.formattedRecordingTime)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                Button {
                    viewModel.cancelRecordingThread()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 56, height: 56)

                        Image(systemName: "xmark")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    stopRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 56, height: 56)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 20, height: 20)
                    }
                    .shadow(color: .red.opacity(0.3), radius: 8)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func sendTextMessage() {
        viewModel.addTextThread(to: memo, context: modelContext)
        isTextFieldFocused = false
    }

    private func startRecording() {
        isTextFieldFocused = false
        viewModel.startRecordingThread()
    }

    private func stopRecording() {
        Task {
            await viewModel.stopRecordingThread(to: memo, context: modelContext)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        InputBar(viewModel: MemoDetailViewModel(), memo: Memo(text: "Test"))
    }
    .modelContainer(for: [Memo.self, ThreadItem.self], inMemory: true)
}
