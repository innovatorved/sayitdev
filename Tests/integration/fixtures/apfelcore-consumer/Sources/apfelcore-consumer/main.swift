import SayItDevCore

let message = OpenAIMessage(role: "user", content: .text("hello"))
print("\(message.textContent ?? "nil")|\(ContextStrategy.slidingWindow.rawValue)")
