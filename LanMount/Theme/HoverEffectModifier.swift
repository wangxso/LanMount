//
//  HoverEffectModifier.swift
//  LanMount
//
//  Hover effect view modifier for interactive elements
//  Requirements: 1.4, 1.5
//

import SwiftUI

// MARK: - HoverEffectModifier

/// A view modifier that applies hover effects to interactive elements
///
/// This modifier creates a subtle interactive feedback with:
/// - Scale animation on hover
/// - Brightness adjustment for visual feedback
/// - Smooth easeInOut animation
///
/// The modifier is designed for macOS where hover interactions are common,
/// providing visual feedback when the user's cursor enters or leaves the view.
///
/// Requirements: 1.4 - Provides smooth hover and click animation effects for all interactive elements
/// Requirements: 1.5 - Displays subtle highlight and shadow changes when user interacts with Glass_Card
struct HoverEffectModifier: ViewModifier {
    /// Tracks whether the view is currently being hovered
    @State private var isHovered = false
    
    /// Scale factor when hovered (1.0 = no scale, > 1.0 = enlarge)
    let scaleAmount: CGFloat
    
    /// Opacity for highlight effect (reserved for future use)
    /// Note: Currently using brightness instead of overlay for cleaner effect
    let highlightOpacity: Double
    
    // MARK: - Body
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scaleAmount : 1.0)
            .brightness(isHovered ? 0.05 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - View Extension

extension View {
    /// Applies a hover effect to the view with scale and brightness animation
    ///
    /// Creates an interactive feedback effect when the user hovers over the view.
    /// The view will slightly scale up and brighten, providing visual confirmation
    /// of the interactive element.
    ///
    /// Example usage:
    /// ```swift
    /// Button("Click Me") {
    ///     // action
    /// }
    /// .hoverEffect()
    ///
    /// // With custom parameters
    /// GlassCard {
    ///     // content
    /// }
    /// .hoverEffect(scale: 1.05, highlightOpacity: 0.15)
    /// ```
    ///
    /// - Parameters:
    ///   - scale: Scale factor when hovered (default: 1.02, subtle enlargement)
    ///   - highlightOpacity: Opacity for highlight effect (default: 0.1, reserved for future use)
    /// - Returns: A view with the hover effect applied
    ///
    /// Requirements: 1.4 - Provides smooth hover and click animation effects for all interactive elements
    /// Requirements: 1.5 - Displays subtle highlight and shadow changes when user interacts with Glass_Card
    func hoverEffect(
        scale: CGFloat = 1.02,
        highlightOpacity: Double = 0.1
    ) -> some View {
        modifier(HoverEffectModifier(
            scaleAmount: scale,
            highlightOpacity: highlightOpacity
        ))
    }
}

// MARK: - Preview

#if DEBUG
struct HoverEffectModifier_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Hover Effect Demo")
                    .font(.title)
                    .foregroundColor(.white)
                
                // Default hover effect
                Text("Default Hover Effect")
                    .font(.headline)
                    .padding()
                    .glassBackground()
                    .hoverEffect()
                
                // Custom scale hover effect
                Text("Custom Scale (1.05)")
                    .font(.headline)
                    .padding()
                    .glassBackground()
                    .hoverEffect(scale: 1.05)
                
                // Subtle hover effect
                Text("Subtle Scale (1.01)")
                    .font(.headline)
                    .padding()
                    .glassBackground()
                    .hoverEffect(scale: 1.01)
                
                // Button with hover effect
                Button(action: {}) {
                    Text("Interactive Button")
                        .font(.headline)
                        .padding()
                }
                .buttonStyle(.plain)
                .glassBackground()
                .hoverEffect()
                
                Text("Hover over the elements above to see the effect")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .previewDisplayName("Hover Effect Demo")
    }
}
#endif
