import Foundation

// MARK: - Server Configuration

public enum ServerConfig {
    public static let name = "apple-eventkit-mcp"
    public static let version = "1.0.0"
    public static let protocolVersion = "2024-11-05"
}

// MARK: - JSON-RPC 2.0 Types

public struct JSONRPCRequest: Codable, Sendable {
    public let jsonrpc: String
    public let id: AnyCodable?
    public let method: String
    public let params: AnyCodable?

    public init(jsonrpc: String = "2.0", id: AnyCodable? = nil, method: String, params: AnyCodable? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct JSONRPCResponse: Codable, Sendable {
    public let jsonrpc: String
    public let id: AnyCodable?
    public let result: AnyCodable?
    public let error: JSONRPCError?

    enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case result
        case error
    }

    public init(id: AnyCodable?, result: AnyCodable?) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = nil
    }

    public init(id: AnyCodable?, error: JSONRPCError) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = nil
        self.error = error
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        if let id = id {
            try container.encode(id, forKey: .id)
        } else {
            try container.encodeNil(forKey: .id)
        }
        if let result = result {
            try container.encode(result, forKey: .result)
        }
        if let error = error {
            try container.encode(error, forKey: .error)
        }
    }
}

public struct JSONRPCError: Codable, Sendable, Equatable {
    public let code: Int
    public let message: String
    public let data: AnyCodable?

    public init(code: Int, message: String, data: AnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    public static func parseError(message: String = "Parse error") -> JSONRPCError {
        JSONRPCError(code: -32700, message: message)
    }

    public static func invalidRequest(message: String = "Invalid Request") -> JSONRPCError {
        JSONRPCError(code: -32600, message: message)
    }

    public static func methodNotFound(method: String) -> JSONRPCError {
        JSONRPCError(code: -32601, message: "Method not found: \(method)")
    }

    public static func invalidParams(message: String) -> JSONRPCError {
        JSONRPCError(code: -32602, message: message)
    }

    public static func internalError(message: String) -> JSONRPCError {
        JSONRPCError(code: -32603, message: message)
    }

    public static func toolExecutionError(message: String) -> JSONRPCError {
        JSONRPCError(code: -32000, message: message)
    }
}

// MARK: - MCP Protocol Structures

public struct ServerInfo: Codable, Sendable {
    public let name: String
    public let version: String

    public init(name: String = ServerConfig.name, version: String = ServerConfig.version) {
        self.name = name
        self.version = version
    }
}

public struct ToolCapability: Codable, Sendable {
    public let listChanged: Bool

    public init(listChanged: Bool = false) {
        self.listChanged = listChanged
    }
}

public struct ServerCapabilities: Codable, Sendable {
    public let tools: ToolCapability

    public init(tools: ToolCapability = ToolCapability()) {
        self.tools = tools
    }
}

public struct InitializeResult: Codable, Sendable {
    public let protocolVersion: String
    public let capabilities: ServerCapabilities
    public let serverInfo: ServerInfo

    public init(protocolVersion: String = ServerConfig.protocolVersion, capabilities: ServerCapabilities = ServerCapabilities(), serverInfo: ServerInfo = ServerInfo()) {
        self.protocolVersion = protocolVersion
        self.capabilities = capabilities
        self.serverInfo = serverInfo
    }
}

public struct ToolDefinition: Codable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: AnyCodable

    public init(name: String, description: String, inputSchema: [String: Any]) {
        self.name = name
        self.description = description
        self.inputSchema = AnyCodable(inputSchema)
    }
}

public struct ToolContent: Codable, Sendable {
    public let type: String
    public let text: String

    public init(type: String = "text", text: String) {
        self.type = type
        self.text = text
    }
}

public struct CallToolResult: Codable, Sendable {
    public let content: [ToolContent]
    public let isError: Bool

    public init(text: String, isError: Bool = false) {
        self.content = [ToolContent(type: "text", text: text)]
        self.isError = isError
    }

    public init(content: [ToolContent], isError: Bool = false) {
        self.content = content
        self.isError = isError
    }
}

public struct ReminderListDTO: Codable, Sendable {
    public let id: String
    public let title: String
    public let color: String?
    public let isDefault: Bool
}

public struct ReminderDTO: Codable, Sendable {
    public let id: String
    public let title: String
    public let notes: String?
    public let isCompleted: Bool
    public let wasCompleted: Bool?
    public let completionDate: String?
    public let dueDate: String?
    public let priority: Int
    public let priorityLevel: String
    public let list: ReminderListDTO
    public let url: String?
    public let creationDate: String?
    public let lastModifiedDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case isCompleted = "is_completed"
        case wasCompleted = "was_completed"
        case completionDate = "completion_date"
        case dueDate = "due_date"
        case priority
        case priorityLevel = "priority_level"
        case list
        case url
        case creationDate = "creation_date"
        case lastModifiedDate = "last_modified_date"
    }
}

public struct RemindersQueryResult: Codable, Sendable {
    public let reminders: [ReminderDTO]
    public let totalCount: Int
    public let returnedCount: Int
    public let offset: Int
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case reminders
        case totalCount = "total_count"
        case returnedCount = "returned_count"
        case offset
        case hasMore = "has_more"
    }

    public init(reminders: [ReminderDTO], totalCount: Int, returnedCount: Int, offset: Int = 0, hasMore: Bool) {
        self.reminders = reminders
        self.totalCount = totalCount
        self.returnedCount = returnedCount
        self.offset = offset
        self.hasMore = hasMore
    }
}

public struct DeleteReminderResult: Codable, Sendable {
    public let id: String
    public let title: String
    public let listTitle: String
    public let message: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case listTitle = "list_title"
        case message
    }
}

public struct DeleteListResult: Codable, Sendable {
    public let id: String
    public let title: String
    public let deletedRemindersCount: Int
    public let message: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case deletedRemindersCount = "deleted_reminders_count"
        case message
    }
}
