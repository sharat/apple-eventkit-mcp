import Testing
import Foundation
@testable import AppleEventKitMCPCore

final class WrittenDataCapture: @unchecked Sendable {
    var data = Data()
    private let lock = NSLock()

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(chunk)
    }

    func string() -> String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func response() throws -> JSONRPCResponse {
        let raw = string()
        guard let line = raw.split(separator: "\n").first, let data = String(line).data(using: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "No response data"))
        }
        return try JSONDecoder().decode(JSONRPCResponse.self, from: data)
    }
}

struct MCPServerProtocolTests {
    @Test func nullIdInParseError() async throws {
        let capture = WrittenDataCapture()
        let server = MCPServer(
            writer: { data in
                capture.append(data)
            }
        )

        await server.handleLine("invalid json payload")

        let jsonStr = capture.string()
        #expect(jsonStr.contains("\"id\":null") || jsonStr.contains("\"id\": null"))
        #expect(jsonStr.contains("\"code\":-32700") || jsonStr.contains("\"code\": -32700"))

        let response = try capture.response()
        #expect(response.id == nil)
        #expect(response.error?.code == -32700)
    }

    @Test func protocolNegotiationReturnsStructuredObject() async throws {
        let capture = WrittenDataCapture()
        let server = MCPServer(
            writer: { data in
                capture.append(data)
            }
        )

        let initPayload = """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"serverInfo":{"name":"test"}}}
        """
        await server.handleLine(initPayload)

        let response = try capture.response()
        #expect(response.id?.intValue == 1)
        #expect(response.error == nil)

        // Result MUST be a structured JSON dictionary, not a stringified Swift struct
        guard case .dictionary(let resultDict)? = response.result else {
            Issue.record("Expected response.result to be a dictionary object, but received \(String(describing: response.result))")
            return
        }

        #expect(resultDict["protocolVersion"]?.stringValue == "2025-06-18")
        #expect(resultDict["serverInfo"]?.dictionaryValue?["name"]?.stringValue == "apple-eventkit-mcp")
        #expect(resultDict["serverInfo"]?.dictionaryValue?["version"]?.stringValue == "1.0.0")
        #expect(resultDict["capabilities"]?.dictionaryValue?["tools"]?.dictionaryValue?["listChanged"]?.boolValue == false)
    }

    @Test func toolsListReturnsProperStructuredSchemas() async throws {
        let capture = WrittenDataCapture()
        let server = MCPServer(
            writer: { data in
                capture.append(data)
            }
        )

        let listPayload = "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}"
        await server.handleLine(listPayload)

        let response = try capture.response()
        #expect(response.id?.intValue == 2)
        #expect(response.error == nil)

        // Result MUST be a structured JSON dictionary
        guard case .dictionary(let resultDict)? = response.result else {
            Issue.record("Expected response.result to be a dictionary object, but received \(String(describing: response.result))")
            return
        }

        guard let toolsArray = resultDict["tools"]?.arrayValue else {
            Issue.record("Expected 'tools' to be an array of tool objects")
            return
        }

        #expect(toolsArray.count == 8)

        let expectedTools = [
            "list_reminder_lists",
            "create_reminder_list",
            "delete_reminder_list",
            "list_reminders",
            "create_reminder",
            "update_reminder",
            "complete_reminder",
            "delete_reminder"
        ]

        var foundNames = [String]()
        for toolCodable in toolsArray {
            guard let toolDict = toolCodable.dictionaryValue else {
                Issue.record("Tool definition is not a JSON object: \(toolCodable)")
                continue
            }

            guard let name = toolDict["name"]?.stringValue,
                  let desc = toolDict["description"]?.stringValue,
                  let inputSchema = toolDict["inputSchema"]?.dictionaryValue else {
                Issue.record("Tool definition missing name/desc/inputSchema dictionary: \(toolDict)")
                continue
            }

            foundNames.append(name)
            #expect(!desc.isEmpty)
            #expect(inputSchema["type"]?.stringValue == "object")
            #expect(inputSchema["properties"]?.dictionaryValue != nil)

            if name == "delete_reminder_list" || name == "delete_reminder" {
                #expect(desc.contains("DESTRUCTIVE") || desc.contains("DANGEROUS"))
            }
        }

        #expect(foundNames == expectedTools)
    }
}
