// ============================================================================
// DebugFlagBaselineTests.swift — Package-internal contract for the future-safe debug
// configuration introduced by issue #105.
//
// The old `nonisolated(unsafe) var apfelDebugEnabled` was data-race-prone and
// not library-grade. The replacement must still be easy to use from sync and
// async contexts, but it should remain package-scoped instead of leaking into
// the public `SayItDevCore` semver surface.
// ============================================================================

import Foundation
import SayItDevCore

func runDebugFlagBaselineTests() {
    test("SayItDevDebugConfiguration.isEnabled is typed as Bool") {
        let snapshot: Bool = SayItDevDebugConfiguration.isEnabled
        try assertTrue(snapshot == true || snapshot == false)
    }

    test("SayItDevDebugConfiguration.isEnabled has default value false at test-runner startup") {
        try assertEqual(SayItDevDebugConfiguration.isEnabled, false)
    }

    test("SayItDevDebugConfiguration supports synchronous write + read") {
        let original = SayItDevDebugConfiguration.isEnabled
        defer { SayItDevDebugConfiguration.isEnabled = original }
        SayItDevDebugConfiguration.isEnabled = true
        try assertEqual(SayItDevDebugConfiguration.isEnabled, true)
        SayItDevDebugConfiguration.isEnabled = false
        try assertEqual(SayItDevDebugConfiguration.isEnabled, false)
    }

    test("nested save/restore idiom restores prior value") {
        let original = SayItDevDebugConfiguration.isEnabled
        defer { SayItDevDebugConfiguration.isEnabled = original }

        SayItDevDebugConfiguration.isEnabled = true
        do {
            let inner = SayItDevDebugConfiguration.isEnabled
            defer { SayItDevDebugConfiguration.isEnabled = inner }
            SayItDevDebugConfiguration.isEnabled = false
            try assertEqual(SayItDevDebugConfiguration.isEnabled, false)
        }
        try assertEqual(SayItDevDebugConfiguration.isEnabled, true)
    }

    testAsync("SayItDevDebugConfiguration reads synchronously from an async context") {
        let _: Bool = SayItDevDebugConfiguration.isEnabled
    }

    testAsync("SayItDevDebugConfiguration writes synchronously from an async context") {
        let original = SayItDevDebugConfiguration.isEnabled
        defer { SayItDevDebugConfiguration.isEnabled = original }
        SayItDevDebugConfiguration.isEnabled = true
        try assertEqual(SayItDevDebugConfiguration.isEnabled, true)
    }
}
