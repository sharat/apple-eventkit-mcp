import Foundation
import AppleEventKitMCPCore

// Check for debug flag in arguments
if CommandLine.arguments.contains("--debug") || CommandLine.arguments.contains("-d") {
    Logger.isDebugEnabled = true
}

let server = MCPServer()
await server.run()
