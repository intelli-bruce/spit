import Foundation
import MessagePack

/// Neovim --embed 프로세스 관리
actor NeovimProcess {
    private var process: Process?
    private var stdin: FileHandle?
    private var stdout: FileHandle?
    private var msgId: UInt32 = 0

    private var pendingRequests: [UInt32: CheckedContinuation<MessagePackValue, Error>] = [:]
    private var notificationHandler: ((String, [MessagePackValue]) -> Void)?
    private var redrawHandler: (([[MessagePackValue]]) -> Void)?

    private var readBuffer = Data()

    init() {}

    // MARK: - Process Management

    func start() async throws {
        // Find nvim binary
        let nvimPath = findNvimPath()
        guard FileManager.default.fileExists(atPath: nvimPath) else {
            throw NeovimError.nvimNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: nvimPath)
        process.arguments = ["--embed"]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        self.stdin = stdinPipe.fileHandleForWriting
        self.stdout = stdoutPipe.fileHandleForReading
        self.process = process

        try process.run()

        // Start reading responses
        Task {
            await readLoop()
        }

        // Attach UI
        try await attachUI(width: 80, height: 24)
    }

    func stop() {
        process?.terminate()
        process = nil
        stdin = nil
        stdout = nil
    }

    private func findNvimPath() -> String {
        // Check common locations
        let paths = [
            "/opt/homebrew/bin/nvim",
            "/usr/local/bin/nvim",
            "/usr/bin/nvim"
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return "/opt/homebrew/bin/nvim"
    }

    // MARK: - RPC

    private func attachUI(width: Int, height: Int) async throws {
        let options: MessagePackValue = .map([
            .string("rgb"): .bool(true),
            .string("ext_linegrid"): .bool(true),
            .string("ext_multigrid"): .bool(false)
        ])

        _ = try await call("nvim_ui_attach", args: [
            .int(Int64(width)),
            .int(Int64(height)),
            options
        ])
    }

    func resizeUI(width: Int, height: Int) async throws {
        _ = try await call("nvim_ui_try_resize", args: [
            .int(Int64(width)),
            .int(Int64(height))
        ])
    }

    func input(_ keys: String) async throws {
        _ = try await call("nvim_input", args: [.string(keys)])
    }

    func command(_ cmd: String) async throws {
        _ = try await call("nvim_command", args: [.string(cmd)])
    }

    func getMode() async throws -> String {
        let result = try await call("nvim_get_mode", args: [])
        if case let .map(dict) = result,
           let modeValue = dict[.string("mode")],
           case let .string(mode) = modeValue {
            return mode
        }
        return "n"
    }

    func getCurrentBuffer() async throws -> Int {
        let result = try await call("nvim_get_current_buf", args: [])
        if case let .int(bufId) = result {
            return Int(bufId)
        }
        // Handle ext type for buffer
        if case let .extended(type, data) = result, type == 0 {
            if let id = data.first {
                return Int(id)
            }
        }
        return 0
    }

    func getBufferLines(buffer: Int, start: Int, end: Int) async throws -> [String] {
        let result = try await call("nvim_buf_get_lines", args: [
            .int(Int64(buffer)),
            .int(Int64(start)),
            .int(Int64(end)),
            .bool(false)
        ])

        if case let .array(lines) = result {
            return lines.compactMap { value -> String? in
                if case let .string(str) = value {
                    return str
                }
                return nil
            }
        }
        return []
    }

    func setBufferLines(buffer: Int, start: Int, end: Int, lines: [String]) async throws {
        let lineValues = lines.map { MessagePackValue.string($0) }
        _ = try await call("nvim_buf_set_lines", args: [
            .int(Int64(buffer)),
            .int(Int64(start)),
            .int(Int64(end)),
            .bool(false),
            .array(lineValues)
        ])
    }

    func openFile(_ path: String) async throws {
        try await command("edit \(path)")
    }

    func saveFile() async throws {
        try await command("write")
    }

    // MARK: - Handlers

    func setNotificationHandler(_ handler: @escaping (String, [MessagePackValue]) -> Void) {
        self.notificationHandler = handler
    }

    func setRedrawHandler(_ handler: @escaping ([[MessagePackValue]]) -> Void) {
        self.redrawHandler = handler
    }

    // MARK: - Low-level RPC

    private func call(_ method: String, args: [MessagePackValue]) async throws -> MessagePackValue {
        let id = nextMsgId()

        // [type, msgid, method, args]
        let request: MessagePackValue = .array([
            .int(0), // request type
            .int(Int64(id)),
            .string(method),
            .array(args)
        ])

        let data = packValue(request)
        stdin?.write(data)

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[id] = continuation
        }
    }

    private func nextMsgId() -> UInt32 {
        msgId += 1
        return msgId
    }

    // MARK: - Read Loop

    private func readLoop() async {
        guard let stdout = stdout else { return }

        while process?.isRunning == true {
            let data = stdout.availableData
            if data.isEmpty {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                continue
            }

            readBuffer.append(data)

            // Try to parse messages - need at least 1 byte for msgpack
            while readBuffer.count > 0 {
                do {
                    let (message, consumed) = try unpackFirst(readBuffer)
                    readBuffer.removeFirst(consumed)
                    await handleMessage(message)
                } catch {
                    // Incomplete message, wait for more data
                    break
                }
            }
        }
    }

    private func handleMessage(_ msg: MessagePackValue) async {
        guard case let .array(arr) = msg, !arr.isEmpty else { return }
        guard case let .int(type) = arr[0] else { return }

        switch type {
        case 1: // Response
            guard arr.count >= 4,
                  case let .int(msgId) = arr[1] else { return }

            let id = UInt32(msgId)
            let error = arr[2]
            let result = arr[3]

            if let continuation = pendingRequests.removeValue(forKey: id) {
                if case .nil = error {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: NeovimError.rpcError(error.description))
                }
            }

        case 2: // Notification
            guard arr.count >= 3,
                  case let .string(method) = arr[1],
                  case let .array(params) = arr[2] else { return }

            if method == "redraw" {
                // params is array of [event_name, ...args]
                let events = params.compactMap { value -> [MessagePackValue]? in
                    if case let .array(arr) = value {
                        return arr
                    }
                    return nil
                }
                redrawHandler?(events)
            } else {
                notificationHandler?(method, params)
            }

        default:
            break
        }
    }
}

// MARK: - MessagePack Helpers

private func packValue(_ value: MessagePackValue) -> Data {
    return pack(value)
}

private func unpackFirst(_ data: Data) throws -> (MessagePackValue, Int) {
    let (value, remainder) = try unpack(data)
    let consumed = data.count - remainder.count
    return (value, consumed)
}

// MARK: - Errors

enum NeovimError: Error {
    case nvimNotFound
    case rpcError(String)
    case invalidResponse
}
