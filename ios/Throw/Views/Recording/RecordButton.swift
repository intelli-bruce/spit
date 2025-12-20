import SwiftUI
import SwiftData

struct RecordButton: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: RecordingViewModel

    let onComplete: (Memo) -> Void

    @State private var showPermissionAlert = false

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.isRecording {
                recordingView
            }

            Button {
                handleTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : Color.accentColor)
                        .frame(width: 72, height: 72)

                    if viewModel.isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
                .shadow(color: (viewModel.isRecording ? Color.red : Color.accentColor).opacity(0.3), radius: 8)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.isRecording ? "녹음 중지" : "녹음 시작")
        }
        .alert("마이크 권한 필요", isPresented: $showPermissionAlert) {
            Button("설정으로 이동") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("음성 메모를 녹음하려면 마이크 권한이 필요합니다.")
        }
    }

    private var recordingView: some View {
        VStack(spacing: 8) {
            WaveformView(levels: viewModel.audioLevels)
                .frame(height: 40)
                .padding(.horizontal)

            Text(viewModel.formattedTime)
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .transition(.scale.combined(with: .opacity))
    }

    private func handleTap() {
        if viewModel.isRecording {
            viewModel.stopRecording(context: modelContext) { memo in
                onComplete(memo)
            }
        } else {
            Task {
                if viewModel.checkPermission() {
                    viewModel.startRecording()
                } else {
                    let granted = await viewModel.requestPermission()
                    if granted {
                        viewModel.startRecording()
                    } else {
                        showPermissionAlert = true
                    }
                }
            }
        }
    }
}

#Preview {
    RecordButton(viewModel: RecordingViewModel()) { _ in }
        .modelContainer(for: [Memo.self], inMemory: true)
}
