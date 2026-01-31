//
//  LayoutBreakpoint.swift
//  LanMount
//
//  Layout breakpoint enumeration and calculation logic for responsive design
//  Requirements: 7.2 - Support compact, regular, and expanded layout breakpoints
//  Requirements: 7.3 - Automatically adjust layout based on window width
//

import Foundation
import SwiftUI

// MARK: - LayoutBreakpoint

/// Enumerates the different layout breakpoints for responsive design
///
/// Layout breakpoints determine how the UI should adapt to different screen sizes
/// and window widths. The breakpoints are:
/// - `compact`: For narrow windows (typically < 600pt)
/// - `regular`: For medium windows (typically 600-1000pt)
/// - `expanded`: For wide windows (typically > 1000pt)
///
/// Example usage:
/// ```swift
/// let breakpoint = LayoutBreakpoint.from(width: geometryProxy.size.width)
/// switch breakpoint {
/// case .compact:
///     // Show single column layout
/// case .regular:
///     // Show two column layout
/// case .expanded:
///     // Show three or more column layout
/// }
/// ```
enum LayoutBreakpoint: CaseIterable, Equatable {
    /// Compact layout for narrow windows
    case compact

    /// Regular layout for medium windows
    case regular

    /// Expanded layout for wide windows
    case expanded

    /// Returns the minimum width threshold for each breakpoint
    /// Requirements: 7.2, 7.3 - Breakpoint thresholds as per design spec
    var minWidth: CGFloat {
        switch self {
        case .compact:
            return 0
        case .regular:
            return 600
        case .expanded:
            return 800
        }
    }

    /// Returns the maximum width threshold for each breakpoint
    /// Requirements: 7.2, 7.3 - Breakpoint thresholds as per design spec
    var maxWidth: CGFloat {
        switch self {
        case .compact:
            return 599
        case .regular:
            return 799
        case .expanded:
            return .infinity
        }
    }

    /// Returns the number of columns appropriate for this breakpoint
    var columnCount: Int {
        switch self {
        case .compact:
            return 1
        case .regular:
            return 2
        case .expanded:
            return 3
        }
    }

    /// Returns a human-readable description of the breakpoint
    var description: String {
        switch self {
        case .compact:
            return NSLocalizedString("Compact", comment: "Compact layout breakpoint")
        case .regular:
            return NSLocalizedString("Regular", comment: "Regular layout breakpoint")
        case .expanded:
            return NSLocalizedString("Expanded", comment: "Expanded layout breakpoint")
        }
    }
}

// MARK: - LayoutBreakpoint + Calculation

extension LayoutBreakpoint {
    /// Determines the appropriate layout breakpoint based on window width
    ///
    /// Requirements: 7.2, 7.3 - Breakpoint calculation as per design spec:
    /// - compact: < 600px
    /// - regular: 600-800px  
    /// - expanded: > 800px
    ///
    /// - Parameter width: The current window or container width
    /// - Returns: The appropriate LayoutBreakpoint for the given width
    static func from(width: CGFloat) -> LayoutBreakpoint {
        switch width {
        case ..<600:
            return .compact
        case 600..<800:
            return .regular
        default:
            return .expanded
        }
    }

    /// Determines the appropriate layout breakpoint based on screen size class
    ///
    /// - Parameter horizontalSizeClass: The horizontal size class from SwiftUI
    /// - Returns: The appropriate LayoutBreakpoint for the given size class
    static func from(horizontalSizeClass: UserInterfaceSizeClass?) -> LayoutBreakpoint {
        switch horizontalSizeClass {
        case .compact:
            return .compact
        case .regular, .none:
            return .regular
        @unknown default:
            return .regular
        }
    }
}

// MARK: - ColorContrastCalculator

/// Utility for calculating color contrast ratios according to WCAG 2.1 guidelines
///
/// This calculator helps ensure that text and background colors meet accessibility
/// standards for readability. WCAG 2.1 requires:
/// - AA compliance: Contrast ratio of at least 4.5:1 for normal text
/// - AAA compliance: Contrast ratio of at least 7:1 for normal text
/// - Large text (18pt+ or 14pt+ bold): AA requires 3:1, AAA requires 4.5:1
///
/// Example usage:
/// ```swift
/// let contrastRatio = ColorContrastCalculator.contrastRatio(
///     foreground: .black,
///     background: .white
/// )
/// let meetsAA = ColorContrastCalculator.meetsWCAG21AA(
///     foreground: .black,
///     background: .white,
///     isLargeText: false
/// )
/// ```
enum ColorContrastCalculator {
    /// Calculates the relative luminance of a color
    ///
    /// Relative luminance is a measure of the brightness of a color relative to
    /// white, normalized to a scale from 0 (black) to 1 (white).
    ///
    /// - Parameter color: The color to calculate luminance for
    /// - Returns: The relative luminance value (0.0 to 1.0)
    static func relativeLuminance(_ color: Color) -> Double {
        // Convert Color to RGB components
        let components = color.cgColor?.components ?? [0, 0, 0, 1]
        let r = Double(components[0])
        let g = Double(components[1])
        let b = Double(components[2])

        // Apply sRGB gamma correction
        let rsRGB = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let gsRGB = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let bsRGB = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)

        // Calculate relative luminance using standard coefficients
        return 0.2126 * rsRGB + 0.7152 * gsRGB + 0.0722 * bsRGB
    }

    /// Calculates the contrast ratio between two colors
    ///
    /// The contrast ratio is calculated according to WCAG 2.1 formula:
    /// (L1 + 0.05) / (L2 + 0.05) where L1 is the relative luminance of the lighter color
    /// and L2 is the relative luminance of the darker color.
    ///
    /// - Parameters:
    ///   - foreground: The foreground/text color
    ///   - background: The background color
    /// - Returns: The contrast ratio (1.0 to 21.0)
    static func contrastRatio(foreground: Color, background: Color) -> Double {
        let luminance1 = relativeLuminance(foreground)
        let luminance2 = relativeLuminance(background)

        let lighter = max(luminance1, luminance2)
        let darker = min(luminance1, luminance2)

        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Checks if two colors meet WCAG 2.1 AA contrast requirements
    ///
    /// - Parameters:
    ///   - foreground: The foreground/text color
    ///   - background: The background color
    ///   - isLargeText: Whether the text is large (18pt+ or 14pt+ bold)
    /// - Returns: True if the colors meet AA requirements, false otherwise
    static func meetsWCAG21AA(foreground: Color, background: Color, isLargeText: Bool = false) -> Bool {
        let ratio = contrastRatio(foreground: foreground, background: background)
        let requiredRatio = isLargeText ? 3.0 : 4.5
        return ratio >= requiredRatio
    }

    /// Checks if two colors meet WCAG 2.1 AAA contrast requirements
    ///
    /// - Parameters:
    ///   - foreground: The foreground/text color
    ///   - background: The background color
    ///   - isLargeText: Whether the text is large (18pt+ or 14pt+ bold)
    /// - Returns: True if the colors meet AAA requirements, false otherwise
    static func meetsWCAG21AAA(foreground: Color, background: Color, isLargeText: Bool = false) -> Bool {
        let ratio = contrastRatio(foreground: foreground, background: background)
        let requiredRatio = isLargeText ? 4.5 : 7.0
        return ratio >= requiredRatio
    }

    /// Gets the WCAG 2.1 compliance level for two colors
    ///
    /// - Parameters:
    ///   - foreground: The foreground/text color
    ///   - background: The background color
    ///   - isLargeText: Whether the text is large (18pt+ or 14pt+ bold)
    /// - Returns: The compliance level (.none, .aa, or .aaa)
    static func complianceLevel(foreground: Color, background: Color, isLargeText: Bool = false) -> WCAGComplianceLevel {
        if meetsWCAG21AAA(foreground: foreground, background: background, isLargeText: isLargeText) {
            return .aaa
        } else if meetsWCAG21AA(foreground: foreground, background: background, isLargeText: isLargeText) {
            return .aa
        } else {
            return .none
        }
    }
}

// MARK: - WCAGComplianceLevel

/// Enumerates WCAG 2.1 contrast compliance levels
enum WCAGComplianceLevel: String, CaseIterable {
    /// No compliance (contrast ratio below AA requirements)
    case none = "None"

    /// AA compliance (meets minimum requirements)
    case aa = "AA"

    /// AAA compliance (meets enhanced requirements)
    case aaa = "AAA"

    /// Returns a localized description of the compliance level
    var description: String {
        switch self {
        case .none:
            return NSLocalizedString("No Compliance", comment: "WCAG compliance level - none")
        case .aa:
            return NSLocalizedString("AA Compliance", comment: "WCAG compliance level - AA")
        case .aaa:
            return NSLocalizedString("AAA Compliance", comment: "WCAG compliance level - AAA")
        }
    }

    /// Returns the minimum contrast ratio required for this compliance level
    /// - Parameter isLargeText: Whether the text is large (18pt+ or 14pt+ bold)
    /// - Returns: The minimum required contrast ratio
    func minimumContrastRatio(isLargeText: Bool = false) -> Double {
        switch self {
        case .none:
            return 0.0
        case .aa:
            return isLargeText ? 3.0 : 4.5
        case .aaa:
            return isLargeText ? 4.5 : 7.0
        }
    }
}