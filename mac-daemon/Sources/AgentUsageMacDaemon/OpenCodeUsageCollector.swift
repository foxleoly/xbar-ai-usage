import Foundation

public struct OpenCodeUsageCollector {
    private let databaseURLs: [URL]
    private let sqlitePath: String
    private let fileManager: FileManager

    public init(
        databaseURLs: [URL] = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/share/opencode/opencode.db"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/share/opencode-alt/opencode/opencode.db")
        ],
        sqlitePath: String = "/usr/bin/sqlite3",
        fileManager: FileManager = .default
    ) {
        self.databaseURLs = databaseURLs
        self.sqlitePath = sqlitePath
        self.fileManager = fileManager
    }

    public func agent(now: Date = Date(), calendar: Calendar = .current) throws -> AgentUsage {
        let aggregator = UsageWindowAggregator(now: now, calendar: calendar)
        var windows = UsageWindows(h5: .zero, today: .zero, d7: .zero, d30: .zero)

        for databaseURL in databaseURLs where fileManager.fileExists(atPath: databaseURL.path) {
            windows.h5.add(try usage(in: databaseURL, since: aggregator.h5Start, until: now))
            windows.today.add(try usage(in: databaseURL, since: aggregator.todayStart, until: now))
            windows.d7.add(try usage(in: databaseURL, since: aggregator.d7Start, until: now))
            windows.d30.add(try usage(in: databaseURL, since: aggregator.d30Start, until: now))
        }

        let status = windows.d30.total > 0 ? "active" : "unavailable"
        return AgentUsage(
            id: "opencode",
            name: "OpenCode",
            source: "opencode",
            status: status,
            windows: windows
        )
    }

    private func usage(in databaseURL: URL, since start: Date, until end: Date) throws -> TokenUsage {
        let startMs = Int(start.timeIntervalSince1970 * 1000)
        let endMs = Int(end.timeIntervalSince1970 * 1000)
        let query = """
        SELECT
          COALESCE(SUM(json_extract(data,'$.tokens.total')), 0) AS total,
          COALESCE(SUM(json_extract(data,'$.tokens.input')), 0) AS input,
          COALESCE(SUM(json_extract(data,'$.tokens.output')), 0) AS output,
          COALESCE(SUM(COALESCE(json_extract(data,'$.tokens.cache.read'), 0) + COALESCE(json_extract(data,'$.tokens.cache.write'), 0)), 0) AS cache,
          COALESCE(SUM(json_extract(data,'$.tokens.reasoning')), 0) AS reasoning
        FROM message
        WHERE json_extract(data,'$.role') = 'assistant'
          AND time_created >= \(startMs)
          AND time_created <= \(endMs);
        """
        let data = try runSQLiteJSON(databaseURL: databaseURL, query: query)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let row = rows.first
        else {
            return .zero
        }

        return TokenUsage(
            total: UsageValue.int(row["total"]),
            input: UsageValue.int(row["input"]),
            output: UsageValue.int(row["output"]),
            cache: UsageValue.int(row["cache"]),
            reasoning: UsageValue.int(row["reasoning"])
        )
    }

    private func runSQLiteJSON(databaseURL: URL, query: String) throws -> Data {
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

private extension UsageWindows {
    mutating func add(_ other: UsageWindows) {
        h5.add(other.h5)
        today.add(other.today)
        d7.add(other.d7)
        d30.add(other.d30)
    }
}
