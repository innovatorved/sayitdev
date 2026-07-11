// ============================================================================
// main.swift — Entry point for dev
// Apple Intelligence from the command line.
// https://github.com/innovatorved/sayitdev
// ============================================================================

import Foundation
import SayItDevCore
import SayItDevCLI
import CReadline

// MARK: - Configuration

let version = buildVersion
let appName = "dev"
let modelName = "sayitdev-on-device"

// MARK: - Exit Codes
// Declared as `let` here (not the SayItDevExitCodes struct) so the
// man-page bidirectional-coverage test (test_bidirectional_exit_code_coverage)
// can still scrape them via its `let\s+exit\w+` regex. Values are delegated
// to SayItDevCLI.SayItDevExitCodes to keep the mapping unit-testable.

let exitSuccess: Int32 = SayItDevExitCodes.success
let exitRuntimeError: Int32 = SayItDevExitCodes.runtimeError
let exitUsageError: Int32 = SayItDevExitCodes.usageError
let exitGuardrail: Int32 = SayItDevExitCodes.guardrail
let exitContextOverflow: Int32 = SayItDevExitCodes.contextOverflow
let exitModelUnavailable: Int32 = SayItDevExitCodes.modelUnavailable
let exitRateLimited: Int32 = SayItDevExitCodes.rateLimited

/// Map an SayItDevError to the appropriate exit code.
/// Thin wrapper around SayItDevExitCodes.code(for:) (see Sources/CLI/ExitCodes.swift)
/// so the mapping is unit-testable.
func exitCode(for error: SayItDevError) -> Int32 {
    SayItDevExitCodes.code(for: error)
}

// MARK: - Locale

// Adopt the user's LC_CTYPE from the environment (LANG/LC_*). dev otherwise
// runs in the "C" locale, and libedit's multibyte handling (mbrtowc/ct_encode)
// keys off LC_CTYPE - without this, chat line editing of non-ASCII input
// (backspace/arrow over "ü"/emoji) operates byte-wise and corrupts the line.
// Must run before any ChatLineEditor is constructed (#256).
setlocale(LC_CTYPE, "")

// MARK: - Signal Handling

dev_install_sigint_exit_handler(isatty(STDOUT_FILENO) != 0 ? 1 : 0)

// Ignore SIGPIPE process-wide. A crashed MCP server (or any closed pipe/socket
// peer) must not kill dev: writes to a dead pipe would otherwise raise SIGPIPE
// with the default disposition and terminate the process (exit 141), taking down
// the whole --serve HTTP server. With SIG_IGN the write instead fails with EPIPE,
// which the throwing write path in MCPClient maps to a recoverable error (#215).
signal(SIGPIPE, SIG_IGN)

// True when stdin is a FIFO/pipe (`command | dev`) vs a regular file
// redirect (`dev < file`). We only suggest `2>&1` for the pipe case;
// regular files don't need that advice.
func stdinIsPipe() -> Bool {
    var st = stat()
    guard fstat(STDIN_FILENO, &st) == 0 else { return false }
    return (st.st_mode & S_IFMT) == S_IFIFO
}

/// Read all of stdin as raw bytes — works for piped text and piped binary files alike.
/// Bounded by `BodyLimits.maxStdinBytes` to prevent OOM from unbounded pipes.
func readStdinData() throws -> Data {
    let handle = FileHandle.standardInput
    let limit = BodyLimits.maxStdinBytes
    var data = Data()
    data.reserveCapacity(min(limit, 65536))
    while true {
        guard let chunk = try handle.read(upToCount: 65536) else { break }
        if chunk.isEmpty { break }
        data.append(chunk)
        if data.count > limit {
            printError("stdin exceeds \(limit / (1024 * 1024)) MiB limit")
            throw ExitSignal.usage
        }
    }
    return data
}

/// Turn piped stdin into prompt text: a piped PDF or image is extracted via lesbar
/// (OCR + "what the image is about", same as `-f`); anything else is decoded as UTF-8
/// text — dev's existing pipe behaviour. Empty stdin returns "".
/// Throws `CLIParseError` when the bytes are a PDF/image but extraction fails.
func stdinPromptText(_ data: Data) throws -> String {
    if data.isEmpty { return "" }
    if let extracted = try LesbarFileReader.extractPipedIfBinary(data) {
        return extracted
    }
    return (String(data: data, encoding: .utf8) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Argument Parsing

let rawArgs = Array(CommandLine.arguments.dropFirst())

// No args AND stdin is a TTY: nothing to read, nothing to do -> usage + exit 2.
// This is the only no-args special case. The bare-pipe case (`echo hi | dev`)
// used to be a fast path that ran BEFORE parse() and therefore dropped every
// DEV_* env var and skipped the model-availability gate (#222). It now flows
// through the normal parse()/dispatch path below.
if rawArgs.isEmpty && isatty(STDIN_FILENO) != 0 {
    printUsage(to: stderr)
    exit(exitUsageError)
}

// True for the bare-pipe invocation (`echo hi | dev` with no flags). It
// streams by default to preserve the historical output behavior of that path.
let noArgsPipe = rawArgs.isEmpty

// Pure, testable parsing. Errors land here as CLIParseError.
let parsed: CLIArguments
do {
    parsed = try CLIArguments.parse(
        rawArgs,
        env: ProcessInfo.processInfo.environment,
        extractFile: { try LesbarFileReader.extractForPrompt(path: $0) }
    )
} catch let error as CLIParseError {
    printError(error.message)
    exit(exitUsageError)
}

// Handle immediate-exit modes.
switch parsed.mode {
case .help:
    printUsage()
    exit(exitSuccess)
case .version:
    print("\(appName) v\(version)")
    exit(exitSuccess)
case .release:
    printRelease()
    exit(exitSuccess)
case .demos:
    exit(runDemosInstall(target: parsed.demosTarget))
case .completions:
    if let shell = parsed.completionsShell {
        print(ShellCompletions.generate(for: shell), terminator: "")
    }
    exit(exitSuccess)
default:
    break
}

// Apply parsed values to global state used throughout the main target.
if let fmt = parsed.outputFormat { outputFormat = fmt }
if parsed.quiet { quietMode = true }
if parsed.noColor { noColorFlag = true }
if parsed.debug { SayItDevDebugConfiguration.isEnabled = true }

// Surface non-fatal parse warnings (invalid DEV_* env values ignored in
// favor of defaults) on stderr unless --quiet. Collected by parse() so it
// stays pure; printed here (#254).
if !quietMode {
    for warning in parsed.warnings {
        printStderr("\(styledErr("dev:", .yellow)) \(warning)")
    }
}

// Prewarm the model concurrently with input I/O (#364). Fire-and-forget so
// the model cold-start overlaps the stdin read / conversation parsing below
// instead of following it serially; in chat mode it overlaps the user typing
// the first message. TokenCounter.prewarm() no-ops when the model is
// unavailable, so the exit-5 path is untouched. The server path prewarms in
// startServer (#169), never here.
if PrewarmDecision.shouldPrewarm(mode: parsed.mode) {
    debugLog("prewarm", "firing model prewarm before input read (mode=\(parsed.mode.rawValue))")
    Task.detached(priority: .userInitiated) {
        _ = await TokenCounter.shared.prewarm()
    }
}

// Build the prompt: positional args + piped stdin + attached files.
var prompt = parsed.prompt
var fileContents = parsed.fileContents
var pipedContent: String? = nil

// One-shot multi-turn (#363): resolve the conversation JSON. `--messages -`
// consumes piped stdin as the conversation, so the prompt-stdin block below
// is skipped for every --messages invocation.
var messagesJSON = parsed.messagesJSON
if parsed.messagesFromStdin {
    guard isatty(STDIN_FILENO) == 0 else {
        printError("--messages - requires a piped JSON conversation on stdin")
        exit(exitUsageError)
    }
    let raw: String
    do {
        raw = String(data: try readStdinData(), encoding: .utf8) ?? ""
    } catch ExitSignal.usage {
        exit(exitUsageError)
    } catch {
        printError("failed to read stdin: \(error.localizedDescription)")
        exit(exitUsageError)
    }
    do {
        _ = try MessagesInput.decode(raw)
    } catch let e as MessagesInput.Error {
        printError("invalid --messages JSON from stdin: \(e.message)")
        exit(exitUsageError)
    }
    messagesJSON = raw
}

// Read stdin when piped (single/stream/count-tokens) -- as the prompt (no args) or prepended to the prompt.
if messagesJSON == nil && parsed.mode.acceptsStdinInput && isatty(STDIN_FILENO) == 0 {
    let readPipedStdin = StdinReadPolicy.shouldReadPipedStdin(mode: parsed.mode, promptEmpty: parsed.prompt.isEmpty)
    if readPipedStdin {
    let stdinContent: String
    do {
        stdinContent = try stdinPromptText(try readStdinData())
    } catch ExitSignal.usage {
        exit(exitUsageError)
    } catch let error as CLIParseError {
        printError(error.message)
        exit(exitUsageError)
    }
    if !stdinContent.isEmpty {
        pipedContent = stdinContent
        if prompt.isEmpty && fileContents.isEmpty {
            prompt = stdinContent
        } else {
            fileContents.append(stdinContent)
        }
    } else if !quietMode && stdinIsPipe() {
        // Empty pipe: hint about stderr redirection. Fires whether or not a
        // prompt was given, so the bare-pipe case (`somecmd | dev`, no args)
        // still gets the hint now that it flows through this path (#152, #222).
        printStderr("\(styledErr("dev:", .yellow)) piped input was empty - if the command prints to stderr, try: command 2>&1 | dev")
    }
    }
}

// Prepend file/stdin content to the prompt.
if !fileContents.isEmpty {
    let combined = fileContents.joined(separator: "\n\n")
    if prompt.isEmpty {
        prompt = combined
    } else {
        prompt = combined + "\n\n" + prompt
    }
}

// Debuggable: with --debug, show exactly what each file extracted to and the full
// prompt that goes to the model, so you can see what dev actually puts to the API.
if SayItDevDebugConfiguration.isEnabled {
    for attachment in parsed.fileAttachments {
        debugLog("extract", "\(attachment.path) -> \(attachment.content.count) chars:\n\(attachment.content)")
    }
    debugLog("prompt", "final prompt to model (\(prompt.count) chars):\n\(prompt)")
}

// MARK: - Dispatch

let contextConfig = ContextConfig(
    strategy: parsed.contextStrategy ?? .newestFirst,
    maxTurns: parsed.contextMaxTurns,
    outputReserve: parsed.contextOutputReserve ?? BodyLimits.defaultOutputReserveTokens,
    permissive: parsed.permissive
)

let sessionOpts = SessionOptions(
    temperature: parsed.temperature,
    topP: parsed.topP,
    maxTokens: parsed.maxTokens,
    seed: parsed.seed,
    permissive: parsed.permissive,
    contextConfig: contextConfig,
    retryEnabled: parsed.retryEnabled,
    retryCount: parsed.retryCount
)

// Resolve the final allowed-origins list: defaults + any CLI-specified values.
let serverAllowedOrigins: [String] = {
    var origins = OriginValidator.defaultAllowedOrigins
    for origin in parsed.serverAllowedOrigins where !origins.contains(origin) {
        origins.append(origin)
    }
    return origins
}()

// Reject empty-prompt single/stream invocations BEFORE the model-availability
// gate, so "nothing to do" is a usage error (exit 2) regardless of whether the
// model is available. This preserves the old bare-pipe behavior: an empty pipe
// with no args prints the hint above and exits 2 without touching the model.
if (parsed.mode == .single || parsed.mode == .stream || parsed.mode == .speak) && prompt.isEmpty && messagesJSON == nil {
    if parsed.mode == .speak && isatty(STDIN_FILENO) == 0 {
        // stdin pipe provides speak text
    } else {
        printError(parsed.mode == .speak ? "no text provided for --speak" : "no prompt provided")
        exit(exitUsageError)
    }
}

let voiceConfig = VoiceConfig.resolve(from: parsed, env: ProcessInfo.processInfo.environment)

// Check model availability for modes that need it.
switch parsed.mode {
case .modelInfo, .serve, .update, .countTokens, .speak, .listen, .transcribe:
    break
default:
    let availability = await TokenCounter.shared.availability
    if !availability.isAvailable {
        printError("Model unavailable: \(availability.shortLabel)")
        printStderr("")
        printStderr(availability.remediation)
        printStderr("")
        printStderr("For full diagnostic info run: dev --model-info")
        exit(exitModelUnavailable)
    }
}

// Initialize MCP servers if any.
var mcpManager: MCPManager?
if !parsed.mcpServerPaths.isEmpty {
    do {
        mcpManager = try await MCPManager(paths: parsed.mcpServerPaths, bearerToken: parsed.mcpBearerToken, timeoutSeconds: parsed.mcpTimeoutSeconds)
    } catch {
        printError("MCP server failed to start: \(error)")
        exit(exitRuntimeError)
    }
}

// Shut MCP servers down before the process exits. This must be an awaited call
// on every exit path, NOT a `defer { Task { ... } }`: async main returns and the
// process exits before an unstructured Task is ever scheduled, so children would
// only die on stdin EOF (a server ignoring EOF is orphaned) and the remote DELETE
// would never fire. terminate() + bounded waitUntilExit() reaps locals; the
// remote branch awaits its DELETE (#246).
func shutdownMCP() async {
    await mcpManager?.shutdown()
}

do {
    switch parsed.mode {
    case .serve:
        var serverToken = parsed.serverToken
        let tokenWasAutoGenerated = parsed.serverTokenAuto && serverToken == nil
        if parsed.serverTokenAuto && serverToken == nil {
            serverToken = UUID().uuidString
        }
        if ServerSecurity.shouldRefuseExposedWithoutToken(
            host: parsed.serverHost,
            hasToken: serverToken != nil,
            allowInsecureOverride: parsed.serverAllowInsecureBind
        ) {
            printError(
                "refusing to bind to \(parsed.serverHost) without a token: " +
                "any host on your network could access inference endpoints unauthenticated. " +
                "Set --token <secret>, --token-auto, or pass --i-know-what-im-doing to override. " +
                "See docs/server-security.md"
            )
            await shutdownMCP()
            exit(exitUsageError)
        }
        if ServerSecurity.shouldRefuseServeMCPWithoutToken(
            hasMCPServers: !parsed.mcpServerPaths.isEmpty,
            hasToken: serverToken != nil
        ) {
            printError(
                "--serve with --mcp requires a bearer token so HTTP clients cannot trigger MCP tool execution. " +
                "Set --token <secret>, --token-auto, or DEV_TOKEN."
            )
            await shutdownMCP()
            exit(exitUsageError)
        }
        let config = ServerConfig(
            host: parsed.serverHost,
            port: parsed.serverPort,
            cors: parsed.serverCORS,
            maxConcurrent: parsed.serverMaxConcurrent,
            debug: parsed.debug,
            allowedOrigins: parsed.serverOriginCheckEnabled ? serverAllowedOrigins : ["*"],
            originCheckEnabled: parsed.serverOriginCheckEnabled,
            token: serverToken,
            tokenWasAutoGenerated: tokenWasAutoGenerated,
            publicHealth: parsed.serverPublicHealth,
            retryEnabled: parsed.retryEnabled,
            retryCount: parsed.retryCount,
            permissive: parsed.permissive,
            allowInsecureBind: parsed.serverAllowInsecureBind
        )
        try await startServer(config: config, mcpManager: mcpManager, voiceConfig: voiceConfig)

    case .update:
        performUpdate()

    case .modelInfo:
        await printModelInfo()

    case .benchmark:
        try await runBenchmarks()

    case .speak:
        do {
            try await VoiceCommands.runSpeak(text: prompt, config: voiceConfig)
        } catch ExitSignal.usage {
            await shutdownMCP()
            exit(exitUsageError)
        }

    case .listen:
        do {
            try await VoiceCommands.runListen(config: voiceConfig)
        } catch SpeechInputError.permissionDenied(let msg) {
            printError(msg)
            await shutdownMCP()
            exit(SayItDevExitCodes.micPermissionDenied)
        } catch SpeechInputError.assetInstallFailed {
            printError(SpeechInputError.assetInstallFailed.localizedDescription)
            await shutdownMCP()
            exit(SayItDevExitCodes.speechAssetFailed)
        } catch SpeechInputError.noInputDevice {
            printError(SpeechInputError.noInputDevice.localizedDescription)
            await shutdownMCP()
            exit(SayItDevExitCodes.noInputDevice)
        } catch SpeechInputError.microphoneNoAudio {
            printError(SpeechInputError.microphoneNoAudio.localizedDescription)
            await shutdownMCP()
            exit(SayItDevExitCodes.noInputDevice)
        } catch SpeechInputError.emptyAudio {
            printError("No speech detected")
            await shutdownMCP()
            exit(exitUsageError)
        }

    case .transcribe:
        do {
            try await VoiceCommands.runTranscribe(path: parsed.transcribePath ?? "", config: voiceConfig)
        } catch ExitSignal.usage {
            await shutdownMCP()
            exit(exitUsageError)
        } catch SpeechInputError.permissionDenied(let msg) {
            printError(msg)
            await shutdownMCP()
            exit(SayItDevExitCodes.micPermissionDenied)
        } catch SpeechInputError.assetInstallFailed {
            printError(SpeechInputError.assetInstallFailed.localizedDescription)
            await shutdownMCP()
            exit(SayItDevExitCodes.speechAssetFailed)
        } catch SpeechInputError.emptyAudio {
            printError("No speech detected in audio")
            await shutdownMCP()
            exit(exitUsageError)
        }

    case .chat:
        // `-f file` / piped / positional content is merged into `prompt` above;
        // seed it into the chat context instead of dropping it silently (#370).
        try await chat(systemPrompt: parsed.systemPrompt, initialContext: prompt.isEmpty ? nil : prompt, options: sessionOpts, mcpManager: mcpManager, contextStatus: parsed.contextStatus)

    case .stream:
        if let messagesJSON {
            // --messages --stream: stream the next assistant turn (#363).
            try await messagesPrompt(
                messagesJSON: messagesJSON, systemPrompt: parsed.systemPrompt,
                stream: true, schemaJSON: parsed.schemaJSON, schemaName: parsed.schemaName,
                options: sessionOpts, mcpManager: mcpManager)
        } else {
            guard !prompt.isEmpty else {
                printError("no prompt provided")
                await shutdownMCP()
                exit(exitUsageError)
            }
            try await singlePrompt(prompt, systemPrompt: parsed.systemPrompt, stream: true, options: sessionOpts, mcpManager: mcpManager)
        }

    case .single:
        // --code (#373): append the steering directive so the model answers
        // with exactly one fenced block; the deterministic crop happens in
        // singlePrompt/messagesPrompt regardless of compliance.
        let effectiveSystemPrompt = parsed.codeOnly
            ? [parsed.systemPrompt, CodeCropper.steeringDirective].compactMap { $0 }.joined(separator: "\n\n")
            : parsed.systemPrompt
        if let messagesJSON {
            // --messages: one-shot multi-turn (#363); composes with --schema.
            let status = try await messagesPrompt(
                messagesJSON: messagesJSON, systemPrompt: effectiveSystemPrompt,
                stream: false, schemaJSON: parsed.schemaJSON, schemaName: parsed.schemaName,
                options: sessionOpts, mcpManager: mcpManager, codeOnly: parsed.codeOnly)
            if status != 0 {
                await shutdownMCP()
                exit(status)
            }
        } else if prompt.isEmpty {
            printError("no prompt provided")
            await shutdownMCP()
            exit(exitUsageError)
        } else if let schemaJSON = parsed.schemaJSON {
            // --schema: schema-guaranteed structured output (#361). Validated
            // at parse time; MCP/stream/chat combinations are rejected there.
            try await structuredSinglePrompt(
                prompt, systemPrompt: parsed.systemPrompt,
                schemaJSON: schemaJSON, schemaName: parsed.schemaName ?? "schema",
                options: sessionOpts)
        } else {
            // The bare-pipe case (`echo hi | dev`) streams to preserve its
            // historical output behavior; an explicit prompt does not (#222).
            let status = try await singlePrompt(prompt, systemPrompt: effectiveSystemPrompt, stream: noArgsPipe, options: sessionOpts, mcpManager: mcpManager, codeOnly: parsed.codeOnly)
            if status != 0 {
                await shutdownMCP()
                exit(status)
            }
        }

    case .countTokens:
        guard !prompt.isEmpty || parsed.systemPrompt != nil else {
            printError("no prompt or file content provided")
            await shutdownMCP()
            exit(exitUsageError)
        }
        let report = try await countTokens(
            mergedPrompt: prompt,
            positionalPrompt: parsed.prompt,
            pipedContent: pipedContent,
            fileAttachments: parsed.fileAttachments,
            systemPrompt: parsed.systemPrompt,
            options: sessionOpts,
            mcpManager: mcpManager
        )
        if parsed.strictCount && !report.fits {
            await shutdownMCP()
            exit(exitContextOverflow)
        }

    case .help, .version, .release, .demos, .completions:
        break   // Already handled above; exhaustive switch.
    }
} catch {
    let classified = SayItDevError.classify(error)
    printError("\(classified.cliLabel) \(classified.openAIMessage)")
    await shutdownMCP()
    exit(exitCode(for: classified))
}

// Normal completion: await MCP shutdown before the process exits (#246).
await shutdownMCP()
