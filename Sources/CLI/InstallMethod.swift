// ============================================================================
// InstallMethod.swift — Detect how the dev binary was installed.
//
// The self-update flow (`dev --update`) prints different instructions per
// install method. Detection is path-based (no network, no shell-outs), which
// keeps it cheap, fast, and offline.
// ============================================================================

import Foundation

public enum InstallMethod: Equatable, Sendable {
    case homebrew
    case macports
    case source
}

/// Classify how a binary was installed based on its absolute (symlink-resolved)
/// path on disk.
///
/// - `homebrew`: path lives under `*/homebrew/Cellar/dev/` or `*/homebrew/opt/dev/`.
/// - `macports`: binary lives at `<prefix>/bin/dev` and `<prefix>/var/macports`
///   exists as a directory. This is the canonical MacPorts marker and works for
///   the default `/opt/local` prefix and custom prefixes alike.
/// - `source`: anything else (manual `make install`, `swift build`, custom dir).
public func detectInstallMethod(
    binaryPath: String,
    fileManager: FileManager = .default
) -> InstallMethod {
    if binaryPath.contains("/homebrew/Cellar/dev/") || binaryPath.contains("/homebrew/opt/dev/") {
        return .homebrew
    }

    let prefixURL = URL(fileURLWithPath: binaryPath)
        .deletingLastPathComponent()  // <prefix>/bin
        .deletingLastPathComponent()  // <prefix>
    let macportsMarker = prefixURL.appendingPathComponent("var/macports").path
    var isDir: ObjCBool = false
    if fileManager.fileExists(atPath: macportsMarker, isDirectory: &isDir), isDir.boolValue {
        return .macports
    }

    return .source
}

/// Derive the Homebrew prefix from a resolved dev binary path.
///
/// For a Cellar install `<prefix>/Cellar/dev/<version>/bin/dev` or an opt
/// symlink `<prefix>/opt/dev/bin/dev`, returns `<prefix>` - e.g.
/// `/opt/homebrew` (Apple Silicon default), `/usr/local` (Intel default), or a
/// custom prefix such as `/Users/me/homebrew`. `brew` and the installed `dev`
/// then live at `<prefix>/bin/brew` and `<prefix>/bin/dev`.
///
/// Returns nil when the path is not a recognizable Homebrew layout, so callers
/// can fall back to locating `brew` on `PATH` instead of hardcoding a prefix
/// (#260).
public func homebrewPrefix(fromBinaryPath path: String) -> String? {
    for marker in ["/Cellar/dev/", "/opt/dev/"] {
        if let range = path.range(of: marker) {
            let prefix = String(path[path.startIndex..<range.lowerBound])
            return prefix.isEmpty ? nil : prefix
        }
    }
    return nil
}
