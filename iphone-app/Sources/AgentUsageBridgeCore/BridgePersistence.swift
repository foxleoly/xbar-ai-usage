import Foundation

public struct BridgeLogEntry: Codable, Equatable, Sendable {
    public var kind: String
    public var at: Date
    public var agentCount: Int?
    public var message: String?

    public init(kind: String, at: Date, agentCount: Int? = nil, message: String? = nil) {
        self.kind = kind
        self.at = at
        self.agentCount = agentCount
        self.message = message
    }

    public static func snapshotReceived(at: Date, agentCount: Int) -> BridgeLogEntry {
        BridgeLogEntry(kind: "snapshot_received", at: at, agentCount: agentCount)
    }

    public static func watchSyncSucceeded(at: Date) -> BridgeLogEntry {
        BridgeLogEntry(kind: "watch_sync_succeeded", at: at)
    }

    public static func macDisconnected(at: Date, reason: String) -> BridgeLogEntry {
        BridgeLogEntry(kind: "mac_disconnected", at: at, message: reason)
    }

    public static func cacheLoadFailed(at: Date, reason: String) -> BridgeLogEntry {
        BridgeLogEntry(kind: "cache_load_failed", at: at, message: reason)
    }

    public static func bluetoothEvent(at: Date, message: String) -> BridgeLogEntry {
        BridgeLogEntry(kind: "bluetooth_event", at: at, message: message)
    }
}

public struct BridgePersistence {
    public let rootDirectory: URL

    private let fileManager: FileManager
    private let snapshotFileName = "latest-snapshot.json"
    private let logFileName = "bridge-events.jsonl"

    public init(
        rootDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AgentUsageBridge", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
    }

    public func saveLatestSnapshot(_ snapshot: AgentUsageSnapshot) throws {
        try ensureRootDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: [.atomic])
    }

    public func loadLatestSnapshot() throws -> AgentUsageSnapshot? {
        guard fileManager.fileExists(atPath: snapshotURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: snapshotURL)
            return try AgentUsageSnapshotDecoder().decode(data)
        } catch {
            try appendLog(.cacheLoadFailed(at: Date(), reason: String(describing: error)))
            return nil
        }
    }

    public func appendLog(_ entry: BridgeLogEntry) throws {
        try ensureRootDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        var line = try encoder.encode(entry)
        line.append(UInt8(ascii: "\n"))

        if fileManager.fileExists(atPath: logURL.path) {
            let handle = try FileHandle(forWritingTo: logURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } else {
            try line.write(to: logURL, options: [.atomic])
        }
    }

    public func loadLogs(limit: Int? = nil) throws -> [BridgeLogEntry] {
        guard fileManager.fileExists(atPath: logURL.path) else {
            return []
        }

        let data = try Data(contentsOf: logURL)
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = text
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> BridgeLogEntry? in
                try? decoder.decode(BridgeLogEntry.self, from: Data(String(line).utf8))
            }

        if let limit, entries.count > limit {
            return Array(entries.suffix(limit))
        }
        return entries
    }

    private var snapshotURL: URL {
        rootDirectory.appendingPathComponent(snapshotFileName)
    }

    private var logURL: URL {
        rootDirectory.appendingPathComponent(logFileName)
    }

    private func ensureRootDirectory() throws {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }
}
