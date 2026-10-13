import Foundation

public enum Provider: String, CaseIterable, Sendable, Identifiable {
    case claude = "Claude"
    case codex = "Codex"

    public var id: String { rawValue }
    public var dashboard: URL {
        switch self {
        case .claude: URL(string: "https://claude.ai/settings/usage")!
        case .codex: URL(string: "https://chatgpt.com/codex/settings/usage")!
        }
    }
}

public struct UsageWindow: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let usedPercent: Double
    public let resetsAt: Date?
    public var remainingPercent: Int { Int((100 - usedPercent).rounded(.down)) }

    public init(id: String, title: String, usedPercent: Double, resetsAt: Date?) throws {
        guard usedPercent.isFinite, (0...100).contains(usedPercent) else {
            throw UsageError.invalidResponse
        }
        self.id = id
        self.title = title
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
    }
}

public struct UsageSnapshot: Sendable {
    public let provider: Provider
    public let plan: String?
    public let windows: [UsageWindow]
    public let fetchedAt: Date
    public var remainingPercent: Int? { windows.map(\.remainingPercent).min() }

    public init(provider: Provider, plan: String?, windows: [UsageWindow], fetchedAt: Date = .now) {
        self.provider = provider
        self.plan = plan
        self.windows = windows
        self.fetchedAt = fetchedAt
    }
}

public enum UsageError: Error, LocalizedError, Sendable {
    case signIn(Provider)
    case keychainDenied
    case invalidResponse
    case http(Int)
    case rateLimited(TimeInterval)
    case network

    public var errorDescription: String? {
        switch self {
        case .signIn(let provider): "Sign in to \(provider.rawValue == "Claude" ? "Claude Code" : "Codex CLI") in Terminal, then refresh."
        case .keychainDenied: "Allow access to Claude Code credentials in Keychain, then refresh."
        case .invalidResponse: "The service returned an unfamiliar usage format. Open its usage page to check your limits."
        case .http(let status) where status == 401 || status == 403:
            "Your sign-in needs attention. Sign in again in the CLI, then refresh."
        case .http(let status): "The usage service is unavailable (HTTP \(status)). Try again later."
        case .rateLimited: "Too many usage requests. Refresh will resume automatically."
        case .network: "Could not connect. Check your internet connection."
        }
    }
}
