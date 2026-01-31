//
//  ColorContrast.swift
//  LanMount
//
//  WCAG 2.1 color contrast calculation utilities
//  Requirements: 8.5 - Ensure text and background contrast meets WCAG 2.1 AA standard
//

import SwiftUI
import AppKit

// MARK: - WCAG Conformance Level

/// WCAG 2.1 conformance levels for contrast requirements
enum WCAGConformanceLevel {
    /// AA level for normal text (minimum 4.5:1)
    case aaNormalText
    /// AA level for large text (minimum 3:1)
    case aaLargeText
    /// AAA level for normal text (minimum 7:1)
    case aaaNormalText
    /// AAA level for large text (minimum 4.5:1)
    case aaaLargeText
    
    /// The minimum contrast ratio required for this conformance level
    var minimumRatio: Double {
        switch self {
        case .aaNormalText:
            return 4.5
        case .aaLargeText:
            return 3.0
        case .aaaNormalText:
            return 7.0
        case .aaaLargeText:
            return 4.5
        }
    }
}

// MARK: - ContrastResult

/// Result of a contrast ratio check
struct ContrastResult: Equatable {
    /// The calculated contrast ratio
    let ratio: Double
    /// Whether the contrast meets AA standard for normal text (4.5:1)
    let meetsAANormalText: Bool
    /// Whether the contrast meets AA standard for large text (3:1)
    let meetsAALargeText: Bool
    /// Whether the contrast meets AAA standard for normal text (7:1)
    let meetsAAANormalText: Bool
    /// Whether the contrast meets AAA standard for large text (4.5:1)
    let meetsAAALargeText: Bool
    
    init(ratio: Double) {
        self.ratio = ratio
        self.meetsAANormalText = ratio >= WCAGConformanceLevel.aaNormalText.minimumRatio
        self.meetsAALargeText = ratio >= WCAGConformanceLevel.aaLargeText.minimumRatio
        self.meetsAAANormalText = ratio >= WCAGConformanceLevel.aaaNormalText.minimumRatio
        self.meetsAAALargeText = ratio >= WCAGConformanceLevel.aaaLargeText.minimumRatio
    }
}

// MARK: - ColorContrast

/// Utility for calculating WCAG 2.1 color contrast ratios
///
/// This utility implements the WCAG 2.1 contrast ratio calculation algorithm:
/// 1. Convert sRGB color values to linear RGB
/// 2. Calculate relative luminance using the formula:
///    L = 0.2126 * R + 0.7152 * G + 0.0722 * B
/// 3. Calculate contrast ratio: (L1 + 0.05) / (L2 + 0.05)
///    where L1 is the lighter color's luminance
///
/// Requirements: 8.5 - Ensure all text and background color contrast meets WCAG 2.1 AA standard
struct ColorContrast {
    
    // MARK: - Relative Luminance Calculation
    
    /// Converts an sRGB color component to linear RGB
    ///
    /// Per WCAG 2.1 specification:
    /// - If value <= 0.03928: linear = value / 12.92
    /// - Else: linear = ((value + 0.055) / 1.055) ^ 2.4
    ///
    /// - Parameter srgbComponent: The sRGB color component (0.0-1.0)
    /// - Returns: The linear RGB value
    static func srgbToLinear(_ srgbComponent: Double) -> Double {
        // Clamp input to valid range
        let clamped = min(max(srgbComponent, 0.0), 1.0)
        
        if clamped <= 0.03928 {
            return clamped / 12.92
        } else {
            return pow((clamped + 0.055) / 1.055, 2.4)
        }
    }
    
    /// Calculates the relative luminance of a color
    ///
    /// Per WCAG 2.1 specification:
    /// L = 0.2126 * R + 0.7152 * G + 0.0722 * B
    /// where R, G, B are linear RGB values
    ///
    /// - Parameters:
    ///   - red: Red component (0.0-1.0 in sRGB)
    ///   - green: Green component (0.0-1.0 in sRGB)
    ///   - blue: Blue component (0.0-1.0 in sRGB)
    /// - Returns: The relative luminance (0.0-1.0)
    static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        let linearR = srgbToLinear(red)
        let linearG = srgbToLinear(green)
        let linearB = srgbToLinear(blue)
        
        return 0.2126 * linearR + 0.7152 * linearG + 0.0722 * linearB
    }
    
    /// Calculates the relative luminance of an NSColor
    ///
    /// - Parameter color: The NSColor to calculate luminance for
    /// - Returns: The relative luminance (0.0-1.0), or nil if color cannot be converted
    static func relativeLuminance(of color: NSColor) -> Double? {
        // Convert to sRGB color space
        guard let srgbColor = color.usingColorSpace(.sRGB) else {
            return nil
        }
        
        return relativeLuminance(
            red: Double(srgbColor.redComponent),
            green: Double(srgbColor.greenComponent),
            blue: Double(srgbColor.blueComponent)
        )
    }
    
    // MARK: - Contrast Ratio Calculation
    
    /// Calculates the contrast ratio between two luminance values
    ///
    /// Per WCAG 2.1 specification:
    /// Contrast ratio = (L1 + 0.05) / (L2 + 0.05)
    /// where L1 is the lighter luminance and L2 is the darker luminance
    ///
    /// - Parameters:
    ///   - luminance1: First luminance value (0.0-1.0)
    ///   - luminance2: Second luminance value (0.0-1.0)
    /// - Returns: The contrast ratio (1.0-21.0)
    static func contrastRatio(luminance1: Double, luminance2: Double) -> Double {
        let lighter = max(luminance1, luminance2)
        let darker = min(luminance1, luminance2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    /// Calculates the contrast ratio between two RGB colors
    ///
    /// - Parameters:
    ///   - r1, g1, b1: First color RGB components (0.0-1.0 in sRGB)
    ///   - r2, g2, b2: Second color RGB components (0.0-1.0 in sRGB)
    /// - Returns: The contrast ratio (1.0-21.0)
    static func contrastRatio(
        r1: Double, g1: Double, b1: Double,
        r2: Double, g2: Double, b2: Double
    ) -> Double {
        let lum1 = relativeLuminance(red: r1, green: g1, blue: b1)
        let lum2 = relativeLuminance(red: r2, green: g2, blue: b2)
        return contrastRatio(luminance1: lum1, luminance2: lum2)
    }
    
    /// Calculates the contrast ratio between two NSColors
    ///
    /// - Parameters:
    ///   - color1: First color
    ///   - color2: Second color
    /// - Returns: The contrast ratio (1.0-21.0), or nil if colors cannot be converted
    static func contrastRatio(between color1: NSColor, and color2: NSColor) -> Double? {
        guard let lum1 = relativeLuminance(of: color1),
              let lum2 = relativeLuminance(of: color2) else {
            return nil
        }
        return contrastRatio(luminance1: lum1, luminance2: lum2)
    }
    
    /// Calculates the contrast ratio between two SwiftUI Colors
    ///
    /// - Parameters:
    ///   - color1: First SwiftUI Color
    ///   - color2: Second SwiftUI Color
    /// - Returns: The contrast ratio (1.0-21.0), or nil if colors cannot be converted
    static func contrastRatio(between color1: Color, and color2: Color) -> Double? {
        let nsColor1 = NSColor(color1)
        let nsColor2 = NSColor(color2)
        return contrastRatio(between: nsColor1, and: nsColor2)
    }
    
    // MARK: - WCAG Compliance Checks
    
    /// Checks if the contrast ratio meets a specific WCAG conformance level
    ///
    /// - Parameters:
    ///   - ratio: The contrast ratio to check
    ///   - level: The WCAG conformance level to check against
    /// - Returns: true if the ratio meets or exceeds the required minimum
    static func meetsConformance(ratio: Double, level: WCAGConformanceLevel) -> Bool {
        return ratio >= level.minimumRatio
    }
    
    /// Checks if two colors meet WCAG AA standard for normal text (4.5:1)
    ///
    /// - Parameters:
    ///   - color1: First color
    ///   - color2: Second color
    /// - Returns: true if contrast meets AA standard for normal text
    static func meetsAANormalText(color1: Color, color2: Color) -> Bool {
        guard let ratio = contrastRatio(between: color1, and: color2) else {
            return false
        }
        return meetsConformance(ratio: ratio, level: .aaNormalText)
    }
    
    /// Checks if two colors meet WCAG AA standard for large text (3:1)
    ///
    /// Large text is defined as 18pt or 14pt bold
    ///
    /// - Parameters:
    ///   - color1: First color
    ///   - color2: Second color
    /// - Returns: true if contrast meets AA standard for large text
    static func meetsAALargeText(color1: Color, color2: Color) -> Bool {
        guard let ratio = contrastRatio(between: color1, and: color2) else {
            return false
        }
        return meetsConformance(ratio: ratio, level: .aaLargeText)
    }
    
    /// Performs a comprehensive contrast check between two colors
    ///
    /// - Parameters:
    ///   - foreground: The foreground (text) color
    ///   - background: The background color
    /// - Returns: A ContrastResult with the ratio and all conformance checks, or nil if colors cannot be converted
    static func checkContrast(foreground: Color, background: Color) -> ContrastResult? {
        guard let ratio = contrastRatio(between: foreground, and: background) else {
            return nil
        }
        return ContrastResult(ratio: ratio)
    }
    
    /// Performs a comprehensive contrast check between two NSColors
    ///
    /// - Parameters:
    ///   - foreground: The foreground (text) color
    ///   - background: The background color
    /// - Returns: A ContrastResult with the ratio and all conformance checks, or nil if colors cannot be converted
    static func checkContrast(foreground: NSColor, background: NSColor) -> ContrastResult? {
        guard let ratio = contrastRatio(between: foreground, and: background) else {
            return nil
        }
        return ContrastResult(ratio: ratio)
    }
}

// MARK: - Color Extension for Convenience

extension Color {
    /// Calculates the contrast ratio between this color and another
    ///
    /// - Parameter other: The other color to compare against
    /// - Returns: The contrast ratio (1.0-21.0), or nil if colors cannot be converted
    func contrastRatio(with other: Color) -> Double? {
        return ColorContrast.contrastRatio(between: self, and: other)
    }
    
    /// Checks if this color has sufficient contrast with another for normal text (AA standard)
    ///
    /// - Parameter other: The other color to compare against
    /// - Returns: true if contrast meets WCAG AA standard for normal text (4.5:1)
    func meetsAAContrastWith(_ other: Color) -> Bool {
        return ColorContrast.meetsAANormalText(color1: self, color2: other)
    }
}
