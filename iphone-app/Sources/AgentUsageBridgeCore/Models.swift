import Foundation

public struct TokenUsage: Codable, Equatable, Sendable {
    public var total: Int
    public var input: Int
    public var output: Int
    public var cache: Int
    public var reasoning: Int

    public static let zero = TokenUsage(total: 0, input: 0, output: 0, cache: 0, reasoning: 0)

    public init(total: Int, input: Int, output: Int, cache: Int, reasoning: Int) {
        self.total = total
        self.input = input
        self.output = output
        self.cache = cache
        self.reasoning = reasoning
    }
}

public struct UsageWindows: Codable, Equatable, Sendable {
    public var h5: TokenUsage
    public var today: TokenUsage
    public var d7: TokenUsage
    public var d30: TokenUsage

    public init(h5: TokenUsage, today: TokenUsage, d7: TokenUsage, d30: TokenUsage) {
        self.h5 = h5
        self.today = today
        self.d7 = d7
        self.d30 = d30
    }
}

public struct AgentUsage: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var source: String
    public var status: String
    public var windows: UsageWindows
    public var rateLimits: AgentRateLimits?

    public init(
        id: String,
        name: String,
        source: String,
        status: String,
        windows: UsageWindows,
        rateLimits: AgentRateLimits? = nil
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.status = status
        self.windows = windows
        self.rateLimits = rateLimits
    }
}

public struct AgentRateLimits: Codable, Equatable, Sendable {
    public var primary: AgentRateLimitWindow?
    public var secondary: AgentRateLimitWindow?

    public init(primary: AgentRateLimitWindow?, secondary: AgentRateLimitWindow?) {
        self.primary = primary
        self.secondary = secondary
    }
}

public struct AgentRateLimitWindow: Codable, Equatable, Sendable {
    public var usedPercent: Double
    public var windowMinutes: Int
    public var resetsAt: Date?

    public init(usedPercent: Double, windowMinutes: Int, resetsAt: Date?) {
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
    }

    public var remainingPercent: Double {
        min(max(100 - usedPercent, 0), 100)
    }
}

public struct AgentUsageSnapshot: Codable, Equatable, Sendable {
    public var kind: String
    public var version: Int
    public var updatedAt: Date
    public var agents: [AgentUsage]

    public init(kind: String, version: Int, updatedAt: Date, agents: [AgentUsage]) {
        self.kind = kind
        self.version = version
        self.updatedAt = updatedAt
        self.agents = agents
    }
}

public struct AgentUsageSnapshotDecoder {
    private let decoder: JSONDecoder

    public init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func decode(_ data: Data) throws -> AgentUsageSnapshot {
        try decoder.decode(AgentUsageSnapshot.self, from: data)
    }
}
