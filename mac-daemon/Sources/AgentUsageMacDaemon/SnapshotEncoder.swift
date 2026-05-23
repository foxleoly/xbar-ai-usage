import Foundation

public struct SnapshotEncoder {
    private let encoder: JSONEncoder

    public init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
    }

    public func encode(_ snapshot: AgentUsageSnapshot) throws -> Data {
        try encoder.encode(snapshot)
    }
}
