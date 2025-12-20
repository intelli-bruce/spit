import Foundation
import IOKit

enum Config {
    // MARK: - Supabase Configuration
    static let supabaseURL = "https://nouigqxpieylsqhggcmt.supabase.co"
    static let supabaseAnonKey = "sb_publishable_BYEyKDUO7XfwaHO01tfF2Q_IeXKHAJk"

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
