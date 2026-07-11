# Error Handling

`SayItDevError` provides a stable, typed classification layer around runtime failures that matter to callers:

- user-facing labels via ``SayItDevError/cliLabel``
- OpenAI-compatible error types and HTTP statuses
- retryability via ``SayItDevError/isRetryable``

For MCP and request validation, use:

- ``MCPError``
- ``ChatRequestValidationFailure``
- ``UnsupportedChatParameter``

These types are designed to give downstream callers stable messages without forcing them to parse localized or framework-specific strings.
