import Foundation
import Testing
@testable import UsageCore

@Test func claudeSubscriptionWindows() throws {
    let payload = Data(#"{"five_hour":{"utilization":22,"resets_at":"2026-10-14T03:00:00.000Z"},"seven_day":{"utilization":4,"resets_at":"2026-10-20T03:00:00Z"},"seven_day_opus":null,"seven_day_sonnet":{"utilization":30,"resets_at":null},"extra_usage":{"is_enabled":false},"future_field":true}"#.utf8)
    let snapshot = try UsageParser.parse(payload, provider: .claude)
    #expect(snapshot.windows.map(\.title) == ["5 hours", "Weekly", "Sonnet · weekly"])
    #expect(snapshot.remainingPercent == 70)
    #expect(snapshot.windows[0].resetsAt != nil)
    #expect(snapshot.windows[1].resetsAt != nil)
    #expect(snapshot.windows[2].resetsAt == nil)
}

@Test func codexUsesActualDurationInsteadOfAssumingFiveHours() throws {
    let payload = Data(#"{"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":10,"limit_window_seconds":604800,"reset_at":1792486864},"secondary_window":null},"code_review_rate_limit":null,"additional_rate_limits":null}"#.utf8)
    let snapshot = try UsageParser.parse(payload, provider: .codex)
    #expect(snapshot.plan == "pro")
    #expect(snapshot.windows.count == 1)
    #expect(snapshot.windows[0].title == "Weekly")
    #expect(snapshot.remainingPercent == 90)
    #expect(snapshot.windows[0].resetsAt == Date(timeIntervalSince1970: 1792486864))
}

@Test func codexMultipleLimitsAndRelativeReset() throws {
    let now = Date(timeIntervalSince1970: 1000)
    let payload = Data(#"{"rate_limit":{"primary_window":{"used_percent":83.2,"limit_window_seconds":18000,"reset_after_seconds":600},"secondary_window":{"used_percent":40,"limit_window_seconds":604800}},"code_review_rate_limit":{"primary_window":{"used_percent":100,"limit_window_seconds":604800}},"additional_rate_limits":[{"limit_name":"Fast model","rate_limit":{"primary_window":{"used_percent":5,"limit_window_seconds":86400}}}]}"#.utf8)
    let snapshot = try UsageParser.parse(payload, provider: .codex, now: now)
    #expect(snapshot.windows.count == 4)
    #expect(Set(snapshot.windows.map(\.id)).count == 4)
    #expect(snapshot.windows[0].remainingPercent == 16)
    #expect(snapshot.windows[0].resetsAt == now.addingTimeInterval(600))
    #expect(snapshot.windows[2].title == "Code review · weekly")
    #expect(snapshot.remainingPercent == 0)
}

@Test func missingOrInvalidLimitsNeverBecomeZeroUsage() {
    for provider in Provider.allCases {
        for payload in ["{}", "{\"rate_limit\":null}", "not json"] {
            #expect(throws: UsageError.self) {
                try UsageParser.parse(Data(payload.utf8), provider: provider)
            }
        }
    }
    for percent in [-1.0, 101.0, .infinity, .nan] {
        #expect(throws: UsageError.self) {
            try UsageWindow(id: "test", title: "Weekly", usedPercent: percent, resetsAt: nil)
        }
    }
    #expect(throws: UsageError.self) {
        try UsageParser.parse(Data(#"{"five_hour":{"utilization":0,"resets_at":"invalid"}}"#.utf8), provider: .claude)
    }
}

@Test func rateLimitBackoffHonorsServerAndHasMinimumDelay() {
    let now = Date(timeIntervalSince1970: 0)
    #expect(UsageClient.retryDelay("0") == 300)
    #expect(UsageClient.retryDelay("1200") == 1200)
    #expect(UsageClient.retryDelay(nil) == 300)
    #expect(UsageClient.retryDelay("invalid") == 300)
    #expect(UsageClient.retryDelay("Thu, 01 Jan 1970 01:00:00 GMT", now: now) == 3600)
}

@Test func claudeCurrentSchemaIncludesScopedLimitsWithoutDuplicates() throws {
    let payload = Data(#"{"five_hour":{"utilization":22,"resets_at":null},"seven_day":{"utilization":4,"resets_at":null},"limits":[{"kind":"session","group":"session","percent":23,"resets_at":"2026-10-13T19:19:59.756416+00:00","scope":null,"is_active":true},{"kind":"weekly_all","group":"weekly","percent":4,"resets_at":"2026-10-19T21:59:59.756436+00:00","scope":null,"is_active":false},{"kind":"weekly_scoped","group":"weekly","percent":0,"resets_at":"2026-10-19T22:00:00+00:00","scope":{"model":{"id":null,"display_name":"Fable"},"surface":null},"is_active":false}]}"#.utf8)
    let snapshot = try UsageParser.parse(payload, provider: .claude)
    #expect(snapshot.windows.map(\.title) == ["5 hours", "Weekly", "Fable · weekly"])
    #expect(snapshot.windows[0].usedPercent == 23)
    #expect(snapshot.windows.allSatisfy { $0.resetsAt != nil })
    #expect(snapshot.remainingPercent == 77)
}
