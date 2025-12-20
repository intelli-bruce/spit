import Foundation
import UIKit

enum Config {
    // MARK: - Environment
    #if DEBUG
    static let useLocalSupabase = true
    #else
    static let useLocalSupabase = false
    #endif

    // MARK: - OpenAI API
    // API 키는 Secrets.swift 파일에서 로드 (git에서 제외됨)
    static let openAIAPIKey = Secrets.openAIAPIKey
    static let whisperEndpoint = "https://api.openai.com/v1/audio/transcriptions"
    static let whisperModel = "whisper-1"

    // MARK: - Supabase
    static var supabaseURL: String {
        useLocalSupabase ? "http://127.0.0.1:56321" : "https://nouigqxpieylsqhggcmt.supabase.co"
    }

    static var supabaseAnonKey: String {
        useLocalSupabase
            ? "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
            : "sb_publishable_BYEyKDUO7XfwaHO01tfF2Q_IeXKHAJk"
    }

    // MARK: - Recording
    static let maxRecordingDuration: TimeInterval = 180 // 3 minutes
    static let audioSampleRate: Double = 44100.0
    static let audioChannels: Int = 1

    // MARK: - App
    static let appGroupIdentifier = "group.com.intellieffect.throw"

    // MARK: - Device
    static var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
}
