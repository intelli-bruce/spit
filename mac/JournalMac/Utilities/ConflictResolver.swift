import Foundation

/// Handles conflict resolution for sync operations
struct ConflictResolver {

    enum Resolution {
        case keepLocal
        case keepRemote
        case merge
    }

    /// Resolve conflict between local and remote entries
    static func resolve(
        local: JournalEntry,
        remote: JournalEntry,
        strategy: Resolution = .merge
    ) -> JournalEntry {
        switch strategy {
        case .keepLocal:
            return local

        case .keepRemote:
            return remote

        case .merge:
            // For append-only journal, merge by keeping both contents
            if local.content == remote.content {
                // Same content, prefer newer metadata
                return local.updatedAt > remote.updatedAt ? local : remote
            }

            // Different content - append both with markers
            let mergedContent = """
            \(local.content)

            <!-- SYNC CONFLICT: Remote version below -->

            \(remote.content)
            """

            return JournalEntry(
                id: local.id,
                content: mergedContent,
                timestamp: min(local.timestamp, remote.timestamp),
                source: .manual,
                deviceId: local.deviceId,
                createdAt: min(local.createdAt, remote.createdAt),
                updatedAt: Date(),
                isDeleted: false,
                version: max(local.version, remote.version) + 1
            )
        }
    }

    /// Check if two entries are in conflict
    static func hasConflict(local: JournalEntry, remote: JournalEntry) -> Bool {
        guard local.id == remote.id else { return false }
        return local.content != remote.content && local.version == remote.version
    }

    /// Merge two sets of entries using append-only strategy
    static func mergeEntrySets(
        local: [JournalEntry],
        remote: [JournalEntry]
    ) -> [JournalEntry] {
        var merged: [UUID: JournalEntry] = [:]

        // Add all local entries
        for entry in local {
            merged[entry.id] = entry
        }

        // Merge remote entries
        for remoteEntry in remote {
            if let localEntry = merged[remoteEntry.id] {
                // Entry exists in both - resolve conflict
                if hasConflict(local: localEntry, remote: remoteEntry) {
                    merged[remoteEntry.id] = resolve(local: localEntry, remote: remoteEntry)
                } else {
                    // No conflict - use newer version
                    merged[remoteEntry.id] = localEntry.updatedAt > remoteEntry.updatedAt
                        ? localEntry
                        : remoteEntry
                }
            } else {
                // New remote entry
                merged[remoteEntry.id] = remoteEntry
            }
        }

        // Sort by timestamp (newest first)
        return Array(merged.values)
            .filter { !$0.isDeleted }
            .sorted { $0.timestamp > $1.timestamp }
    }
}
