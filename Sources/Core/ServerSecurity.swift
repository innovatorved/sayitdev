// ============================================================================
// ServerSecurity.swift - Pure server-hardening predicates (host classification,
// startup-warning gates, Host-header allowlisting, MCP env scrubbing).
// Lives in SayItDevCore so it is unit-testable without Hummingbird or Foundation
// networking.
// ============================================================================

/// Pure decision logic for server security hardening. No I/O, no framework
/// dependencies - just predicates the CLI/server/MCP layers consult.
public enum ServerSecurity {

    /// True if `host` is a loopback bind address (traffic never leaves the box).
    public static func isLoopbackHost(_ host: String) -> Bool {
        switch host.lowercased() {
        case "127.0.0.1", "localhost", "::1", "[::1]":
            return true
        default:
            return false
        }
    }

    /// True when the server is bound to a non-loopback address with no bearer
    /// token: every host that can reach the socket can hit the inference
    /// endpoints with zero authentication (#228). Callers surface a loud warning.
    public static func shouldWarnExposedWithoutToken(host: String, hasToken: Bool) -> Bool {
        return !isLoopbackHost(host) && !hasToken
    }

    /// True when startup must refuse a non-loopback bind without authentication.
    /// Operators may pass `--i-know-what-im-doing` to override (#228 hardening).
    public static func shouldRefuseExposedWithoutToken(
        host: String, hasToken: Bool, allowInsecureOverride: Bool
    ) -> Bool {
        if allowInsecureOverride { return false }
        return shouldWarnExposedWithoutToken(host: host, hasToken: hasToken)
    }

    /// True when `--serve` attaches MCP servers but no bearer token protects HTTP.
    public static func shouldRefuseServeMCPWithoutToken(hasMCPServers: Bool, hasToken: Bool) -> Bool {
        return hasMCPServers && !hasToken
    }

    /// Blocklist for remote MCP Streamable HTTP URLs (SSRF defense). Accepts only
    /// public hostnames on ports 80/443 (or scheme defaults) and loopback literals
    /// for local dev (`127.0.0.1`, `localhost`, `::1`). Private/link-local/metadata
    /// IP literals and known cloud metadata hostnames are rejected.
    public static func isAllowedRemoteMCPHost(hostname: String, port: Int?) -> Bool {
        let host = hostname.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !host.isEmpty else { return false }

        if blockedRemoteMCPHostnames.contains(host) { return false }

        if isLoopbackHost(host) || host == "127.0.0.1" {
            return true
        }

        if let port, port != 80 && port != 443 {
            return false
        }

        if let octets = parseIPv4(host) {
            return !isBlockedIPv4(octets)
        }

        if host.hasPrefix("[") && host.hasSuffix("]") {
            let inner = String(host.dropFirst().dropLast())
            if inner == "::1" { return true }
            return false
        }
        if host.contains(":") {
            // Unbracketed IPv6 literals are rejected; only [::1] loopback is allowed above.
            return false
        }

        return true
    }

    /// Minimal environment handed to a local (stdio) MCP subprocess (#229).
    ///
    /// A `Process` with `environment == nil` inherits dev's entire environment,
    /// leaking `DEV_TOKEN`/`DEV_MCP_TOKEN` and any cloud/API keys in the shell
    /// to the third-party tool script. This returns an explicit allowlist instead:
    /// PATH/HOME/TMPDIR/LANG plus `LC_*`, `PYTHON*`, and `VIRTUAL_ENV` (what the
    /// calculator server and typical FastMCP/venv servers need). Everything else
    /// is dropped, and any `DEV_*` var or any var whose name contains
    /// TOKEN/KEY/SECRET is excluded even if it would otherwise match. PATH is
    /// synthesized when absent so `/usr/bin/env python3` still resolves.
    public static func scrubbedMCPEnvironment(from parent: [String: String]) -> [String: String] {
        let exactAllow: Set<String> = ["PATH", "HOME", "TMPDIR", "LANG", "VIRTUAL_ENV"]
        let prefixAllow = ["LC_", "PYTHON"]
        var result: [String: String] = [:]
        for (key, value) in parent {
            let upper = key.uppercased()
            // Exclusions win over the allowlist.
            if upper.hasPrefix("DEV_") { continue }
            if upper.hasPrefix("AWS_") || upper.hasPrefix("GITHUB_") || upper.hasPrefix("OPENAI_") { continue }
            if upper.contains("TOKEN") || upper.contains("KEY") || upper.contains("SECRET") { continue }
            if exactAllow.contains(upper) || prefixAllow.contains(where: { upper.hasPrefix($0) }) {
                result[key] = value
            }
        }
        if result["PATH"] == nil {
            result["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        }
        return result
    }

    /// DNS-rebinding defense: is this request's `Host` header acceptable? (#230)
    ///
    /// Same-origin GET requests carry no Origin header, so origin checking alone
    /// cannot stop a rebinding page (`attacker.com` re-resolved to `127.0.0.1`)
    /// from reading `/health` and `/v1/models`. The canonical defense is a Host
    /// allowlist: accept only loopback names (`localhost`, `127.0.0.1`, `[::1]`,
    /// with or without a port) and the configured bind host. A missing/empty
    /// Host is allowed - there is nothing to rebind. Callers apply this only when
    /// bound to a loopback host; a deliberately network-exposed bind (`0.0.0.0`)
    /// receives Host headers we cannot enumerate and is the operator's choice.
    public static func isAllowedHostHeader(_ hostHeader: String?, bindHost: String) -> Bool {
        guard let hostHeader, !hostHeader.isEmpty else { return true }
        let name = hostWithoutPort(hostHeader).lowercased()
        let allowed: Set<String> = ["localhost", "127.0.0.1", "::1", "[::1]", bindHost.lowercased()]
        return allowed.contains(name)
    }

    // MARK: - Private

    private static let blockedRemoteMCPHostnames: Set<String> = [
        "metadata.google.internal",
        "metadata.google",
        "169.254.169.254",
    ]

    private static func parseIPv4(_ host: String) -> [Int]? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var octets: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.count <= 3, part.allSatisfy(\.isNumber), let value = Int(part), value >= 0, value <= 255 else {
                return nil
            }
            octets.append(value)
        }
        return octets
    }

    private static func isBlockedIPv4(_ octets: [Int]) -> Bool {
        guard octets.count == 4 else { return true }
        let a = octets[0], b = octets[1]
        if a == 10 { return true }
        if a == 172 && (16...31).contains(b) { return true }
        if a == 192 && b == 168 { return true }
        if a == 169 && b == 254 { return true }
        if a == 127 { return octets != [127, 0, 0, 1] }
        if a == 0 { return true }
        return false
    }

    /// Strip an optional `:port` suffix, keeping bracketed IPv6 literals intact.
    private static func hostWithoutPort(_ s: String) -> String {
        if s.hasPrefix("[") {
            // "[::1]" or "[::1]:8080" -> "[::1]"
            if let close = s.firstIndex(of: "]") {
                return String(s[...close])
            }
            return s
        }
        // "host:port" -> "host", but only when the suffix is a numeric port
        // (a bare unbracketed IPv6 like "::1" has no numeric-only tail).
        if let colon = s.lastIndex(of: ":") {
            let portPart = s[s.index(after: colon)...]
            if !portPart.isEmpty && portPart.allSatisfy(\.isNumber) {
                return String(s[..<colon])
            }
        }
        return s
    }
}
