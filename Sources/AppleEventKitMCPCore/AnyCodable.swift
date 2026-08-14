import Foundation

public enum AnyCodable: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])

    public init(_ value: Any?) {
        guard let value = value else {
            self = .null
            return
        }

        switch value {
        case let b as Bool:
            self = .bool(b)
        case let i as Int:
            self = .int(i)
        case let d as Double:
            self = .double(d)
        case let s as String:
            self = .string(s)
        case let a as [Any]:
            self = .array(a.map { AnyCodable($0) })
        case let d as [String: Any]:
            self = .dictionary(d.mapValues { AnyCodable($0) })
        case let ac as AnyCodable:
            self = ac
        default:
            // Non-JSON primitives evaluate to null rather than corrupting wire formats
            self = .null
        }
    }

    public static func from<T: Encodable>(_ encodable: T) throws -> AnyCodable {
        let data = try JSONEncoder().encode(encodable)
        return try JSONDecoder().decode(AnyCodable.self, from: data)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([AnyCodable].self) {
            self = .array(a)
        } else if let d = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(d)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let b):
            try container.encode(b)
        case .int(let i):
            try container.encode(i)
        case .double(let d):
            try container.encode(d)
        case .string(let s):
            try container.encode(s)
        case .array(let a):
            try container.encode(a)
        case .dictionary(let d):
            try container.encode(d)
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return String(b)
        default: return nil
        }
    }

    public var boolValue: Bool? {
        switch self {
        case .bool(let b): return b
        case .string(let s):
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "1", "yes", "y"].contains(trimmed) { return true }
            if ["false", "0", "no", "n"].contains(trimmed) { return false }
            return nil
        case .int(let i): return i != 0
        default: return nil
        }
    }

    public var intValue: Int? {
        switch self {
        case .int(let i):
            return i
        case .double(let d):
            if d.isNaN || d.isInfinite || d >= Double(Int.max) || d < Double(Int.min) {
                return nil
            }
            return Int(d)
        case .string(let s):
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if let i = Int(trimmed) {
                return i
            }
            if let d = Double(trimmed), !d.isNaN && !d.isInfinite && d < Double(Int.max) && d >= Double(Int.min) {
                return Int(d)
            }
            return nil
        default:
            return nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .double(let d):
            return d
        case .int(let i):
            return Double(i)
        case .string(let s):
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(trimmed)
        default:
            return nil
        }
    }

    public var arrayValue: [AnyCodable]? {
        if case .array(let a) = self { return a }
        return nil
    }

    public var dictionaryValue: [String: AnyCodable]? {
        if case .dictionary(let d) = self { return d }
        return nil
    }

    public var rawValue: Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let b):
            return b
        case .int(let i):
            return i
        case .double(let d):
            return d
        case .string(let s):
            return s
        case .array(let a):
            return a.map { $0.rawValue }
        case .dictionary(let d):
            return d.mapValues { $0.rawValue }
        }
    }
}
