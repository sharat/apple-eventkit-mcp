import Foundation

public enum Priority: Sendable {
    public static func parse(_ value: AnyCodable) throws -> Int {
        if let intVal = value.intValue {
            if intVal >= 0 && intVal <= 9 {
                return intVal
            }
            throw ReminderError.invalidArgument("Priority integer must be between 0 (none) and 9 (low). Received: \(intVal)")
        }

        if let strVal = value.stringValue?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
            switch strVal {
            case "high", "h", "1", "urgent", "critical", "important", "p1":
                return 1
            case "medium", "med", "m", "5", "normal", "moderate", "p2":
                return 5
            case "low", "l", "9", "minor", "p3":
                return 9
            case "none", "0", "clear", "default", "standard", "p0", "":
                return 0
            default:
                if let num = Int(strVal) {
                    if num >= 0 && num <= 9 {
                        return num
                    }
                    throw ReminderError.invalidArgument("Priority integer must be between 0 and 9. Received: \(num)")
                }
                throw ReminderError.invalidArgument("Unknown priority level '\(strVal)'. Supported: high/p1/1, medium/p2/5, low/p3/9, none/0.")
            }
        }

        return 0
    }

    public static func name(for priority: Int) -> String {
        switch priority {
        case 1...4:
            return "high"
        case 5:
            return "medium"
        case 6...9:
            return "low"
        default:
            return "none"
        }
    }

    public static func rank(for priority: Int) -> Int {
        switch priority {
        case 1...4:
            return 1 // High
        case 5:
            return 2 // Medium
        case 6...9:
            return 3 // Low
        default:
            return 4 // None (0)
        }
    }
}
