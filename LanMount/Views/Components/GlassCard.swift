//
//  GlassCard.swift
//  LanMount
//
//  Reusable glass card component with glassmorphism design
//  Requirements: 1.2, 8.1
//

import SwiftUI

// MARK: - GlassCardAccessibility

/// Accessibility configuration for GlassCard
///
/// This struct encapsulates all accessibility-related properties for VoiceOver support.
/// Requirements: 8.1 - Provides complete content description for VoiceOver
struct GlassCardAccessibility {
    /// The accessibility label describing the card's content
    /// This is read by VoiceOver when the card receives focus
    let label: String?
    
    /// The accessibility hint providing additional context
    /// This describes what happens when the user interacts with the card
    let hint: String?
    
    /// The accessibility traits describing the card's behavior
    /// Common traits include .isButton, .isHeader, .isSelected, etc.
    let traits: AccessibilityTraits
    
    /// Whether the card should be treated as an accessibility element
    /// When true, VoiceOver treats the card as a single focusable element
    let isAccessibilityElement: Bool
    
    /// Creates a new accessibility configuration
    ///
    /// - Parameters:
    ///   - label: The accessibility label (nil for no custom label)
    ///   - hint: The accessibility hint (nil for no hint)
    ///   - traits: The accessibility traits (default: empty)
    ///   - isAccessibilityElement: Whether to treat as single element (default: true when label is provided)
    init(
        label: String? = nil,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        isAccessibilityElement: Bool? = nil
    ) {
        self.label = label
        self.hint = hint
        self.traits = traits
        // Default to true if a label is provided, false otherwise
        self.isAccessibilityElement = isAccessibilityElement ?? (label != nil)
    }
    
    /// A default configuration with no custom accessibility settings
    static let none = GlassCardAccessibility()
    
    /// Creates a configuration for a button-like card
    ///
    /// - Parameters:
    ///   - label: The button's accessibility label
    ///   - hint: Optional hint describing the action
    /// - Returns: A configured GlassCardAccessibility instance
    static func button(label: String, hint: String? = nil) -> GlassCardAccessibility {
        GlassCardAccessibility(
            label: label,
            hint: hint,
            traits: .isButton,
            isAccessibilityElement: true
        )
    }
    
    /// Creates a configuration for a header card
    ///
    /// - Parameters:
    ///   - label: The header's accessibility label
    /// - Returns: A configured GlassCardAccessibility instance
    static func header(label: String) -> GlassCardAccessibility {
        GlassCardAccessibility(
            label: label,
            hint: nil,
            traits: .isHeader,
            isAccessibilityElement: true
        )
    }
    
    /// Creates a configuration for a summary/information card
    ///
    /// - Parameters:
    ///   - label: The summary content to be read
    ///   - hint: Optional hint for additional context
    /// - Returns: A configured GlassCardAccessibility instance
    static func summary(label: String, hint: String? = nil) -> GlassCardAccessibility {
        GlassCardAccessibility(
            label: label,
            hint: hint,
            traits: .isSummaryElement,
            isAccessibilityElement: true
        )
    }
}

// MARK: - GlassCard

/// A reusable glass card container with glassmorphism design
///
/// GlassCard provides a frosted glass appearance for content containers,
/// supporting customizable transparency, blur, and corner radius.
/// All parameters are automatically clamped to valid ranges:
/// - Opacity: 0.1-0.9
/// - Blur radius: 5-30
/// - Corner radius: 8-24
///
/// Example usage:
/// ```swift
/// GlassCard {
///     VStack {
///         Text("Title")
///         Text("Content")
///     }
/// }
///
/// // With custom parameters
/// GlassCard(opacity: 0.5, blurRadius: 15, cornerRadius: 20) {
///     Text("Custom styled card")
/// }
///
/// // Without hover effect
/// GlassCard(isHoverable: false) {
///     Text("Static card")
/// }
///
/// // With accessibility support
/// GlassCard(
///     accessibilityLabel: "Storage Status",
///     accessibilityHint: "Double tap to view details"
/// ) {
///     Text("50% used")
/// }
///
/// // With full accessibility configuration
/// GlassCard(accessibility: .button(label: "Mount Drive", hint: "Double tap to mount")) {
///     Text("Mount")
/// }
/// ```
///
/// Requirements: 1.2 - Supports customizable opacity (0.1-0.9), blur radius (5-30), and corner radius (8-24)
/// Requirements: 8.1 - Provides complete VoiceOver content description
struct GlassCard<Content: View>: View {
    /// The content to display inside the card
    let content: Content
    
    /// Background opacity (clamped to 0.1-0.9)
    /// Lower values create more transparent backgrounds
    let opacity: Double
    
    /// Blur radius for the frosted glass effect (clamped to 5-30)
    /// Higher values create more blur
    let blurRadius: CGFloat
    
    /// Corner radius for rounded edges (clamped to 8-24)
    let cornerRadius: CGFloat
    
    /// Whether the card should show hover effects
    let isHoverable: Bool
    
    /// Accessibility configuration for VoiceOver support
    /// Requirements: 8.1
    let accessibility: GlassCardAccessibility
    
    // MARK: - Initialization
    
    /// Creates a new glass card with the specified parameters
    ///
    /// All numeric parameters are automatically clamped to their valid ranges
    /// to ensure consistent visual appearance.
    ///
    /// - Parameters:
    ///   - opacity: Background transparency (0.1-0.9, default: 0.3)
    ///   - blurRadius: Blur effect radius (5-30, default: 10)
    ///   - cornerRadius: Corner rounding (8-24, default: 16)
    ///   - isHoverable: Whether to show hover effects (default: true)
    ///   - accessibility: Accessibility configuration for VoiceOver (default: .none)
    ///   - content: The content view builder
    init(
        opacity: Double = 0.3,
        blurRadius: CGFloat = 10,
        cornerRadius: CGFloat = 16,
        isHoverable: Bool = true,
        accessibility: GlassCardAccessibility = .none,
        @ViewBuilder content: () -> Content
    ) {
        // Clamp parameters to valid ranges using GlassTheme helpers
        self.opacity = GlassTheme.clampedOpacity(opacity)
        self.blurRadius = GlassTheme.clampedBlurRadius(blurRadius)
        self.cornerRadius = GlassTheme.clampedCornerRadius(cornerRadius)
        self.isHoverable = isHoverable
        self.accessibility = accessibility
        self.content = content()
    }
    
    /// Creates a new glass card with simple accessibility parameters
    ///
    /// This convenience initializer provides a simpler API for common accessibility needs.
    ///
    /// - Parameters:
    ///   - opacity: Background transparency (0.1-0.9, default: 0.3)
    ///   - blurRadius: Blur effect radius (5-30, default: 10)
    ///   - cornerRadius: Corner rounding (8-24, default: 16)
    ///   - isHoverable: Whether to show hover effects (default: true)
    ///   - accessibilityLabel: The VoiceOver label for the card
    ///   - accessibilityHint: Optional hint describing the card's action
    ///   - accessibilityTraits: Accessibility traits (default: empty)
    ///   - content: The content view builder
    init(
        opacity: Double = 0.3,
        blurRadius: CGFloat = 10,
        cornerRadius: CGFloat = 16,
        isHoverable: Bool = true,
        accessibilityLabel: String?,
        accessibilityHint: String? = nil,
        accessibilityTraits: AccessibilityTraits = [],
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            opacity: opacity,
            blurRadius: blurRadius,
            cornerRadius: cornerRadius,
            isHoverable: isHoverable,
            accessibility: GlassCardAccessibility(
                label: accessibilityLabel,
                hint: accessibilityHint,
                traits: accessibilityTraits
            ),
            content: content
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        content
            .glassBackground(
                opacity: opacity,
                blurRadius: blurRadius,
                cornerRadius: cornerRadius
            )
            .modifier(ConditionalHoverModifier(isEnabled: isHoverable))
            .modifier(GlassCardAccessibilityModifier(accessibility: accessibility))
    }
}

// MARK: - GlassCardAccessibilityModifier

/// A view modifier that applies accessibility settings to GlassCard
///
/// This modifier conditionally applies VoiceOver accessibility attributes
/// based on the provided GlassCardAccessibility configuration.
/// Requirements: 8.1 - Provides complete VoiceOver content description
private struct GlassCardAccessibilityModifier: ViewModifier {
    /// The accessibility configuration to apply
    let accessibility: GlassCardAccessibility
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: accessibility.isAccessibilityElement ? .combine : .contain)
            .modifier(AccessibilityLabelModifier(label: accessibility.label))
            .modifier(AccessibilityHintModifier(hint: accessibility.hint))
            .accessibilityAddTraits(accessibility.traits)
    }
}

// MARK: - AccessibilityLabelModifier

/// A view modifier that conditionally applies an accessibility label
private struct AccessibilityLabelModifier: ViewModifier {
    let label: String?
    
    func body(content: Content) -> some View {
        if let label = label {
            content.accessibilityLabel(label)
        } else {
            content
        }
    }
}

// MARK: - AccessibilityHintModifier

/// A view modifier that conditionally applies an accessibility hint
private struct AccessibilityHintModifier: ViewModifier {
    let hint: String?
    
    func body(content: Content) -> some View {
        if let hint = hint {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

// MARK: - ConditionalHoverModifier

/// A view modifier that conditionally applies hover effects
///
/// This modifier allows GlassCard to optionally include hover effects
/// based on the `isHoverable` parameter.
private struct ConditionalHoverModifier: ViewModifier {
    /// Whether hover effects are enabled
    let isEnabled: Bool
    
    func body(content: Content) -> some View {
        if isEnabled {
            content.hoverEffect()
        } else {
            content
        }
    }
}

// MARK: - GlassCard + Convenience Initializers

extension GlassCard {
    /// Creates a glass card using a GlassTheme configuration
    ///
    /// This initializer allows using a pre-configured GlassTheme for consistent
    /// styling across the application.
    ///
    /// - Parameters:
    ///   - theme: The GlassTheme configuration to use
    ///   - isHoverable: Whether to show hover effects (default: true)
    ///   - accessibility: Accessibility configuration for VoiceOver (default: .none)
    ///   - content: The content view builder
    init(
        theme: GlassTheme,
        isHoverable: Bool = true,
        accessibility: GlassCardAccessibility = .none,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            opacity: theme.backgroundOpacity,
            blurRadius: theme.blurRadius,
            cornerRadius: theme.cornerRadius,
            isHoverable: isHoverable,
            accessibility: accessibility,
            content: content
        )
    }
    
    /// Creates a glass card using a GlassTheme with simple accessibility parameters
    ///
    /// - Parameters:
    ///   - theme: The GlassTheme configuration to use
    ///   - isHoverable: Whether to show hover effects (default: true)
    ///   - accessibilityLabel: The VoiceOver label for the card
    ///   - accessibilityHint: Optional hint describing the card's action
    ///   - content: The content view builder
    init(
        theme: GlassTheme,
        isHoverable: Bool = true,
        accessibilityLabel: String?,
        accessibilityHint: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            theme: theme,
            isHoverable: isHoverable,
            accessibility: GlassCardAccessibility(
                label: accessibilityLabel,
                hint: accessibilityHint
            ),
            content: content
        )
    }
}

// MARK: - Preview

#if DEBUG
struct GlassCard_Previews: PreviewProvider {
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
                    // Default glass card
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Default Glass Card")
                                .font(.headline)
                            Text("With default parameters")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // With accessibility label
                    GlassCard(
                        accessibilityLabel: "Storage Status Card",
                        accessibilityHint: "Shows current storage usage"
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accessible Card")
                                .font(.headline)
                            Text("With VoiceOver support")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // Button-style accessible card
                    GlassCard(
                        accessibility: .button(
                            label: "Mount All Drives",
                            hint: "Double tap to mount all configured drives"
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Button Card")
                                .font(.headline)
                            Text("With button accessibility traits")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // Header-style accessible card
                    GlassCard(
                        accessibility: .header(label: "Dashboard Overview")
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Header Card")
                                .font(.headline)
                            Text("With header accessibility traits")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // Summary-style accessible card
                    GlassCard(
                        accessibility: .summary(
                            label: "Total storage: 500GB used of 1TB, 50% capacity",
                            hint: "Tap for detailed breakdown"
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Summary Card")
                                .font(.headline)
                            Text("With summary accessibility traits")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // Custom opacity with accessibility
                    GlassCard(
                        opacity: 0.6,
                        accessibilityLabel: "High Opacity Card",
                        accessibilityTraits: .isStaticText
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Higher Opacity (0.6)")
                                .font(.headline)
                            Text("With custom traits")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode - Accessibility")
            
            // Dark mode preview
            ZStack {
                LinearGradient(
                    colors: [.indigo, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    GlassCard(
                        accessibilityLabel: "Dark Mode Card",
                        accessibilityHint: "Automatically adapts to dark mode"
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dark Mode Card")
                                .font(.headline)
                            Text("With VoiceOver support")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    GlassCard(
                        theme: .dark,
                        accessibilityLabel: "Dark Theme Card",
                        accessibilityHint: "Using dark theme configuration"
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Using Dark Theme")
                                .font(.headline)
                            Text("Theme-based styling with accessibility")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode - Accessibility")
        }
        .frame(width: 400, height: 800)
    }
}
#endif
