//
//  GlassBackgroundModifier.swift
//  LanMount
//
//  Glass background view modifier for glassmorphism design
//  Requirements: 1.1, 1.3
//

import SwiftUI

// MARK: - GlassBackgroundModifier

/// A view modifier that applies a glassmorphism background effect
///
/// This modifier creates a frosted glass appearance with:
/// - Semi-transparent background using `.ultraThinMaterial`
/// - Rounded corners
/// - Subtle border for edge definition
/// - Soft shadow for depth
///
/// The modifier automatically adapts to light and dark color schemes,
/// adjusting border and shadow colors for optimal visibility.
///
/// Requirements: 1.1 - Provides unified glassmorphism visual style
/// Requirements: 1.3 - Automatically adapts to light and dark mode
struct GlassBackgroundModifier: ViewModifier {
    /// Background opacity (0.0-1.0)
    let opacity: Double
    
    /// Blur radius for the glass effect
    /// Note: This parameter is reserved for future custom blur implementations.
    /// Currently, the modifier uses `.ultraThinMaterial` which has built-in blur.
    let blurRadius: CGFloat
    
    /// Corner radius for rounded edges
    let cornerRadius: CGFloat
    
    /// Current color scheme from environment
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Body
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(opacity)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 0.5)
            )
            .shadow(color: shadowColor, radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Computed Properties
    
    /// Border color adapted for current color scheme
    ///
    /// - Dark mode: Subtle white border for visibility against dark backgrounds
    /// - Light mode: Very subtle black border for definition without harshness
    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.1)
            : Color.black.opacity(0.05)
    }
    
    /// Shadow color adapted for current color scheme
    ///
    /// - Dark mode: Stronger shadow for depth on dark backgrounds
    /// - Light mode: Softer shadow for subtle depth effect
    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.3)
            : Color.black.opacity(0.1)
    }
}

// MARK: - View Extension

extension View {
    /// Applies a glassmorphism background effect to the view
    ///
    /// Creates a frosted glass appearance with semi-transparent background,
    /// subtle border, and soft shadow. Automatically adapts to light and dark modes.
    ///
    /// Example usage:
    /// ```swift
    /// Text("Hello, World!")
    ///     .padding()
    ///     .glassBackground()
    ///
    /// // With custom parameters
    /// VStack {
    ///     // content
    /// }
    /// .glassBackground(opacity: 0.5, cornerRadius: 20)
    /// ```
    ///
    /// - Parameters:
    ///   - opacity: Background opacity (default: 0.3)
    ///   - blurRadius: Blur radius for glass effect (default: 10)
    ///   - cornerRadius: Corner radius for rounded edges (default: 16)
    /// - Returns: A view with the glass background effect applied
    ///
    /// Requirements: 1.1 - Provides unified glassmorphism visual style
    /// Requirements: 1.3 - Automatically adapts to light and dark mode
    func glassBackground(
        opacity: Double = 0.3,
        blurRadius: CGFloat = 10,
        cornerRadius: CGFloat = 16
    ) -> some View {
        modifier(GlassBackgroundModifier(
            opacity: opacity,
            blurRadius: blurRadius,
            cornerRadius: cornerRadius
        ))
    }
    
    /// Applies a glassmorphism background effect using a GlassTheme configuration
    ///
    /// This variant allows using a pre-configured GlassTheme for consistent styling
    /// across the application.
    ///
    /// Example usage:
    /// ```swift
    /// VStack {
    ///     // content
    /// }
    /// .glassBackground(theme: .light)
    /// ```
    ///
    /// - Parameter theme: The GlassTheme configuration to use
    /// - Returns: A view with the glass background effect applied
    func glassBackground(theme: GlassTheme) -> some View {
        modifier(GlassBackgroundModifier(
            opacity: theme.backgroundOpacity,
            blurRadius: theme.blurRadius,
            cornerRadius: theme.cornerRadius
        ))
    }
}

// MARK: - Preview

#if DEBUG
struct GlassBackgroundModifier_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            ZStack {
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Glass Background")
                        .font(.title)
                        .padding()
                        .glassBackground()
                    
                    Text("Custom Opacity")
                        .font(.headline)
                        .padding()
                        .glassBackground(opacity: 0.5)
                    
                    Text("Custom Corner Radius")
                        .font(.headline)
                        .padding()
                        .glassBackground(cornerRadius: 24)
                    
                    Text("Using Theme")
                        .font(.headline)
                        .padding()
                        .glassBackground(theme: .light)
                }
                .padding()
            }
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
            
            // Dark mode preview
            ZStack {
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Glass Background")
                        .font(.title)
                        .padding()
                        .glassBackground()
                    
                    Text("Custom Opacity")
                        .font(.headline)
                        .padding()
                        .glassBackground(opacity: 0.5)
                    
                    Text("Custom Corner Radius")
                        .font(.headline)
                        .padding()
                        .glassBackground(cornerRadius: 24)
                    
                    Text("Using Theme")
                        .font(.headline)
                        .padding()
                        .glassBackground(theme: .dark)
                }
                .padding()
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
