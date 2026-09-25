// StdinReadPolicyTests.swift — Unit tests for piped stdin read policy

import Foundation
import SayItDevCLI

func runStdinReadPolicyTests() {
    test("speak with explicit prompt does not read piped stdin") {
        try assertTrue(!StdinReadPolicy.shouldReadPipedStdin(mode: .speak, promptEmpty: false))
    }

    test("speak with empty prompt reads piped stdin") {
        try assertTrue(StdinReadPolicy.shouldReadPipedStdin(mode: .speak, promptEmpty: true))
    }

    test("single mode always reads piped stdin") {
        try assertTrue(StdinReadPolicy.shouldReadPipedStdin(mode: .single, promptEmpty: false))
        try assertTrue(StdinReadPolicy.shouldReadPipedStdin(mode: .single, promptEmpty: true))
    }

    test("listen does not read piped stdin") {
        try assertTrue(!StdinReadPolicy.shouldReadPipedStdin(mode: .listen, promptEmpty: true))
    }
}
