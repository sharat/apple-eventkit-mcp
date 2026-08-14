import Foundation

public enum Logger: Sendable {
    #if swift(>=5.10)
    nonisolated(unsafe) public static var isDebugEnabled: Bool = false
    #else
    public static var isDebugEnabled: Bool = false
    #endif

    public static func info(_ message: String) {
        log("[INFO] \(message)")
    }

    /// `@autoclosure` so the interpolated message — which at the call site in
    /// MCPServer is the entire request payload — is never built when debug is off.
    public static func debug(_ message: @autoclosure () -> String) {
        if isDebugEnabled {
            log("[DEBUG] \(message())")
        }
    }

    public static func error(_ message: String) {
        log("[ERROR] \(message)")
    }

    private static let timestampFormatter = ISO8601DateFormatter()

    private static func log(_ message: String) {
        let timestamp = timestampFormatter.string(from: Date())
        let formatted = "[\(timestamp)] [apple-eventkit-mcp] \(message)\n"
        if let data = formatted.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
}
