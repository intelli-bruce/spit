import Foundation
import Combine

actor LocalFileService {
    static let shared = LocalFileService()

    private let fileURL: URL
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var lastModificationDate: Date?

    private init() {
        self.fileURL = URL(fileURLWithPath: Config.journalFilePath)
    }

    // MARK: - File Operations

    func readJournal() async throws -> String {
        // Ensure parent directory exists
        let parentDir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // Create initial file if not exists
            let initialContent = "# Journal\n\n---\n"
            try initialContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return initialContent
        }

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        lastModificationDate = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date
        return content
    }

    func writeJournal(_ content: String) async throws {
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        lastModificationDate = Date()
    }

    func appendToJournal(_ entry: String) async throws {
        var content = try await readJournal()

        // Add entry with timestamp separator
        let timestamp = formatTimestamp(Date())
        content += "\n---\n\n## \(timestamp)\n\n\(entry)\n"

        try await writeJournal(content)
    }

    func hasFileChanged() async throws -> Bool {
        guard let lastDate = lastModificationDate else { return true }

        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let modDate = attrs[.modificationDate] as? Date else { return false }

        return modDate > lastDate
    }

    // MARK: - File Watching

    nonisolated func startWatching(onChange: @escaping () -> Void) {
        let fd = open(Config.journalFilePath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler {
            onChange()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()

        Task { @MainActor in
            await self.setFileMonitor(source)
        }
    }

    private func setFileMonitor(_ monitor: DispatchSourceFileSystemObject) {
        fileMonitor = monitor
    }

    nonisolated func stopWatching() {
        Task {
            await self.cancelFileMonitor()
        }
    }

    private func cancelFileMonitor() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    // MARK: - Helpers

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    func computeHash(_ content: String) -> String {
        let data = Data(content.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

import CommonCrypto
