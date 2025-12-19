import Foundation
import SwiftData
import SwiftUI

@Observable
final class MemoDetailViewModel {
    let audioPlayer = AudioPlayer()
    let audioRecorder = AudioRecorder()
    private let whisperService = WhisperService()
    private let journalService = JournalSyncService.shared

    var isRecordingThread = false
    var textInput = ""
    var playbackRate: Float = 1.0
    var isSendingToJournal = false
    var journalSyncError: String?
    var journalSyncSuccess = false

    var isPlaying: Bool {
        audioPlayer.isPlaying
    }

    var currentPlaybackTime: String {
        audioPlayer.formattedCurrentTime
    }

    var playbackDuration: String {
        audioPlayer.formattedDuration
    }

    var playbackProgress: Double {
        audioPlayer.progress
    }

    var formattedRecordingTime: String {
        audioRecorder.formattedTime
    }

    func loadAudio(url: URL) {
        do {
            try audioPlayer.load(url: url)
        } catch {
            print("Failed to load audio: \(error)")
        }
    }

    func togglePlayback() {
        audioPlayer.togglePlayPause()
    }

    func stopPlayback() {
        audioPlayer.stop()
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        audioPlayer.setPlaybackRate(rate)
    }

    func cyclePlaybackRate() {
        switch playbackRate {
        case 1.0:
            setPlaybackRate(1.5)
        case 1.5:
            setPlaybackRate(2.0)
        default:
            setPlaybackRate(1.0)
        }
    }

    func addTextThread(to memo: Memo, context: ModelContext) {
        guard !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let thread = ThreadItem(
            type: .text,
            content: textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        memo.threads.append(thread)
        memo.updatedAt = Date()
        textInput = ""

        try? context.save()
    }

    func startRecordingThread() {
        do {
            _ = try audioRecorder.startRecording()
            isRecordingThread = true
            HapticManager.recordingStart()
        } catch {
            print("Failed to start recording: \(error)")
            HapticManager.error()
        }
    }

    func stopRecordingThread(to memo: Memo, context: ModelContext) async {
        guard let audioURL = audioRecorder.stopRecording() else { return }

        HapticManager.recordingStop()
        isRecordingThread = false

        let thread = ThreadItem(
            type: .audio,
            audioFileName: audioURL.lastPathComponent,
            sttStatus: .pending
        )

        memo.threads.append(thread)
        memo.updatedAt = Date()

        try? context.save()

        await processThreadSTT(thread, context: context)
    }

    func cancelRecordingThread() {
        audioRecorder.cancelRecording()
        isRecordingThread = false
    }

    func deleteThread(_ thread: ThreadItem, from memo: Memo, context: ModelContext) {
        if let audioFileName = thread.audioFileName {
            AudioRecorder.deleteAudioFile(named: audioFileName)
        }

        memo.threads.removeAll { $0.id == thread.id }
        memo.updatedAt = Date()
        context.delete(thread)

        try? context.save()
    }

    func retrySTT(for memo: Memo, context: ModelContext) async {
        guard let audioURL = memo.audioURL else { return }

        memo.sttStatus = .processing

        do {
            let text = try await whisperService.transcribe(audioURL: audioURL)
            memo.text = text.isEmpty ? "" : text
            memo.sttStatus = .completed
            memo.updatedAt = Date()
            HapticManager.success()
        } catch {
            print("STT retry failed: \(error)")
            memo.sttStatus = .failed
            HapticManager.error()
        }

        try? context.save()
    }

    func retryThreadSTT(_ thread: ThreadItem, context: ModelContext) async {
        await processThreadSTT(thread, context: context)
    }

    private func processThreadSTT(_ thread: ThreadItem, context: ModelContext) async {
        guard let audioURL = thread.audioURL else { return }

        thread.sttStatus = .processing

        do {
            let text = try await whisperService.transcribe(audioURL: audioURL)
            thread.content = text.isEmpty ? "" : text
            thread.sttStatus = .completed
        } catch {
            print("Thread STT failed: \(error)")
            thread.sttStatus = .failed
        }

        try? context.save()
    }

    // MARK: - Journal Sync

    func sendToJournal(_ memo: Memo) async {
        isSendingToJournal = true
        journalSyncError = nil
        journalSyncSuccess = false

        do {
            try await journalService.sendMemoToJournal(memo)
            journalSyncSuccess = true
            HapticManager.success()
        } catch {
            print("Journal sync failed: \(error)")
            journalSyncError = error.localizedDescription
            HapticManager.error()
        }

        isSendingToJournal = false
    }

    func resetJournalSyncState() {
        journalSyncError = nil
        journalSyncSuccess = false
    }
}
