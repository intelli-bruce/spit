import Foundation
import SwiftData
import SwiftUI

@Observable
final class HomeViewModel {
    var deletedMemo: Memo?
    var showUndoToast = false

    private var undoTimer: Timer?
    private let whisperService = WhisperService()

    func deleteMemo(_ memo: Memo, context: ModelContext) {
        deletedMemo = memo
        context.delete(memo)

        showUndoToast = true

        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.confirmDelete()
        }
    }

    func undoDelete(context: ModelContext) {
        guard let memo = deletedMemo else { return }

        undoTimer?.invalidate()
        undoTimer = nil

        context.insert(memo)
        deletedMemo = nil
        showUndoToast = false
    }

    func confirmDelete() {
        if let memo = deletedMemo {
            if let audioFileName = memo.audioFileName {
                AudioRecorder.deleteAudioFile(named: audioFileName)
            }
            for thread in memo.threads {
                if let audioFileName = thread.audioFileName {
                    AudioRecorder.deleteAudioFile(named: audioFileName)
                }
            }
        }

        deletedMemo = nil
        showUndoToast = false
        undoTimer?.invalidate()
        undoTimer = nil
    }

    func processSTT(for memo: Memo, context: ModelContext) async {
        guard let audioURL = memo.audioURL else { return }

        memo.sttStatus = .processing

        do {
            let text = try await whisperService.transcribe(audioURL: audioURL)
            memo.text = text.isEmpty ? "" : text
            memo.sttStatus = .completed
            memo.updatedAt = Date()
        } catch {
            print("STT failed: \(error)")
            memo.sttStatus = .failed
        }

        try? context.save()
    }
}
