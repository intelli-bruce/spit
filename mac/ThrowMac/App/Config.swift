import Foundation

enum Config {
    // MARK: - Supabase Configuration
    static let supabaseURL = "https://nouigqxpieylsqhggcmt.supabase.co"
    static let supabaseAnonKey = "sb_publishable_BYEyKDUO7XfwaHO01tfF2Q_IeXKHAJk"

    // MARK: - Local File Path
    static var journalFilePath: String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("Throw/Journal.md").path
    }

    // MARK: - Sync Settings
    static let autoSyncInterval: TimeInterval = 30 // seconds
    static let debounceDelay: TimeInterval = 1.0 // seconds after typing stops
}
