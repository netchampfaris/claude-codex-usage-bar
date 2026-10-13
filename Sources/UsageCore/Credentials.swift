import Foundation

struct Credential: Sendable {
    let accessToken: String
    let accountID: String?
    let plan: String?
}

struct CredentialReader: Sendable {
    func read(_ provider: Provider) throws -> Credential {
        switch provider {
        case .claude: try claude()
        case .codex: try codex()
        }
    }

    private func claude() throws -> Credential {
        let file = directory("CLAUDE_CONFIG_DIR", fallback: ".claude").appendingPathComponent(".credentials.json")
        let data = try? Data(contentsOf: file)
        let credentials = data ?? keychain(service: "Claude Code-credentials")
        guard let credentials,
              let auth = try? JSONDecoder().decode(ClaudeAuth.self, from: credentials),
              let token = auth.claudeAiOauth?.accessToken, !token.isEmpty else {
            throw UsageError.signIn(.claude)
        }
        return Credential(accessToken: token, accountID: nil, plan: auth.claudeAiOauth?.subscriptionType)
    }

    private func codex() throws -> Credential {
        let file = directory("CODEX_HOME", fallback: ".codex").appendingPathComponent("auth.json")
        guard let data = try? Data(contentsOf: file),
              let auth = try? JSONDecoder().decode(CodexAuth.self, from: data),
              auth.auth_mode != "apikey",
              let token = auth.tokens?.access_token, !token.isEmpty else {
            throw UsageError.signIn(.codex)
        }
        return Credential(accessToken: token, accountID: auth.tokens?.account_id, plan: nil)
    }

    private func directory(_ variable: String, fallback: String) -> URL {
        if let path = ProcessInfo.processInfo.environment[variable], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(fallback)
    }

    private func keychain(service: String) -> Data? {
        // The Apple-signed utility reads the CLI's existing item without saving another copy.
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-w"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 15, execute: timeout)
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            timeout.cancel()
            return process.terminationStatus == 0 ? data : nil
        } catch {
            return nil
        }
    }
}

private struct ClaudeAuth: Decodable {
    struct OAuth: Decodable {
        let accessToken: String?
        let subscriptionType: String?
    }
    let claudeAiOauth: OAuth?
}

private struct CodexAuth: Decodable {
    struct Tokens: Decodable {
        let access_token: String?
        let account_id: String?
    }
    let auth_mode: String?
    let tokens: Tokens?
}
