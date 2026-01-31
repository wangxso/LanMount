//
//  AdaptiveGrid.swift
//  LanMount
//
//  Adaptive grid layout component that automatically adjusts column count based on window width
//  Requirements: 7.2 - Support compact, regular, and expanded layout breakpoints
//  Requirements: 7.3 - Automatically adjust layout based on window width
//  Requirements: 7.4 - Maintain consistent spacing and alignment across breakpoints
//

import SwiftUI

// MARK: - AdaptiveGrid

/// A responsive grid layout that automatically adjusts the number of columns based on available width
///
/// AdaptiveGrid uses the LayoutBreakpoint system to determine how many columns to display:
/// - Compact (< 600pt): Single column layout
/// - Regular (600-800pt): Two column layout
/// - Expanded (>= 800pt): Multi-column layout based on minItemWidth
///
/// The grid maintains consistent spacing and alignment across all breakpoints.
///
/// Example usage:
/// ```swift
/// AdaptiveGrid(minItemWidth: 300, spacing: 16) {
///     ForEach(connections) { connection in
///         ConnectionCard(connection: connection)
///     }
/// }
/// .padding()
/// ```
struct AdaptiveGrid<Content: View>: View {
    /// Minimum width for each grid item
    let minItemWidth: CGFloat
    
    /// Spacing between grid items (both horizontal and vertical)
    let spacing: CGFloat
    
    /// The content to display in the grid
    let content: Content
    
    /// Creates a new adaptive grid
    ///
    /// - Parameters:
    ///   - minItemWidth: Minimum width for each item (default: 300)
    ///   - spacing: Spacing between items (default: 16)
    ///   - content: A view builder closure that provides the grid content
    init(
        minItemWidth: CGFloat = 300,
        spacing: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.minItemWidth = minItemWidth
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            let breakpoint = LayoutBreakpoint.from(width: geometry.size.width)
            let columns = calculateColumns(for: geometry.size.width, breakpoint: breakpoint)
            
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
                    spacing: spacing
                ) {
                    content
                }
            }
        }
    }
    
    /// Calculates the number of columns based on available width and breakpoint
    ///
    /// - Parameters:
    ///   - width: Available container width
    ///   - breakpoint: Current layout breakpoint
    /// - Returns: Number of columns to display
    private func calculateColumns(for width: CGFloat, breakpoint: LayoutBreakpoint) -> Int {
        switch breakpoint {
        case .compact:
            // Always single column in compact mode
            return 1
        case .regular:
            // Two columns in regular mode
            return 2
        case .expanded:
            // Calculate based on minItemWidth, minimum 3 columns
            let calculatedColumns = max(1, Int(width / minItemWidth))
            return max(3, calculatedColumns)
        }
    }
}

// MARK: - AdaptiveGrid + Items Convenience Initializer

extension AdaptiveGrid {
    /// Creates a new adaptive grid with an array of identifiable items
    ///
    /// This convenience initializer provides a simpler API when you have a collection of items to display.
    ///
    /// - Parameters:
    ///   - items: The array of items to display
    ///   - minItemWidth: Minimum width for each item (default: 300)
    ///   - spacing: Spacing between items (default: 16)
    ///   - content: A closure that returns a view for each item
    init<Item: Identifiable, ItemContent: View>(
        items: [Item],
        minItemWidth: CGFloat = 300,
        spacing: CGFloat = 16,
        @ViewBuilder content: @escaping (Item) -> ItemContent
    ) where Content == ForEach<[Item], Item.ID, ItemContent> {
        self.minItemWidth = minItemWidth
        self.spacing = spacing
        self.content = ForEach(items) { item in
            content(item)
        }
    }
}

// MARK: - AdaptiveGridWithItems

/// A convenience wrapper for AdaptiveGrid that works with arrays of identifiable items
///
/// This provides a simpler API when you have a collection of items to display.
///
/// Example usage:
/// ```swift
/// AdaptiveGridWithItems(items: connections) { connection in
///     ConnectionCard(connection: connection)
/// }
/// ```
struct AdaptiveGridWithItems<Item: Identifiable, ItemContent: View>: View {
    /// The items to display in the grid
    let items: [Item]
    
    /// Minimum width for each grid item
    let minItemWidth: CGFloat
    
    /// Spacing between grid items
    let spacing: CGFloat
    
    /// The content closure that creates a view for each item
    let itemContent: (Item) -> ItemContent
    
    /// Creates a new adaptive grid with items
    ///
    /// - Parameters:
    ///   - items: The array of items to display
    ///   - minItemWidth: Minimum width for each item (default: 300)
    ///   - spacing: Spacing between items (default: 16)
    ///   - content: A closure that returns a view for each item
    init(
        items: [Item],
        minItemWidth: CGFloat = 300,
        spacing: CGFloat = 16,
        @ViewBuilder content: @escaping (Item) -> ItemContent
    ) {
        self.items = items
        self.minItemWidth = minItemWidth
        self.spacing = spacing
        self.itemContent = content
    }
    
    var body: some View {
        AdaptiveGrid(minItemWidth: minItemWidth, spacing: spacing) {
            ForEach(items) { item in
                itemContent(item)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AdaptiveGrid_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Compact preview (1 column)
            VStack {
                Text("Compact Layout (< 600pt)")
                    .font(.headline)
                AdaptiveGrid(minItemWidth: 200, spacing: 12) {
                    ForEach(1...6, id: \.self) { item in
                        GlassCard {
                            VStack {
                                Text("Item \(item)")
                                    .font(.headline)
                                Text("Compact layout")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }
                }
            }
            .frame(width: 400, height: 600)
            .previewDisplayName("Compact")

            // Regular preview (2 columns)
            VStack {
                Text("Regular Layout (600-800pt)")
                    .font(.headline)
                AdaptiveGrid(minItemWidth: 200, spacing: 12) {
                    ForEach(1...6, id: \.self) { item in
                        GlassCard {
                            VStack {
                                Text("Item \(item)")
                                    .font(.headline)
                                Text("Regular layout")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }
                }
            }
            .frame(width: 700, height: 600)
            .previewDisplayName("Regular")

            // Expanded preview (3+ columns)
            VStack {
                Text("Expanded Layout (>= 800pt)")
                    .font(.headline)
                AdaptiveGrid(minItemWidth: 200, spacing: 12) {
                    ForEach(1...6, id: \.self) { item in
                        GlassCard {
                            VStack {
                                Text("Item \(item)")
                                    .font(.headline)
                                Text("Expanded layout")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }
                }
            }
            .frame(width: 1000, height: 600)
            .previewDisplayName("Expanded")
        }
    }
}
#endif
