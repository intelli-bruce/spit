import Foundation
import IOKit

enum Config {
    // MARK: - Environment
    #if DEBUG
    static let useLocalSupabase = true
    #else
    static let useLocalSupabase = false
    #endif

    // MARK: - Supabase Configuration
    static var supabaseURL: String {
        useLocalSupabase ? "http://127.0.0.1:56321" : "https://nouigqxpieylsqhggcmt.supabase.co"
    }

    static var supabaseAnonKey: String {
        useLocalSupabase
            ? "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
            : "sb_publishable_BYEyKDUO7XfwaHO01tfF2Q_IeXKHAJk"
    }

    // MARK: - Sync Settings
    static let autoSyncInterval: TimeInterval = 30 // seconds
    static let debounceDelay: TimeInterval = 1.0 // seconds after typing stops

    // MARK: - Device
    static var deviceId: String {
        // Get hardware UUID for macOS
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )

        guard platformExpert != 0 else {
            return UUID().uuidString
        }

        defer { IOObjectRelease(platformExpert) }

        if let serialNumber = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            return serialNumber
        }

        return UUID().uuidString
    }
}
