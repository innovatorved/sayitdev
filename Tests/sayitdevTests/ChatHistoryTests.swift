// ChatHistoryTests - persistent chat-history opt-in decision logic (#259)

import Foundation
import SayItDevCLI

func runChatHistoryTests() {
    test("history is off by default (env var absent -> nil)") {
        try assertNil(ChatHistory.filePath(env: [:]))
    }

    test("empty DEV_HISTFILE is treated as absence (nil)") {
        try assertNil(ChatHistory.filePath(env: ["DEV_HISTFILE": ""]))
    }

    test("whitespace-only DEV_HISTFILE is treated as absence (nil)") {
        try assertNil(ChatHistory.filePath(env: ["DEV_HISTFILE": "   "]))
    }

    test("DEV_HISTFILE with an absolute path is returned verbatim") {
        try assertEqual(
            ChatHistory.filePath(env: ["DEV_HISTFILE": "/tmp/apfel_hist"]),
            "/tmp/apfel_hist"
        )
    }

    test("DEV_HISTFILE leading tilde is expanded to home") {
        let home = NSHomeDirectory()
        try assertEqual(
            ChatHistory.filePath(env: ["DEV_HISTFILE": "~/.dev_history"]),
            home + "/.dev_history"
        )
    }

    test("surrounding whitespace is trimmed before use") {
        try assertEqual(
            ChatHistory.filePath(env: ["DEV_HISTFILE": "  /tmp/h  "]),
            "/tmp/h"
        )
    }

    test("history bound matches the in-memory stifle limit") {
        try assertEqual(ChatHistory.maxEntries, 500)
    }
}
