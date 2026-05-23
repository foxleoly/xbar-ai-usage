import Foundation

public enum MockData {
    public static let codexSnapshot = AgentUsageSnapshot(
        kind: "agent_usage_snapshot",
        version: 1,
        updatedAt: Date(timeIntervalSince1970: 1_779_190_307),
        agents: [
            AgentUsage(
                id: "codex",
                name: "Codex",
                source: "codex",
                status: "active",
                windows: UsageWindows(
                    h5: TokenUsage(total: 8_100_241, input: 8_049_731, output: 50_510, cache: 7_583_488, reasoning: 13_445),
                    today: TokenUsage(total: 8_100_241, input: 8_049_731, output: 50_510, cache: 7_583_488, reasoning: 13_445),
                    d7: TokenUsage(total: 20_767_375, input: 20_682_736, output: 84_639, cache: 19_344_384, reasoning: 20_767),
                    d30: TokenUsage(total: 77_076_451, input: 76_499_079, output: 250_603, cache: 71_767_424, reasoning: 52_320)
                ),
                rateLimits: AgentRateLimits(
                    primary: AgentRateLimitWindow(usedPercent: 67, windowMinutes: 300, resetsAt: Date(timeIntervalSince1970: 1_779_511_370)),
                    secondary: AgentRateLimitWindow(usedPercent: 52, windowMinutes: 10_080, resetsAt: Date(timeIntervalSince1970: 1_779_838_670))
                )
            ),
            AgentUsage(
                id: "claude_code",
                name: "Claude Code",
                source: "claude_code",
                status: "active",
                windows: UsageWindows(
                    h5: TokenUsage(total: 2_384_920, input: 2_301_104, output: 83_816, cache: 1_856_000, reasoning: 42_118),
                    today: TokenUsage(total: 5_928_640, input: 5_704_880, output: 223_760, cache: 4_318_720, reasoning: 91_442),
                    d7: TokenUsage(total: 18_472_300, input: 17_899_420, output: 572_880, cache: 13_201_408, reasoning: 216_904),
                    d30: TokenUsage(total: 64_803_910, input: 62_481_600, output: 2_322_310, cache: 47_882_240, reasoning: 732_190)
                )
            ),
            AgentUsage(
                id: "opencode",
                name: "OpenCode",
                source: "opencode",
                status: "active",
                windows: UsageWindows(
                    h5: TokenUsage(total: 846_210, input: 811_360, output: 34_850, cache: 542_720, reasoning: 9_620),
                    today: TokenUsage(total: 1_704_880, input: 1_627_440, output: 77_440, cache: 1_088_512, reasoning: 18_904),
                    d7: TokenUsage(total: 7_934_120, input: 7_588_220, output: 345_900, cache: 5_210_112, reasoning: 88_330),
                    d30: TokenUsage(total: 22_418_760, input: 21_504_008, output: 914_752, cache: 14_884_864, reasoning: 247_680)
                )
            )
        ]
    )
}
