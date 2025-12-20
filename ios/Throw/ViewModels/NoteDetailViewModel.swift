import Foundation
import SwiftData
import SwiftUI

@Observable
final class NoteDetailViewModel {
    let audioPlayer = AudioPlayer()
    let audioRecorder = AudioRecorder()
    private let whisperService = WhisperService()

    var isRecordingThread = false
    var textInput = ""
    var playbackRate: Float = 1.0
    var isSyncing = false
    var syncError: String?
    var syncSuccess = false

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

    // MARK: - Text Block

    func addTextBlock(to note: Note, context: ModelContext) {
        guard !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let block = NoteBlock(
            note: note,
            type: .text,
            content: textInput.trimmingCharacters(in: .whitespacesAndNewlines),
            position: note.blocks.count
        )

        note.blocks.append(block)
        note.updatedAt = Date()
        textInput = ""

        try? context.save()
    }

    // MARK: - Thread (Reply Block)

    func addTextThread(to parentBlock: NoteBlock, note: Note, context: ModelContext) {
        guard !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let thread = NoteBlock(
            note: note,
            parentBlock: parentBlock,
            type: .text,
            content: textInput.trimmingCharacters(in: .whitespacesAndNewlines),
            position: parentBlock.childBlocks.count
        )

        parentBlock.childBlocks.append(thread)
        note.updatedAt = Date()
        textInput = ""

        try? context.save()
    }

    // MARK: - Audio Recording

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

    func stopRecordingThread(to note: Note, parentBlock: NoteBlock? = nil, context: ModelContext) async {
        guard let audioURL = audioRecorder.stopRecording() else { return }

        HapticManager.recordingStop()
        isRecordingThread = false

        let block = NoteBlock(
            note: note,
            parentBlock: parentBlock,
            type: .audio,
            storagePath: "local://\(audioURL.lastPathComponent)",
            position: parentBlock?.childBlocks.count ?? note.blocks.count
        )

        if let parentBlock = parentBlock {
            parentBlock.childBlocks.append(block)
        } else {
            note.blocks.append(block)
        }
        note.updatedAt = Date()

        try? context.save()

        await processBlockSTT(block, context: context)
    }

    func cancelRecordingThread() {
        audioRecorder.cancelRecording()
        isRecordingThread = false
    }

    // MARK: - Block Management

    func deleteBlock(_ block: NoteBlock, from note: Note, context: ModelContext) {
        // Delete local audio file if exists
        if block.type == .audio, let storagePath = block.storagePath, storagePath.hasPrefix("local://") {
            let fileName = storagePath.replacingOccurrences(of: "local://", with: "")
            AudioRecorder.deleteAudioFile(named: fileName)
        }

        // Remove from parent or note
        if let parentBlock = block.parentBlock {
            parentBlock.childBlocks.removeAll { $0.id == block.id }
        } else {
            note.blocks.removeAll { $0.id == block.id }
        }

        note.updatedAt = Date()
        context.delete(block)

        try? context.save()
    }

    func updateBlockContent(_ block: NoteBlock, content: String, context: ModelContext) {
        block.content = content
        block.updatedAt = Date()
        block.version += 1
        block.syncStatus = .pending

        try? context.save()
    }

    // MARK: - STT

    func retrySTT(for block: NoteBlock, context: ModelContext) async {
        await processBlockSTT(block, context: context)
    }

    private func processBlockSTT(_ block: NoteBlock, context: ModelContext) async {
        guard block.type == .audio, let audioURL = block.localMediaURL else { return }

        do {
            let text = try await whisperService.transcribe(audioURL: audioURL)
            block.content = text.isEmpty ? "" : text
            block.updatedAt = Date()
            HapticManager.success()
        } catch {
            print("Block STT failed: \(error)")
            HapticManager.error()
        }

        try? context.save()
    }

    // MARK: - Sync

    func syncNote(_ note: Note, context: ModelContext) async {
        isSyncing = true
        syncError = nil
        syncSuccess = false

        do {
            // Sync note
            if note.syncStatus == .pending {
                _ = try await SupabaseService.shared.createNote(note: note)
                note.syncStatus = .synced
            }

            // Sync blocks
            for block in note.blocks where block.syncStatus == .pending {
                _ = try await SupabaseService.shared.createBlock(block: block, noteId: note.id)
                block.syncStatus = .synced

                // Upload media if needed
                if block.type != .text, let storagePath = block.storagePath, storagePath.hasPrefix("local://") {
                    await uploadMedia(for: block, noteId: note.id)
                }
            }

            try? context.save()
            syncSuccess = true
            HapticManager.success()
        } catch {
            print("Sync failed: \(error)")
            syncError = error.localizedDescription
            HapticManager.error()
        }

        isSyncing = false
    }

    private func uploadMedia(for block: NoteBlock, noteId: UUID) async {
        guard let localURL = block.localMediaURL,
              let data = try? Data(contentsOf: localURL) else { return }

        let remotePath = "notes/\(noteId.uuidString)/\(block.id.uuidString)_\(block.type.rawValue)"
        let contentType = block.type == .audio ? "audio/m4a" : "application/octet-stream"

        do {
            let path = try await SupabaseService.shared.uploadMedia(data: data, path: remotePath, contentType: contentType)
            block.storagePath = path
        } catch {
            print("Media upload failed: \(error)")
        }
    }

    func resetSyncState() {
        syncError = nil
        syncSuccess = false
    }
}
