import Foundation
import SwiftData
import SwiftUI

@Observable
final class HomeViewModel {
    var deletedNote: Note?
    var showUndoToast = false

    private var undoTimer: Timer?
    private let whisperService = WhisperService()

    func deleteNote(_ note: Note, context: ModelContext) {
        deletedNote = note
        context.delete(note)

        showUndoToast = true

        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.confirmDelete()
        }
    }

    func undoDelete(context: ModelContext) {
        guard let note = deletedNote else { return }

        undoTimer?.invalidate()
        undoTimer = nil

        context.insert(note)
        deletedNote = nil
        showUndoToast = false
    }

    func confirmDelete() {
        if let note = deletedNote {
            // Delete local audio files
            for block in note.blocks where block.type == .audio {
                if let storagePath = block.storagePath, storagePath.hasPrefix("local://") {
                    let fileName = storagePath.replacingOccurrences(of: "local://", with: "")
                    AudioRecorder.deleteAudioFile(named: fileName)
                }
            }
        }

        deletedNote = nil
        showUndoToast = false
        undoTimer?.invalidate()
        undoTimer = nil
    }

    func processSTT(for block: NoteBlock, context: ModelContext) async {
        guard block.type == .audio, let audioURL = block.localMediaURL else { return }

        block.syncStatus = .pending

        do {
            let text = try await whisperService.transcribe(audioURL: audioURL)
            // Create a text block with the transcribed content
            block.content = text.isEmpty ? "" : text
            block.updatedAt = Date()
        } catch {
            print("STT failed: \(error)")
        }

        try? context.save()
    }

    // MARK: - Sync

    func syncPendingNotes(context: ModelContext) async {
        let pendingStatus = SyncStatus.pending
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.syncStatus == pendingStatus }
        )

        guard let pendingNotes = try? context.fetch(descriptor) else { return }

        for note in pendingNotes {
            await syncNote(note, context: context)
        }
    }

    private func syncNote(_ note: Note, context: ModelContext) async {
        do {
            _ = try await SupabaseService.shared.createNote(note: note)
            note.syncStatus = .synced

            // Sync blocks
            for block in note.blocks {
                _ = try await SupabaseService.shared.createBlock(block: block, noteId: note.id)
                block.syncStatus = .synced
            }

            try? context.save()
        } catch {
            print("Sync failed: \(error)")
        }
    }
}
