import Foundation

public actor UsageClient {
    private let session: URLSession
    private let redirectGuard: RedirectGuard
    private let credentials = CredentialReader()

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        let guardDelegate = RedirectGuard()
        redirectGuard = guardDelegate
        session = URLSession(configuration: configuration, delegate: guardDelegate, delegateQueue: nil)
    }

    public func fetch(_ provider: Provider) async throws -> UsageSnapshot {
        let credential = try credentials.read(provider)
        let url: URL
        switch provider {
        case .claude: url = URL(string: "https://api.anthropic.com/api/oauth/usage")!
        case .codex: url = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("UsageBar/1.0", forHTTPHeaderField: "User-Agent")
        if provider == .claude {
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        } else if let account = credential.accountID {
            request.setValue(account, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UsageError.network
        }
        guard let http = response as? HTTPURLResponse else { throw UsageError.network }
        guard http.statusCode == 200 else {
            if http.statusCode == 429 {
                throw UsageError.rateLimited(Self.retryDelay(http.value(forHTTPHeaderField: "Retry-After")))
            }
            throw UsageError.http(http.statusCode)
        }
        let snapshot = try UsageParser.parse(data, provider: provider)
        return UsageSnapshot(
            provider: provider, plan: snapshot.plan ?? credential.plan,
            windows: snapshot.windows, fetchedAt: snapshot.fetchedAt
        )
    }

    public static func retryDelay(_ value: String?, now: Date = .now) -> TimeInterval {
        if let value, let seconds = TimeInterval(value), seconds.isFinite {
            return max(300, seconds)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let value, let date = formatter.date(from: value) {
            return max(300, date.timeIntervalSince(now))
        }
        return 300
    }
}

private final class RedirectGuard: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
