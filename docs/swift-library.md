# Swift Library: SayItDevCore

`SayItDevCore` is the pure, FoundationModels-free Swift Package product inside this repo. It exists for Swift developers who want the reusable policy pieces - OpenAI-compatible types, validation, MCP helpers, schema parsing, retry classification, context-trimming strategies - without depending on the `dev` executable.

**The main product is the `dev` CLI and the `dev --serve` OpenAI-compatible server.** The Swift library is a secondary surface for downstream developers. If you just want to talk to Apple's on-device model, use the CLI or the server - you do not need this library.

## When to depend on `SayItDevCore`

Good fit:

- You are writing a Swift app that calls FoundationModels directly and want to speak OpenAI-shaped JSON over the wire.
- You want dev's context-trimming strategies, tool-call parsing, or MCP protocol types without the CLI binary.
- You want the exact same error classification and retry logic that dev itself uses.

Not a fit:

- You want to run prompts from the shell -> use the `dev` CLI.
- You want a local OpenAI-compatible server -> use `dev --serve`.
- You want FoundationModels itself -> depend on Apple's framework directly. `SayItDevCore` is FoundationModels-free by design.

## Install

The first tagged release that contains `SayItDevCore` is `1.1.0`. Depend on the package product directly from `Package.swift`:

```swift
dependencies: [
    .package(url: "__UPSTREAM_DEV_URL__.git", from: "1.1.0")
],
targets: [
    .executableTarget(
        name: "MyTool",
        dependencies: [
            .product(name: "SayItDevCore", package: "dev")
        ]
    )
]
```

## Quick start

```swift
import SayItDevCore

let request = ChatCompletionRequest(
    model: "sayitdev-on-device",
    messages: [OpenAIMessage(role: "user", content: .text("Hello"))]
)
```

See [Examples/](../Examples/) for runnable samples covering OpenAI types, tool calling, MCP protocol, error handling, and context strategies.

## API surface (high level)

| Area | Representative types |
|------|---------------------|
| OpenAI types | `ChatCompletionRequest`, `OpenAIMessage`, `MessageContent`, `OpenAITool`, `ToolChoice`, `ResponseFormat` |
| Validation | Request validators for unsupported features (embeddings, logprobs, n>1) |
| Context strategies | `ContextStrategy` with 5 trimming policies |
| Tool calling | `ToolCallHandler`, JSON tool-call detection, schema conversion |
| MCP protocol | Message types + transport-agnostic client primitives |
| Error handling | `SayItDevError` with typed error classification |
| Retry logic | `withRetry`, `isRetryableError` |

Full API reference lives in the DocC catalog at [Sources/Core/SayItDevCore.docc/](../Sources/Core/SayItDevCore.docc/).

## Stability contract

`SayItDevCore` follows dev's semver. Breaking changes require a major version bump and are guarded in CI via `swift package diagnose-api-breaking-changes`. Deprecations land with `@available(*, deprecated, ...)` one release before removal.

Full policy: [STABILITY.md](../STABILITY.md).

## Examples

| Topic | Directory |
|-------|-----------|
| OpenAI request/response shapes | [Examples/OpenAITypes/](../Examples/OpenAITypes/) |
| Tool calling end-to-end | [Examples/ToolCalling/](../Examples/ToolCalling/) |
| MCP protocol primitives | [Examples/MCPProtocol/](../Examples/MCPProtocol/) |
| Error handling + retry | [Examples/ErrorHandling/](../Examples/ErrorHandling/) |
| Context-trimming strategies | [Examples/ContextStrategies/](../Examples/ContextStrategies/) |

## Architecture note

`SayItDevCore` contains zero dependencies on FoundationModels or Hummingbird. That is on purpose. The dev executable composes `SayItDevCore` with FoundationModels (for inference) and Hummingbird (for the HTTP server), but the library itself stays pure Swift so it can be unit-tested, cross-compiled, and embedded into apps that do their own FoundationModels calls.
