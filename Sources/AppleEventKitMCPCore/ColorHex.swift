import Foundation
import CoreGraphics

public enum ColorHex: Sendable {
    public static func colorFromHex(_ hex: String) -> CGColor? {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }
        if cleanHex.count == 3 {
            cleanHex = cleanHex.map { "\($0)\($0)" }.joined()
        }
        guard cleanHex.count == 6, let intVal = UInt64(cleanHex, radix: 16) else {
            return nil
        }
        let r = CGFloat((intVal >> 16) & 0xFF) / 255.0
        let g = CGFloat((intVal >> 8) & 0xFF) / 255.0
        let b = CGFloat(intVal & 0xFF) / 255.0
        return CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    public static func hexString(from cgColor: CGColor?) -> String? {
        guard let color = cgColor else { return nil }
        guard let srgbColorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = color.converted(to: srgbColorSpace, intent: .defaultIntent, options: nil),
              let components = converted.components, components.count >= 3 else {
            return nil
        }
        let r = UInt8(max(0.0, min(1.0, components[0])) * 255.0)
        let g = UInt8(max(0.0, min(1.0, components[1])) * 255.0)
        let b = UInt8(max(0.0, min(1.0, components[2])) * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
