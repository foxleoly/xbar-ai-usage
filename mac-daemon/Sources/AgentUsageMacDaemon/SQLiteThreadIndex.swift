import Foundation

public enum SQLiteThreadIndexError: Error, Equatable {
    case sqliteFailed(String)
}

public struct SQLiteThreadIndex: ThreadIndex {
    private let databaseURL: URL
    private let sqlitePath: String

    public init(
        databaseURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/state_5.sqlite"),
        sqlitePath: String = "/usr/bin/sqlite3"
    ) {
        self.databaseURL = databaseURL
        self.sqlitePath = sqlitePath
    }

    public func records(updatedSince cutoff: Date) throws -> [ThreadRecord] {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return []
        }

        let cutoffSeconds = Int(cutoff.timeIntervalSince1970)
        let query = """
        SELECT rollout_path, updated_at
        FROM threads
        WHERE updated_at >= \(cutoffSeconds)
        ORDER BY updated_at DESC;
        """

        let data = try runSQLiteJSON(query: query)
        let rows = try JSONDecoder().decode([SQLiteThreadRow].self, from: data)
        return rows.compactMap { row in
            guard !row.rollout_path.isEmpty else {
                return nil
            }
            return ThreadRecord(
                rolloutPath: URL(fileURLWithPath: row.rollout_path),
                updatedAt: Date(timeIntervalSince1970: TimeInterval(row.updated_at))
            )
        }
    }

    private func runSQLiteJSON(query: String) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sqlitePath)
        process.arguments = ["-json", databaseURL.path, query]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let message = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "sqlite3 failed"
            throw SQLiteThreadIndexError.sqliteFailed(message)
        }

        return outputData.isEmpty ? Data("[]".utf8) : outputData
    }
}

private struct SQLiteThreadRow: Decodable {
    let rollout_path: String
    let updated_at: Int
}
