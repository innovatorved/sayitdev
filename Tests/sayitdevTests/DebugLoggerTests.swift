import Foundation
import SayItDevCore

func runDebugLoggerTests() {
    test("SayItDevDebugConfiguration defaults to false") {
        try assertEqual(SayItDevDebugConfiguration.isEnabled, false)
    }
    test("SayItDevDebugConfiguration can be toggled") {
        let original = SayItDevDebugConfiguration.isEnabled
        defer { SayItDevDebugConfiguration.isEnabled = original }
        SayItDevDebugConfiguration.isEnabled = true
        try assertEqual(SayItDevDebugConfiguration.isEnabled, true)
    }
}
