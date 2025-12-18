import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Memo.createdAt, order: .reverse) private var memos: [Memo]

    @Binding var shouldStartRecording: Bool

    @State private var viewModel = HomeViewModel()
    @State private var recordingViewModel = RecordingViewModel()
    @State private var selectedMemo: Memo?
    @State private var showPermissionAlert = false

    init(shouldStartRecording: Binding<Bool> = .constant(false)) {
        _shouldStartRecording = shouldStartRecording
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if memos.isEmpty {
                    EmptyStateView()
                } else {
                    memoList
                }

                VStack {
                    Spacer()
                    RecordButton(viewModel: recordingViewModel) {
                        handleRecordingComplete($0)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Drops")
            .navigationDestination(item: $selectedMemo) { memo in
                MemoDetailView(memo: memo)
            }
            .overlay(alignment: .bottom) {
                if viewModel.showUndoToast {
                    undoToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 100)
                }
            }
            .animation(.easeInOut, value: viewModel.showUndoToast)
            .onChange(of: shouldStartRecording) { _, newValue in
                if newValue {
                    startRecordingFromWidget()
                }
            }
            .onAppear {
                if shouldStartRecording {
                    startRecordingFromWidget()
                }
            }
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

    private var memoList: some View {
        List {
            ForEach(memos) { memo in
                MemoCell(memo: memo)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMemo = memo
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteMemo(memo, context: modelContext)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    private var undoToast: some View {
        HStack {
            Text("메모가 삭제되었습니다")
                .font(.subheadline)

            Spacer()

            Button("실행 취소") {
                viewModel.undoDelete(context: modelContext)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding()
        .glassEffect()
        .padding(.horizontal)
    }

    private func handleRecordingComplete(_ memo: Memo) {
        Task {
            await viewModel.processSTT(for: memo, context: modelContext)
        }
    }

    private func startRecordingFromWidget() {
        shouldStartRecording = false

        guard !recordingViewModel.isRecording else { return }

        Task {
            if recordingViewModel.checkPermission() {
                // 약간의 딜레이를 주어 UI가 준비된 후 녹음 시작
                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    recordingViewModel.startRecording()
                }
            } else {
                let granted = await recordingViewModel.requestPermission()
                if granted {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await MainActor.run {
                        recordingViewModel.startRecording()
                    }
                } else {
                    await MainActor.run {
                        showPermissionAlert = true
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Memo.self, ThreadItem.self], inMemory: true)
}
