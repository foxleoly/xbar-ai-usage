import Foundation

public struct UsageWindowAggregator {
    public let now: Date
    public let calendar: Calendar
    public let h5Start: Date
    public let todayStart: Date
    public let d7Start: Date
    public let d30Start: Date

    public init(now: Date = Date(), calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
        self.h5Start = now.addingTimeInterval(-5 * 60 * 60)
        self.todayStart = calendar.startOfDay(for: now)
        self.d7Start = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        self.d30Start = calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
    }

    public func windows(for samples: [TimedTokenUsage]) -> UsageWindows {
        UsageWindows(
            h5: aggregate(samples, since: h5Start),
            today: aggregate(samples, since: todayStart),
            d7: aggregate(samples, since: d7Start),
            d30: aggregate(samples, since: d30Start)
        )
    }

    private func aggregate(_ samples: [TimedTokenUsage], since start: Date) -> TokenUsage {
        samples
            .filter { $0.timestamp >= start && $0.timestamp <= now }
            .reduce(into: .zero) { partial, sample in
                partial.add(sample.usage)
            }
    }
}

public enum AgentUsageDateParser {
    public static func date(from string: String) -> Date? {
        let iso8601WithFractions = ISO8601DateFormatter()
        iso8601WithFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601WithFractions.date(from: string) {
            return date
        }
        let iso8601 = ISO8601DateFormatter()
        return iso8601.date(from: string)
    }
}

public enum UsageValue {
    public static func int(_ value: Any?) -> Int {
        if let value = value as? Int {
            return value
        }
        if let value = value as? Double {
            return Int(value)
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        return 0
    }
}
