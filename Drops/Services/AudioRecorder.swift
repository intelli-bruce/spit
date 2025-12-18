import AVFoundation
import Foundation

@Observable
final class AudioRecorder: NSObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var meteringTimer: Timer?

    var isRecording = false
    var recordingTime: TimeInterval = 0
    var currentLevel: Float = 0
    var audioLevels: [Float] = []

    private(set) var currentRecordingURL: URL?

    private let maxDuration = Config.maxRecordingDuration

    override init() {
        super.init()
    }

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func checkPermission() -> Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let fileName = "\(UUID().uuidString).m4a"
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: Config.audioSampleRate,
            AVNumberOfChannelsKey: Config.audioChannels,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        currentRecordingURL = fileURL
        isRecording = true
        recordingTime = 0
        audioLevels = []

        startTimers()

        return fileURL
    }

    func stopRecording() -> URL? {
        stopTimers()

        audioRecorder?.stop()
        isRecording = false

        let url = currentRecordingURL
        currentRecordingURL = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }

        return url
    }

    func cancelRecording() {
        stopTimers()

        if let url = currentRecordingURL {
            audioRecorder?.stop()
            try? FileManager.default.removeItem(at: url)
        }

        isRecording = false
        currentRecordingURL = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }

    private func startTimers() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.recordingTime += 1

            if self.recordingTime >= self.maxDuration {
                _ = self.stopRecording()
            }
        }

        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            let level = recorder.averagePower(forChannel: 0)
            let normalizedLevel = max(0, (level + 60) / 60)
            self.currentLevel = normalizedLevel
            self.audioLevels.append(normalizedLevel)

            if self.audioLevels.count > 50 {
                self.audioLevels.removeFirst()
            }
        }
    }

    private func stopTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        meteringTimer?.invalidate()
        meteringTimer = nil
    }

    var formattedTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var remainingTime: TimeInterval {
        max(0, maxDuration - recordingTime)
    }

    static func deleteAudioFile(named fileName: String) {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording finished unsuccessfully")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording encode error: \(error)")
        }
    }
}
