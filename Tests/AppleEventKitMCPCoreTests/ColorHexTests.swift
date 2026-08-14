import Testing
import Foundation
import CoreGraphics
@testable import AppleEventKitMCPCore

struct ColorHexTests {
    @Test func hexToColor() {
        let red = ColorHex.colorFromHex("#FF0000")
        #expect(red != nil)

        let shortGreen = ColorHex.colorFromHex("#0F0")
        #expect(shortGreen != nil)

        let invalid = ColorHex.colorFromHex("XYZ123")
        #expect(invalid == nil)
    }

    @Test func colorToHex() {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        let blue = CGColor(colorSpace: srgb, components: [0.0, 0.0, 1.0, 1.0])
        let hex = ColorHex.hexString(from: blue)
        #expect(hex == "#0000FF")

        // Grayscale conversion
        let graySpace = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
        let gray = CGColor(colorSpace: graySpace, components: [0.5, 1.0])
        let grayHex = ColorHex.hexString(from: gray)
        #expect(grayHex != nil)
    }
}
