import AgentUsageMacDaemon
import Foundation

let threadIndex = SQLiteThreadIndex()
let collector = CodexUsageCollector(threadIndex: threadIndex)

if CommandLine.arguments.contains("--print-once") {
    do {
        let snapshot = try collector.snapshot()
        let encoded = try SnapshotEncoder().encode(snapshot)
        FileHandle.standardOutput.write(encoded)
        FileHandle.standardOutput.write(Data("\n".utf8))
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("agent-usage-daemon: \(error)\n".utf8))
        exit(1)
    }
}

let daemon = UsageDaemon(collector: collector)
daemon.start()
