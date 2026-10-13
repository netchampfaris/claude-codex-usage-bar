import AppKit
import SwiftUI
import UsageCore

struct UsagePopover: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Usage Bar").font(.system(size: 15, weight: .semibold))
                Spacer()
                if store.refreshing {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                        .accessibilityLabel("Refreshing usage")
                }
                Button { store.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(store.refreshing)
                .help("Refresh usage")
                .accessibilityLabel("Refresh usage")
            }
            .padding(.bottom, 6)
            Text("Subscription limits").font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.bottom, 18)

            ForEach(Provider.allCases) { provider in
                ProviderSection(provider: provider, state: store.states[provider] ?? ProviderState())
                if provider == .claude { Divider().padding(.vertical, 16) }
            }
            Divider().padding(.top, 18).padding(.bottom, 12)
            HStack {
                Menu {
                    Toggle("Launch at login", isOn: Binding(
                        get: { store.launchesAtLogin },
                        set: { _ in store.toggleLaunchAtLogin() }
                    ))
                    Divider()
                    Button("Quit Usage Bar") { NSApplication.shared.terminate(nil) }
                        .keyboardShortcut("q")
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Settings")
                .accessibilityLabel("Settings")
                Spacer()
                Text("Menu bar shows % remaining")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            if let error = store.loginError {
                Text(error).font(.caption).foregroundStyle(.red).padding(.top, 8)
            }
        }
        .padding(20)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ProviderSection: View {
    let provider: Provider
    let state: ProviderState
    private var accent: Color { provider == .claude ? Color(red: 0.77, green: 0.39, blue: 0.24) : .teal }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(nsImage: ProviderAssets.image(for: provider))
                    .resizable()
                    .renderingMode(provider == .codex ? .template : .original)
                    .scaledToFit()
                    .foregroundStyle(.primary)
                    .frame(width: 16, height: 16)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                Text(provider.rawValue).font(.system(size: 13, weight: .semibold))
                if let plan = state.snapshot?.plan {
                    Text(plan.capitalized).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { NSWorkspace.shared.open(provider.dashboard) } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help("Open \(provider.rawValue) usage page")
                .accessibilityLabel("Open \(provider.rawValue) usage page")
            }
            if let snapshot = state.snapshot {
                ForEach(snapshot.windows) { window in
                    WindowRow(window: window, accent: accent, stale: state.error != nil)
                }
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text("\(state.error == nil ? "Updated" : "Last updated") \(snapshot.fetchedAt, style: .relative) ago")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            } else if state.refreshing {
                Text("Checking your limits…").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if let error = state.error {
                VStack(alignment: .leading, spacing: 6) {
                    Label(state.snapshot == nil ? "Usage unavailable" : "Showing earlier usage", systemImage: "exclamationmark.circle")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.orange)
                    Text(error).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let retry = state.retryAt, retry > .now {
                        Text("Next refresh after \(retry, style: .time)").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Button("Copy sign-in command") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(provider == .claude ? "claude auth login" : "codex login", forType: .string)
                    }
                    .font(.system(size: 11)).buttonStyle(.borderless)
                }
            }
        }
    }
}

private struct WindowRow: View {
    let window: UsageWindow
    let accent: Color
    let stale: Bool
    private var color: Color {
        if stale { return .secondary }
        if window.usedPercent >= 90 { return .red }
        if window.usedPercent >= 75 { return .orange }
        return accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(window.title).foregroundStyle(.secondary)
                Spacer()
                Text("\(window.usedPercent, specifier: "%.0f")% used")
                    .fontWeight(.medium).monospacedDigit()
            }
            .font(.system(size: 11))
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.07))
                    Capsule().fill(color)
                        .frame(width: geometry.size.width * window.usedPercent / 100)
                }
            }
            .frame(height: 5)
            .accessibilityLabel("\(window.title): \(Int(window.usedPercent.rounded())) percent used")
            TimelineView(.periodic(from: .now, by: 60)) { context in
                if let reset = window.resetsAt {
                    HStack {
                        if reset <= context.date {
                            Text("Reset due · refresh to check")
                        } else {
                            Text("Resets \(reset, style: .relative)")
                        }
                        Spacer()
                        Text(reset, format: .dateTime.weekday(.abbreviated).hour().minute())
                    }
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .help(reset.formatted(date: .complete, time: .shortened))
                } else {
                    Text("Reset time unavailable").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
    }
}
