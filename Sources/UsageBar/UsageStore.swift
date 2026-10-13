import AppKit
import Combine
import ServiceManagement
import UsageCore

struct ProviderState {
    var snapshot: UsageSnapshot?
    var error: String?
    var retryAt: Date?
    var refreshing = false
}

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var states = Dictionary(uniqueKeysWithValues: Provider.allCases.map { ($0, ProviderState()) })
    @Published private(set) var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @Published private(set) var loginError: String?
    private let client = UsageClient()
    private var refreshTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    var onChange: (() -> Void)?

    var refreshing: Bool { states.values.contains(where: \.refreshing) }
    var statusTitle: String {
        Provider.allCases.map { provider in
            let state = states[provider]
            let percent = state?.error == nil ? state?.snapshot?.remainingPercent : nil
            return "\(provider == .claude ? "C" : "X") \(percent.map { "\($0)%" } ?? "—")"
        }.joined(separator: "  ·  ")
    }

    func start() {
        refresh()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    func refreshIfNeeded() {
        let outdated = states.values.contains { state in
            state.snapshot.map { Date.now.timeIntervalSince($0.fetchedAt) >= 60 } ?? true
        }
        if outdated { refresh() }
    }

    func refresh() {
        guard refreshTask == nil else { return }
        let providers = Provider.allCases.filter { states[$0]?.retryAt.map { $0 <= .now } ?? true }
        guard !providers.isEmpty else { return }
        for provider in providers { states[provider]?.refreshing = true }
        refreshTask = Task { [weak self, client] in
            await withTaskGroup(of: (Provider, Result<UsageSnapshot, UsageError>).self) { group in
                for provider in providers {
                    group.addTask {
                        do { return (provider, .success(try await client.fetch(provider))) }
                        catch { return (provider, .failure(error as? UsageError ?? .network)) }
                    }
                }
                for await (provider, result) in group {
                    guard let self else { continue }
                    switch result {
                    case .success(let snapshot):
                        self.states[provider] = ProviderState(snapshot: snapshot)
                    case .failure(let error):
                        self.states[provider]?.error = error.localizedDescription
                        self.states[provider]?.refreshing = false
                        if case .rateLimited(let seconds) = error {
                            self.states[provider]?.retryAt = .now.addingTimeInterval(seconds)
                        }
                    }
                    self.onChange?()
                }
            }
            self?.refreshTask = nil
        }
    }

    func toggleLaunchAtLogin() {
        do {
            if launchesAtLogin { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            launchesAtLogin = SMAppService.mainApp.status == .enabled
            loginError = SMAppService.mainApp.status == .requiresApproval
                ? "Allow Usage Bar in System Settings → General → Login Items." : nil
        } catch {
            loginError = "Could not change login settings. Try again from the installed app."
        }
    }
}
