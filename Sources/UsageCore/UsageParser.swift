import Foundation

public enum UsageParser {
    public static func parse(_ data: Data, provider: Provider, now: Date = .now) throws -> UsageSnapshot {
        do {
            return switch provider {
            case .claude: try claude(data, now: now)
            case .codex: try codex(data, now: now)
            }
        } catch {
            throw UsageError.invalidResponse
        }
    }

    private static func claude(_ data: Data, now: Date) throws -> UsageSnapshot {
        let response = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        if let limits = response.limits, !limits.isEmpty {
            let windows = try limits.enumerated().map { index, limit in
                try UsageWindow(
                    id: "\(limit.kind)-\(index)", title: limit.title,
                    usedPercent: limit.percent, resetsAt: resetDate(limit.resets_at)
                )
            }
            return UsageSnapshot(provider: .claude, plan: nil, windows: windows, fetchedAt: now)
        }
        let windows = try response.entries.compactMap { id, title, value -> UsageWindow? in
            guard let value else { return nil }
            let reset = try resetDate(value.resets_at)
            return try UsageWindow(id: id, title: title, usedPercent: value.utilization, resetsAt: reset)
        }
        guard !windows.isEmpty else { throw UsageError.invalidResponse }
        return UsageSnapshot(provider: .claude, plan: nil, windows: windows, fetchedAt: now)
    }

    private static func codex(_ data: Data, now: Date) throws -> UsageSnapshot {
        let response = try JSONDecoder().decode(CodexResponse.self, from: data)
        var windows = try codexWindows(response.rate_limit, prefix: "", now: now)
        windows += try codexWindows(response.code_review_rate_limit, prefix: "Code review", now: now)
        for (index, limit) in (response.additional_rate_limits ?? []).enumerated() {
            let prefix = limit.limit_name ?? "Additional limit \(index + 1)"
            let extra = try codexWindows(limit.rate_limit, prefix: prefix, now: now)
            windows += try extra.map {
                try UsageWindow(id: "additional-\(index)-\($0.id)", title: $0.title, usedPercent: $0.usedPercent, resetsAt: $0.resetsAt)
            }
        }
        guard !windows.isEmpty else { throw UsageError.invalidResponse }
        return UsageSnapshot(provider: .codex, plan: response.plan_type, windows: windows, fetchedAt: now)
    }

    private static func codexWindows(_ limit: CodexLimit?, prefix: String, now: Date) throws -> [UsageWindow] {
        try [("primary", limit?.primary_window), ("secondary", limit?.secondary_window)].compactMap { id, value in
            guard let value else { return nil }
            let duration = windowName(value.limit_window_seconds)
            let title = prefix.isEmpty ? duration : "\(prefix) · \(duration.lowercased())"
            let reset = value.reset_at.map { Date(timeIntervalSince1970: $0) }
                ?? value.reset_after_seconds.map { now.addingTimeInterval($0) }
            return try UsageWindow(id: "\(prefix)-\(id)", title: title, usedPercent: value.used_percent, resetsAt: reset)
        }
    }

    private static func windowName(_ seconds: Int) -> String {
        switch seconds {
        case 18_000: "5 hours"
        case 604_800: "Weekly"
        case 86_400: "Daily"
        case 1_209_600: "2 weeks"
        case let value where value > 0 && value % 86_400 == 0: "\(value / 86_400) days"
        case let value where value > 0 && value % 3_600 == 0: "\(value / 3_600) hours"
        default: "Usage limit"
        }
    }

    private static func resetDate(_ value: String?) throws -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value) else {
            throw UsageError.invalidResponse
        }
        return date
    }
}

private struct ClaudeResponse: Decodable {
    let limits: [ClaudeLimit]?
    let five_hour: ClaudeWindow?
    let seven_day: ClaudeWindow?
    let seven_day_opus: ClaudeWindow?
    let seven_day_sonnet: ClaudeWindow?
    let seven_day_cowork: ClaudeWindow?
    let seven_day_oauth_apps: ClaudeWindow?

    var entries: [(String, String, ClaudeWindow?)] {
        [
            ("five_hour", "5 hours", five_hour),
            ("seven_day", "Weekly", seven_day),
            ("seven_day_opus", "Opus · weekly", seven_day_opus),
            ("seven_day_sonnet", "Sonnet · weekly", seven_day_sonnet),
            ("seven_day_cowork", "Cowork · weekly", seven_day_cowork),
            ("seven_day_oauth_apps", "OAuth apps · weekly", seven_day_oauth_apps),
        ]
    }
}

private struct ClaudeLimit: Decodable {
    struct Scope: Decodable {
        struct Model: Decodable { let display_name: String? }
        let model: Model?
    }
    let kind: String
    let percent: Double
    let resets_at: String?
    let scope: Scope?

    var title: String {
        switch kind {
        case "session": "5 hours"
        case "weekly_all": "Weekly"
        case "weekly_scoped": "\(scope?.model?.display_name ?? "Scoped usage") · weekly"
        default: kind.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

private struct ClaudeWindow: Decodable {
    let utilization: Double
    let resets_at: String?
}

private struct CodexResponse: Decodable {
    let plan_type: String?
    let rate_limit: CodexLimit?
    let code_review_rate_limit: CodexLimit?
    let additional_rate_limits: [AdditionalCodexLimit]?
}

private struct AdditionalCodexLimit: Decodable {
    let limit_name: String?
    let rate_limit: CodexLimit?
}

private struct CodexLimit: Decodable {
    let primary_window: CodexWindow?
    let secondary_window: CodexWindow?
}

private struct CodexWindow: Decodable {
    let used_percent: Double
    let limit_window_seconds: Int
    let reset_at: Double?
    let reset_after_seconds: Double?
}
