import SwiftUI
import SwiftData

struct InputBar: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: MemoDetailViewModel
    let memo: Memo

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            if viewModel.isRecordingThread {
                recordingView
            } else {
                textInputView
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private var textInputView: some View {
        HStack(spacing: 12) {
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
                    Image(systemName: "mic.circle.fill")
                        .font(.title)
                        .foregroundStyle(Color.accentColor)
                }
            } else {
                Button {
                    sendTextMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private var recordingView: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.cancelRecordingThread()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            WaveformView(levels: viewModel.audioRecorder.audioLevels)
                .frame(height: 30)

            Text(viewModel.formattedRecordingTime)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                stopRecording()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.title)
                    .foregroundStyle(.red)
            }
        }
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
