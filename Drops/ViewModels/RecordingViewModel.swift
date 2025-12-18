import Foundation
import SwiftData
import SwiftUI

@Observable
final class RecordingViewModel {
    let audioRecorder = AudioRecorder()

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

    func toggleRecording(context: ModelContext, onComplete: @escaping (Memo) -> Void) {
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

    func stopRecording(context: ModelContext, onComplete: @escaping (Memo) -> Void) {
        guard let audioURL = audioRecorder.stopRecording() else { return }

        HapticManager.recordingStop()

        let memo = Memo(
            text: "",
            audioFileName: audioURL.lastPathComponent,
            sttStatus: .pending
        )

        context.insert(memo)
        try? context.save()

        onComplete(memo)
    }

    func cancelRecording() {
        audioRecorder.cancelRecording()
    }
}
