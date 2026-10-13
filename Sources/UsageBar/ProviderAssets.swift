import AppKit
import UsageCore

@MainActor
enum ProviderAssets {
    private static let claude = load("Claude")
    private static let codex = load("Codex")

    static func image(for provider: Provider) -> NSImage {
        switch provider {
        case .claude: claude
        case .codex: codex
        }
    }

    private static let bundle: Bundle = {
        if let url = Bundle.main.url(forResource: "UsageBar_UsageBar", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return .module
    }()

    private static func load(_ name: String) -> NSImage {
        guard let url = bundle.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            preconditionFailure("Missing bundled logo: \(name)")
        }
        return image
    }
}
