//
//  GlassTheme.swift
//  LanMount
//
//  Glassmorphism theme configuration for the UI enhancement
//  Requirements: 1.1, 1.3
//

import SwiftUI

// MARK: - GlassShadow

/// Shadow configuration for glass effect
/// Used to create depth and dimension in glassmorphism design
struct GlassShadow: Equatable {
    /// Shadow color
    let color: Color
    /// Shadow blur radius
    let radius: CGFloat
    /// Horizontal shadow offset
    let x: CGFloat
    /// Vertical shadow offset
    let y: CGFloat
    
    /// Creates a new shadow configuration
    /// - Parameters:
    ///   - color: Shadow color
    ///   - radius: Shadow blur radius
    ///   - x: Horizontal offset
    ///   - y: Vertical offset
    init(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
    
    /// Default shadow for light mode
    static let lightDefault = GlassShadow(
        color: Color.black.opacity(0.1),
        radius: 10,
        x: 0,
        y: 5
    )
    
    /// Default shadow for dark mode
    static let darkDefault = GlassShadow(
        color: Color.black.opacity(0.3),
        radius: 10,
        x: 0,
        y: 5
    )
}

// MARK: - GlassTheme

/// Glassmorphism theme configuration
/// Provides unified visual styling for glass effect components
/// 
/// The theme includes:
/// - Background transparency settings
/// - Blur effect configuration
/// - Corner radius for rounded edges
/// - Border styling
/// - Shadow configuration
///
/// Requirements: 1.1 - Provides unified glassmorphism visual style
/// Requirements: 1.3 - Supports light and dark mode color schemes
struct GlassTheme: Equatable {
    /// Background opacity (0.1-0.9)
    /// Lower values create more transparent backgrounds
    let backgroundOpacity: Double
    
    /// Blur radius for the frosted glass effect (5-30)
    /// Higher values create more blur
    let blurRadius: CGFloat
    
    /// Corner radius for rounded edges (8-24)
    let cornerRadius: CGFloat
    
    /// Border width for the glass edge
    let borderWidth: CGFloat
    
    /// Border color for the glass edge
    let borderColor: Color
    
    /// Shadow configuration for depth effect
    let shadow: GlassShadow
    
    /// Creates a new glass theme configuration
    /// - Parameters:
    ///   - backgroundOpacity: Background transparency (0.1-0.9)
    ///   - blurRadius: Blur effect radius (5-30)
    ///   - cornerRadius: Corner rounding (8-24)
    ///   - borderWidth: Edge border width
    ///   - borderColor: Edge border color
    ///   - shadow: Shadow configuration
    init(
        backgroundOpacity: Double,
        blurRadius: CGFloat,
        cornerRadius: CGFloat,
        borderWidth: CGFloat,
        borderColor: Color,
        shadow: GlassShadow
    ) {
        self.backgroundOpacity = backgroundOpacity
        self.blurRadius = blurRadius
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.shadow = shadow
    }
    
    // MARK: - Static Theme Instances
    
    /// Default light mode theme
    /// Optimized for light system appearance with subtle transparency
    /// Requirements: 1.3 - Light mode color scheme
    static let light = GlassTheme(
        backgroundOpacity: 0.3,
        blurRadius: 10,
        cornerRadius: 16,
        borderWidth: 0.5,
        borderColor: Color.black.opacity(0.05),
        shadow: .lightDefault
    )
    
    /// Default dark mode theme
    /// Optimized for dark system appearance with enhanced contrast
    /// Requirements: 1.3 - Dark mode color scheme
    static let dark = GlassTheme(
        backgroundOpacity: 0.4,
        blurRadius: 12,
        cornerRadius: 16,
        borderWidth: 0.5,
        borderColor: Color.white.opacity(0.1),
        shadow: .darkDefault
    )
    
    // MARK: - Theme Selection
    
    /// Returns the appropriate theme for the given color scheme
    /// - Parameter colorScheme: The current system color scheme
    /// - Returns: The matching GlassTheme instance
    static func theme(for colorScheme: ColorScheme) -> GlassTheme {
        switch colorScheme {
        case .dark:
            return .dark
        case .light:
            return .light
        @unknown default:
            return .light
        }
    }
    
    // MARK: - Validation Helpers
    
    /// Validates and clamps background opacity to valid range (0.1-0.9)
    /// - Parameter value: The input opacity value
    /// - Returns: Clamped opacity value within valid range
    static func clampedOpacity(_ value: Double) -> Double {
        return min(max(value, 0.1), 0.9)
    }
    
    /// Validates and clamps blur radius to valid range (5-30)
    /// - Parameter value: The input blur radius
    /// - Returns: Clamped blur radius within valid range
    static func clampedBlurRadius(_ value: CGFloat) -> CGFloat {
        return min(max(value, 5), 30)
    }
    
    /// Validates and clamps corner radius to valid range (8-24)
    /// - Parameter value: The input corner radius
    /// - Returns: Clamped corner radius within valid range
    static func clampedCornerRadius(_ value: CGFloat) -> CGFloat {
        return min(max(value, 8), 24)
    }
    
    /// Creates a theme with validated/clamped parameters
    /// - Parameters:
    ///   - backgroundOpacity: Background transparency (will be clamped to 0.1-0.9)
    ///   - blurRadius: Blur effect radius (will be clamped to 5-30)
    ///   - cornerRadius: Corner rounding (will be clamped to 8-24)
    ///   - borderWidth: Edge border width
    ///   - borderColor: Edge border color
    ///   - shadow: Shadow configuration
    /// - Returns: A new GlassTheme with validated parameters
    static func validated(
        backgroundOpacity: Double,
        blurRadius: CGFloat,
        cornerRadius: CGFloat,
        borderWidth: CGFloat,
        borderColor: Color,
        shadow: GlassShadow
    ) -> GlassTheme {
        return GlassTheme(
            backgroundOpacity: clampedOpacity(backgroundOpacity),
            blurRadius: clampedBlurRadius(blurRadius),
            cornerRadius: clampedCornerRadius(cornerRadius),
            borderWidth: borderWidth,
            borderColor: borderColor,
            shadow: shadow
        )
    }
}

// MARK: - GlassTheme + CustomStringConvertible

extension GlassTheme: CustomStringConvertible {
    var description: String {
        return """
        GlassTheme(
            backgroundOpacity: \(backgroundOpacity),
            blurRadius: \(blurRadius),
            cornerRadius: \(cornerRadius),
            borderWidth: \(borderWidth)
        )
        """
    }
}
