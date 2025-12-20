import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    @Binding var shouldStartRecording: Bool

    @State private var viewModel = HomeViewModel()
    @State private var recordingViewModel = RecordingViewModel()
    @State private var selectedNote: Note?
    @State private var showPermissionAlert = false

    init(shouldStartRecording: Binding<Bool> = .constant(false)) {
        _shouldStartRecording = shouldStartRecording
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if notes.isEmpty {
                    EmptyStateView()
                } else {
                    noteList
                }

                VStack {
                    Spacer()
                    RecordButton(viewModel: recordingViewModel) {
                        handleRecordingComplete($0)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Throw")
            .navigationDestination(item: $selectedNote) { note in
                NoteDetailView(note: note)
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

    private var noteList: some View {
        List {
            ForEach(notes.filter { !$0.isDeleted }) { note in
                NoteCell(note: note)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedNote = note
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteNote(note, context: modelContext)
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
            Text("노트가 삭제되었습니다")
                .font(.subheadline)

            Spacer()

            Button("실행 취소") {
                viewModel.undoDelete(context: modelContext)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func handleRecordingComplete(_ note: Note) {
        if let audioBlock = note.blocks.first(where: { $0.type == .audio }) {
            Task {
                await viewModel.processSTT(for: audioBlock, context: modelContext)
            }
        }
    }

    private func startRecordingFromWidget() {
        shouldStartRecording = false

        guard !recordingViewModel.isRecording else { return }

        Task {
            if recordingViewModel.checkPermission() {
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
        .modelContainer(for: [Note.self, NoteBlock.self, Tag.self], inMemory: true)
}
