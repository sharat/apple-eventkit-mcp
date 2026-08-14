import Foundation

public final class MCPServer: Sendable {
    private let eventKitManager: EventKitManager
    private let tools: ReminderTools
    private let writer: @Sendable (Data) -> Void

    public init(
        eventKitManager: EventKitManager = EventKitManager(),
        writer: @Sendable @escaping (Data) -> Void = { data in FileHandle.standardOutput.write(data) }
    ) {
        self.eventKitManager = eventKitManager
        self.tools = ReminderTools(eventKitManager: eventKitManager)
        self.writer = writer
    }

    public func run() async {
        Logger.info("Starting Apple EventKit MCP Server...")

        let stdin = FileHandle.standardInput
        var buffer = Data()
        let maxMessageSize = 10 * 1024 * 1024 // 10 MB limit

        while true {
            let chunk = stdin.availableData
            if chunk.isEmpty {
                // EOF reached
                break
            }

            buffer.append(chunk)
            if buffer.count > maxMessageSize {
                Logger.error("Received payload exceeded maximum allowed size of 10MB. Discarding buffer.")
                sendError(id: nil, error: JSONRPCError.invalidRequest(message: "Message size exceeds 10MB limit."))
                buffer.removeAll()
                continue
            }

            while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = buffer.subdata(in: 0..<newlineIndex)
                buffer.removeSubrange(0...newlineIndex)

                guard !lineData.isEmpty else { continue }

                if let lineStr = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !lineStr.isEmpty {
                    await handleLine(lineStr)
                }
            }
        }

        Logger.info("Standard input closed. Shutting down Apple EventKit MCP Server.")
    }

    public func handleLine(_ line: String) async {
        Logger.debug("Received: \(line)")
        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        guard let data = line.data(using: .utf8) else {
            sendError(id: nil, error: JSONRPCError.parseError(message: "Invalid UTF-8 string"), isParseError: true)
            return
        }

        guard let request = try? JSONDecoder().decode(JSONRPCRequest.self, from: data) else {
            Logger.error("Failed to parse JSON-RPC request payload")
            sendError(id: nil, error: JSONRPCError.parseError(message: "Invalid JSON-RPC request"), isParseError: true)
            return
        }

        await handleRequest(request)
    }

    public func handleRequest(_ request: JSONRPCRequest) async {
        guard request.jsonrpc == "2.0" else {
            sendError(
                id: request.id,
                error: JSONRPCError.invalidRequest(message: "Invalid jsonrpc version '\(request.jsonrpc)'. Expected '2.0'.")
            )
            return
        }

        switch request.method {
        case "initialize":
            let supportedVersions: Set<String> = [ServerConfig.protocolVersion, "2024-11-05", "2025-06-18"]
            var negotiatedVersion = ServerConfig.protocolVersion
            if let params = request.params,
               let dict = params.dictionaryValue,
               let clientProto = dict["protocolVersion"]?.stringValue,
               supportedVersions.contains(clientProto) {
                negotiatedVersion = clientProto
            }

            let result = InitializeResult(
                protocolVersion: negotiatedVersion,
                capabilities: ServerCapabilities(tools: ToolCapability(listChanged: false)),
                serverInfo: ServerInfo(name: ServerConfig.name, version: ServerConfig.version)
            )
            sendResult(id: request.id, result: result)

        case "initialized", "notifications/initialized":
            // Initialized notification, no response required
            Logger.info("Client initialized successfully.")

        case "ping":
            sendResult(id: request.id, result: [String: String]())

        case "tools/list":
            let toolDefs = tools.definitions
            let result = ["tools": toolDefs]
            sendResult(id: request.id, result: result)

        case "tools/call":
            guard let params = request.params, let dict = params.dictionaryValue else {
                sendError(id: request.id, error: JSONRPCError.invalidParams(message: "Missing parameters object for tools/call"))
                return
            }

            guard let name = dict["name"]?.stringValue else {
                sendError(id: request.id, error: JSONRPCError.invalidParams(message: "Missing 'name' in tools/call parameters"))
                return
            }

            let arguments = dict["arguments"]?.dictionaryValue ?? [:]
            let callResult = await tools.callTool(name: name, arguments: arguments)

            sendResult(id: request.id, result: callResult)

        case "resources/list":
            sendResult(id: request.id, result: ["resources": [String]()])

        case "prompts/list":
            sendResult(id: request.id, result: ["prompts": [String]()])

        default:
            if request.id != nil {
                sendError(id: request.id, error: JSONRPCError.methodNotFound(method: request.method))
            } else {
                Logger.debug("Ignored unhandled notification method: \(request.method)")
            }
        }
    }

    private func sendResult<T: Encodable>(id: AnyCodable?, result: T) {
        guard let id = id else { return } // Notifications do not receive responses
        do {
            let data = try JSONEncoder().encode(result)
            let resultCodable = try JSONDecoder().decode(AnyCodable.self, from: data)
            let response = JSONRPCResponse(id: id, result: resultCodable)
            sendResponse(response)
        } catch {
            Logger.error("Failed to encode result response: \(error)")
            sendError(id: id, error: JSONRPCError.internalError(message: "Failed to encode response: \(error.localizedDescription)"))
        }
    }

    private func sendError(id: AnyCodable?, error: JSONRPCError, isParseError: Bool = false) {
        // Per JSON-RPC 2.0 Section 4.1, notifications (id == nil) must not receive error responses
        // unless it's a parse error where the server could not determine if the request had an id.
        guard id != nil || isParseError else {
            Logger.debug("Suppressed error response for notification: \(error.message)")
            return
        }
        let response = JSONRPCResponse(id: id, error: error)
        sendResponse(response)
    }

    private func sendResponse(_ response: JSONRPCResponse) {
        do {
            let data = try JSONEncoder().encode(response)
            writer(data)
            if let newline = "\n".data(using: .utf8) {
                writer(newline)
            }
        } catch {
            Logger.error("Failed to encode JSON-RPC response: \(error)")
        }
    }
}
