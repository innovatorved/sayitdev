# Getting Started

The first tagged release that contains `SayItDevCore` is `1.1.0`. Add dev as a package dependency and depend on the `SayItDevCore` product:

```swift
dependencies: [
    .package(url: "https://github.com/innovatorved/sayitdev.git", from: "1.1.0")
],
targets: [
    .executableTarget(
        name: "MyTool",
        dependencies: [
            .product(name: "SayItDevCore", package: "sayitdev")
        ]
    )
]
```

Then import `SayItDevCore` and work with the same request, tool, and validation types dev uses internally:

```swift
import SayItDevCore

let request = ChatCompletionRequest(
    model: "sayitdev-on-device",
    messages: [
        OpenAIMessage(role: "user", content: .text("Hello"))
    ],
    stream: false,
    stream_options: nil,
    temperature: 0.2,
    max_tokens: 64,
    seed: nil,
    tools: nil,
    tool_choice: nil,
    response_format: nil,
    logprobs: nil,
    n: nil,
    stop: nil,
    presence_penalty: nil,
    frequency_penalty: nil,
    user: nil,
    x_context_strategy: nil,
    x_context_max_turns: nil,
    x_context_output_reserve: nil
)

if let failure = ChatRequestValidator.validate(request) {
    print(failure.message)
}
```

See the executable examples in [Examples](../../../Examples) for small runnable entry points.
