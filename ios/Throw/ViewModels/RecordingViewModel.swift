import Foundation
import SwiftData
import SwiftUI

@Observable
final class RecordingViewModel {
    let audioRecorder = AudioRecorder()
    private let whisperService = WhisperService()

    var isRecording: Bool {
        audioRecorder.isRecording
    }

    var recordingTime: TimeInterval {
        audioRecorder.recordingTime
    }

    var formattedTime: String {
        audioRecorder.formattedTime
    }

    var currentLevel: Float {
        audioRecorder.currentLevel
    }

    var audioLevels: [Float] {
        audioRecorder.audioLevels
    }

    func checkPermission() -> Bool {
        audioRecorder.checkPermission()
    }

    func requestPermission() async -> Bool {
        await audioRecorder.requestPermission()
    }

    func toggleRecording(context: ModelContext, onComplete: @escaping (Note) -> Void) {
        if isRecording {
            stopRecording(context: context, onComplete: onComplete)
        } else {
            startRecording()
        }
    }

    func startRecording() {
        do {
            _ = try audioRecorder.startRecording()
            HapticManager.recordingStart()
        } catch {
            print("Failed to start recording: \(error)")
            HapticManager.error()
        }
    }

    func stopRecording(context: ModelContext, onComplete: @escaping (Note) -> Void) {
        guard let audioURL = audioRecorder.stopRecording() else { return }

        HapticManager.recordingStop()

        // Create note with audio block
        let note = Note()

        let audioBlock = NoteBlock(
            note: note,
            type: .audio,
            storagePath: "local://\(audioURL.lastPathComponent)",
            position: 0
        )

        note.blocks.append(audioBlock)

        context.insert(note)
        try? context.save()

        onComplete(note)

        // Process STT in background
        Task {
            await processSTT(for: audioBlock, context: context)
        }
    }

    func cancelRecording() {
        audioRecorder.cancelRecording()
    }

    // MARK: - Text Note

    func createTextNote(text: String, context: ModelContext) -> Note? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return nil }

        let note = Note()

        let textBlock = NoteBlock(
            note: note,
            type: .text,
            content: trimmedText,
            position: 0
        )

        note.blocks.append(textBlock)

        context.insert(note)
        try? context.save()

        return note
    }

    // MARK: - STT

    private func processSTT(for block: NoteBlock, context: ModelContext) async {
        guard block.type == .audio, let audioURL = block.localMediaURL else { return }

        do {
            let text = try await whisperService.transcribe(audioURL: audioURL)
            block.content = text.isEmpty ? "" : text
            block.updatedAt = Date()
            try? context.save()
        } catch {
            print("STT failed: \(error)")
        }
    }
}
