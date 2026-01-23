import Foundation

class EnvLoader {
    static func loadEnv() -> [String: String] {
        var env: [String: String] = [:]

        guard let envPath = Bundle.main.path(forResource: ".env.development.local", ofType: nil) else {
            print("Warning: .env.development.local file not found")
            return env
        }

        guard let content = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            print("Warning: Could not read .env.development.local file")
            return env
        }

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                env[key] = value
            }
        }

        return env
    }
}
