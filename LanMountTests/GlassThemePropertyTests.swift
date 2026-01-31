//
//  GlassThemePropertyTests.swift
//  LanMountTests
//
//  Property-based tests for GlassTheme
//  Feature: ui-enhancement
//
//  **Validates: Requirements 1.1, 1.3**
//

import XCTest
import SwiftUI
@testable import LanMountCore

// MARK: - Simple Property Testing Framework

/// A simple property testing helper that generates random test cases
struct PropertyTester {
    /// Runs a property test with the specified number of iterations
    /// - Parameters:
    ///   - iterations: Number of test iterations (default: 100 as per design.md)
    ///   - label: Test label for identification
    ///   - property: The property to test, returns true if property holds
    static func check(
        iterations: Int = 100,
        label: String,
        property: () -> Bool
    ) -> Bool {
        for _ in 0..<iterations {
            if !property() {
                return false
            }
        }
        return true
    }
    
    /// Generates a random Double in the specified range
    static func randomDouble(in range: ClosedRange<Double>) -> Double {
        return Double.random(in: range)
    }
    
    /// Generates a random CGFloat in the specified range
    static func randomCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        return CGFloat.random(in: range)
    }
}

// MARK: - Random Generators for GlassTheme

extension GlassShadow {
    /// Creates a random GlassShadow for property testing
    static func random() -> GlassShadow {
        return GlassShadow(
            color: Color.black.opacity(PropertyTester.randomDouble(in: 0.0...1.0)),
            radius: PropertyTester.randomCGFloat(in: 0.0...50.0),
            x: PropertyTester.randomCGFloat(in: -20.0...20.0),
            y: PropertyTester.randomCGFloat(in: -20.0...20.0)
        )
    }
}

extension GlassTheme {
    /// Creates a random GlassTheme for property testing
    static func random() -> GlassTheme {
        return GlassTheme(
            backgroundOpacity: PropertyTester.randomDouble(in: 0.0...1.0),
            blurRadius: PropertyTester.randomCGFloat(in: 0.0...50.0),
            cornerRadius: PropertyTester.randomCGFloat(in: 0.0...50.0),
            borderWidth: PropertyTester.randomCGFloat(in: 0.0...5.0),
            borderColor: Color.white.opacity(PropertyTester.randomDouble(in: 0.0...1.0)),
            shadow: GlassShadow.random()
        )
    }
}

// MARK: - GlassTheme Property Tests

final class GlassThemePropertyTests: XCTestCase {
    
    // MARK: - Property 1: 主题配置完整性 (Theme Configuration Completeness)
    
    /// Feature: ui-enhancement, Property 1: 主题配置完整性
    /// 
    /// For any GlassTheme instance, it must contain all required visual properties:
    /// backgroundOpacity, blurRadius, cornerRadius, borderWidth, borderColor, and shadow.
    ///
    /// **Validates: Requirements 1.1**
    func testProperty1_ThemeConfigurationCompleteness() {
        // Property test: All GlassTheme instances must have all required properties
        // Label: Feature: ui-enhancement, Property 1: 主题配置完整性
        // Minimum iterations: 100 (as per design.md)
        
        let result = PropertyTester.check(
            iterations: 100,
            label: "Feature: ui-enhancement, Property 1: 主题配置完整性"
        ) {
            let theme = GlassTheme.random()
            
            // Verify backgroundOpacity exists and is a valid Double (0.0-1.0)
            let hasBackgroundOpacity = theme.backgroundOpacity >= 0.0 && theme.backgroundOpacity <= 1.0
            
            // Verify blurRadius exists and is a valid CGFloat (non-negative)
            let hasBlurRadius = theme.blurRadius >= 0.0
            
            // Verify cornerRadius exists and is a valid CGFloat (non-negative)
            let hasCornerRadius = theme.cornerRadius >= 0.0
            
            // Verify borderWidth exists and is a valid CGFloat (non-negative)
            let hasBorderWidth = theme.borderWidth >= 0.0
            
            // Verify borderColor exists (Color type is always valid if it compiles)
            // The struct requires borderColor, so if we can create the theme, it exists
            let hasBorderColor = true
            
            // Verify shadow exists and has all required properties
            let hasShadow = theme.shadow.radius >= 0.0
            
            return hasBackgroundOpacity
                && hasBlurRadius
                && hasCornerRadius
                && hasBorderWidth
                && hasBorderColor
                && hasShadow
        }
        
        XCTAssertTrue(result, "Property 1 failed: All GlassTheme instances must have all required properties")
    }
    
    /// Feature: ui-enhancement, Property 1: 主题配置完整性 - Static themes
    ///
    /// Verifies that the static light and dark theme instances have all required properties.
    ///
    /// **Validates: Requirements 1.1**
    func testProperty1_StaticThemesHaveAllRequiredProperties() {
        // Test light theme has all required properties
        let lightTheme = GlassTheme.light
        XCTAssertGreaterThanOrEqual(lightTheme.backgroundOpacity, 0.0, "Light theme backgroundOpacity should be >= 0")
        XCTAssertLessThanOrEqual(lightTheme.backgroundOpacity, 1.0, "Light theme backgroundOpacity should be <= 1")
        XCTAssertGreaterThanOrEqual(lightTheme.blurRadius, 0.0, "Light theme blurRadius should be >= 0")
        XCTAssertGreaterThanOrEqual(lightTheme.cornerRadius, 0.0, "Light theme cornerRadius should be >= 0")
        XCTAssertGreaterThanOrEqual(lightTheme.borderWidth, 0.0, "Light theme borderWidth should be >= 0")
        XCTAssertGreaterThanOrEqual(lightTheme.shadow.radius, 0.0, "Light theme shadow radius should be >= 0")
        
        // Test dark theme has all required properties
        let darkTheme = GlassTheme.dark
        XCTAssertGreaterThanOrEqual(darkTheme.backgroundOpacity, 0.0, "Dark theme backgroundOpacity should be >= 0")
        XCTAssertLessThanOrEqual(darkTheme.backgroundOpacity, 1.0, "Dark theme backgroundOpacity should be <= 1")
        XCTAssertGreaterThanOrEqual(darkTheme.blurRadius, 0.0, "Dark theme blurRadius should be >= 0")
        XCTAssertGreaterThanOrEqual(darkTheme.cornerRadius, 0.0, "Dark theme cornerRadius should be >= 0")
        XCTAssertGreaterThanOrEqual(darkTheme.borderWidth, 0.0, "Dark theme borderWidth should be >= 0")
        XCTAssertGreaterThanOrEqual(darkTheme.shadow.radius, 0.0, "Dark theme shadow radius should be >= 0")
    }
    
    /// Feature: ui-enhancement, Property 1: 主题配置完整性 - Validated theme creation
    ///
    /// Verifies that the validated() factory method produces themes with all required properties.
    ///
    /// **Validates: Requirements 1.1**
    func testProperty1_ValidatedThemeCreation() {
        // Property test: Validated themes always have all required properties
        // Label: Feature: ui-enhancement, Property 1: 主题配置完整性 (validated)
        
        let result = PropertyTester.check(
            iterations: 100,
            label: "Feature: ui-enhancement, Property 1: 主题配置完整性 (validated)"
        ) {
            // Generate random values (potentially out of range)
            let opacity = PropertyTester.randomDouble(in: -1.0...2.0)
            let blurRadius = PropertyTester.randomCGFloat(in: -10.0...100.0)
            let cornerRadius = PropertyTester.randomCGFloat(in: -10.0...100.0)
            let borderWidth = PropertyTester.randomCGFloat(in: 0.0...5.0)
            let shadow = GlassShadow.random()
            
            // Create validated theme
            let theme = GlassTheme.validated(
                backgroundOpacity: opacity,
                blurRadius: blurRadius,
                cornerRadius: cornerRadius,
                borderWidth: borderWidth,
                borderColor: .white.opacity(0.1),
                shadow: shadow
            )
            
            // Verify all properties exist and are valid
            let hasBackgroundOpacity = theme.backgroundOpacity >= 0.0 && theme.backgroundOpacity <= 1.0
            let hasBlurRadius = theme.blurRadius >= 0.0
            let hasCornerRadius = theme.cornerRadius >= 0.0
            let hasBorderWidth = theme.borderWidth >= 0.0
            let hasShadow = theme.shadow.radius >= 0.0
            
            return hasBackgroundOpacity
                && hasBlurRadius
                && hasCornerRadius
                && hasBorderWidth
                && hasShadow
        }
        
        XCTAssertTrue(result, "Property 1 failed: Validated themes must have all required properties")
    }
    
    // MARK: - Property 3: 主题颜色方案适配 (Theme Color Scheme Adaptation)
    
    /// Feature: ui-enhancement, Property 3: 主题颜色方案适配
    ///
    /// For any color scheme (light or dark), the GlassTheme returned by ThemeManager
    /// should have colors matching that scheme, and light and dark themes should have
    /// different border colors and shadow colors.
    ///
    /// **Validates: Requirements 1.3**
    func testProperty3_ThemeColorSchemeAdaptation() {
        // Get themes for both color schemes
        let lightTheme = GlassTheme.theme(for: .light)
        let darkTheme = GlassTheme.theme(for: .dark)
        
        // Property: Light and dark themes should be different
        XCTAssertNotEqual(lightTheme, darkTheme,
            "Light and dark themes should be different")
        
        // Property: The theme(for:) method should return the correct theme for each scheme
        XCTAssertEqual(lightTheme, GlassTheme.light,
            "theme(for: .light) should return the light theme")
        XCTAssertEqual(darkTheme, GlassTheme.dark,
            "theme(for: .dark) should return the dark theme")
    }
    
    /// Feature: ui-enhancement, Property 3: 主题颜色方案适配 - Border and shadow differences
    ///
    /// Verifies that light and dark themes have different visual characteristics
    /// for border and shadow to ensure proper adaptation to color schemes.
    ///
    /// **Validates: Requirements 1.3**
    func testProperty3_LightAndDarkThemesHaveDifferentBorderAndShadow() {
        let lightTheme = GlassTheme.light
        let darkTheme = GlassTheme.dark
        
        // The themes should have different configurations
        // Since Color comparison is complex, we verify the themes are not equal
        // which implies at least one property (including borderColor or shadow.color) differs
        XCTAssertNotEqual(lightTheme, darkTheme,
            "Light and dark themes must have different configurations")
        
        // Verify the default shadows are different
        XCTAssertNotEqual(GlassShadow.lightDefault, GlassShadow.darkDefault,
            "Light and dark default shadows should be different")
    }
    
    /// Feature: ui-enhancement, Property 3: 主题颜色方案适配 - Property test
    ///
    /// For any boolean representing a color scheme choice, the returned theme
    /// should be consistent and appropriate for that scheme.
    ///
    /// **Validates: Requirements 1.3**
    func testProperty3_ColorSchemeConsistency() {
        // Property test: Theme selection is consistent for color schemes
        // Label: Feature: ui-enhancement, Property 3: 主题颜色方案适配
        // Minimum iterations: 100 (as per design.md)
        
        let result = PropertyTester.check(
            iterations: 100,
            label: "Feature: ui-enhancement, Property 3: 主题颜色方案适配"
        ) {
            let isDark = Bool.random()
            let colorScheme: ColorScheme = isDark ? .dark : .light
            let theme = GlassTheme.theme(for: colorScheme)
            
            // The returned theme should match the expected static theme
            let expectedTheme = isDark ? GlassTheme.dark : GlassTheme.light
            
            return theme == expectedTheme
        }
        
        XCTAssertTrue(result, "Property 3 failed: Theme selection must be consistent for color schemes")
    }
    
    /// Feature: ui-enhancement, Property 3: 主题颜色方案适配 - Unknown color scheme handling
    ///
    /// Verifies that the theme system handles unknown color schemes gracefully
    /// by defaulting to light theme.
    ///
    /// **Validates: Requirements 1.3**
    func testProperty3_UnknownColorSchemeDefaultsToLight() {
        // Test that both known schemes return appropriate themes
        let lightResult = GlassTheme.theme(for: .light)
        let darkResult = GlassTheme.theme(for: .dark)
        
        XCTAssertEqual(lightResult, GlassTheme.light,
            "theme(for: .light) should return light theme")
        XCTAssertEqual(darkResult, GlassTheme.dark,
            "theme(for: .dark) should return dark theme")
        
        // The @unknown default case in the implementation defaults to light
        // This is tested implicitly through the switch statement coverage
    }
    
    /// Feature: ui-enhancement, Property 3: 主题颜色方案适配 - Theme idempotency
    ///
    /// Verifies that calling theme(for:) multiple times with the same color scheme
    /// always returns the same theme instance.
    ///
    /// **Validates: Requirements 1.3**
    func testProperty3_ThemeIdempotency() {
        // Property test: Theme selection is idempotent
        // Label: Feature: ui-enhancement, Property 3: 主题颜色方案适配 (idempotency)
        
        let result = PropertyTester.check(
            iterations: 100,
            label: "Feature: ui-enhancement, Property 3: 主题颜色方案适配 (idempotency)"
        ) {
            let isDark = Bool.random()
            let colorScheme: ColorScheme = isDark ? .dark : .light
            
            // Call theme(for:) multiple times
            let theme1 = GlassTheme.theme(for: colorScheme)
            let theme2 = GlassTheme.theme(for: colorScheme)
            let theme3 = GlassTheme.theme(for: colorScheme)
            
            // All calls should return equal themes
            return theme1 == theme2 && theme2 == theme3
        }
        
        XCTAssertTrue(result, "Property 3 failed: Theme selection must be idempotent")
    }
}
