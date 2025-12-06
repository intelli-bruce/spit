import Foundation

enum Config {
    // MARK: - OpenAI API
    static let openAIAPIKey = "YOUR_OPENAI_API_KEY"
    static let whisperEndpoint = "https://api.openai.com/v1/audio/transcriptions"
    static let whisperModel = "whisper-1"

    // MARK: - Recording
    static let maxRecordingDuration: TimeInterval = 180 // 3 minutes
    static let audioSampleRate: Double = 44100.0
    static let audioChannels: Int = 1

    // MARK: - App
    static let appGroupIdentifier = "group.com.intellieffect.spit"
}
