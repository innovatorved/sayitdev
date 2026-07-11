import SayItDevCore

let errors: [SayItDevError] = [
    .rateLimited,
    .contextOverflow,
    .unsupportedLanguage("tlh"),
]

for error in errors {
    print("\(error.cliLabel) \(error.localizedDescription)")
}
