//
//  TabBarItem.swift
//  LanMount
//
//  Created for bottom navigation bar refactor
//  Implements individual tab item view for the bottom navigation bar
//

import SwiftUI

// MARK: - TabBarItem

/// 选项卡项视图
/// Displays a single tab item with icon, label, badge, and interaction effects
///
/// Features:
/// - Vertical layout with icon on top and text label below
/// - Selected state highlighting with accent color
/// - Hover effect with scale animation
/// - Badge display integration via TabBadgeView
/// - Keyboard shortcut support (Cmd+1/2/3/4)
///
/// **Validates: Requirements 1.4, 1.5, 7.3**
struct TabBarItem: View {
    
    // MARK: - Properties
    
    /// The tab this item represents
    let tab: AppTab
    
    /// Whether this tab is currently selected
    let isSelected: Bool
    
    /// Optional badge data to display
    let badge: TabBadgeData?
    
    /// Action to perform when the tab is tapped
    let action: () -> Void
    
    // MARK: - State
    
    /// Tracks whether the mouse is hovering over this item
    @State private var isHovered = false
    
    // MARK: - Body
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Icon with optional badge overlay
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 22))
                    
                    // Badge overlay
                    if let badge = badge, badge.shouldShow {
                        TabBadgeView(badge: badge)
                            .offset(x: 8, y: -4)
                    }
                }
                
                // Text label
                Text(tab.title)
                    .font(.system(size: 11))
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .keyboardShortcut(tab.keyboardShortcut, modifiers: .command)
    }
}

// MARK: - Preview

#if DEBUG
struct TabBarItem_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // All tabs in a row - simulating tab bar
            Text("Tab Bar Simulation").font(.headline)
            
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    TabBarItem(
                        tab: tab,
                        isSelected: tab == .overview,
                        badge: previewBadge(for: tab),
                        action: {}
                    )
                }
            }
            .frame(height: 70)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Divider()
            
            // Individual states
            Text("Individual States").font(.headline)
            
            HStack(spacing: 20) {
                // Unselected state
                VStack {
                    TabBarItem(
                        tab: .overview,
                        isSelected: false,
                        badge: nil,
                        action: {}
                    )
                    .frame(width: 80, height: 60)
                    Text("Unselected").font(.caption)
                }
                
                // Selected state
                VStack {
                    TabBarItem(
                        tab: .overview,
                        isSelected: true,
                        badge: nil,
                        action: {}
                    )
                    .frame(width: 80, height: 60)
                    Text("Selected").font(.caption)
                }
                
                // With count badge
                VStack {
                    TabBarItem(
                        tab: .diskConfig,
                        isSelected: false,
                        badge: TabBadgeData(type: .count(3), color: .red),
                        action: {}
                    )
                    .frame(width: 80, height: 60)
                    Text("With Badge").font(.caption)
                }
                
                // With dot badge
                VStack {
                    TabBarItem(
                        tab: .diskInfo,
                        isSelected: true,
                        badge: TabBadgeData(type: .dot, color: .orange),
                        action: {}
                    )
                    .frame(width: 80, height: 60)
                    Text("Selected + Dot").font(.caption)
                }
            }
            
            Divider()
            
            // Badge variations
            Text("Badge Variations").font(.headline)
            
            HStack(spacing: 20) {
                // Blue info badge
                TabBarItem(
                    tab: .overview,
                    isSelected: true,
                    badge: TabBadgeData(type: .count(5), color: .blue),
                    action: {}
                )
                .frame(width: 80, height: 60)
                
                // Red error badge
                TabBarItem(
                    tab: .diskConfig,
                    isSelected: false,
                    badge: TabBadgeData(type: .count(2), color: .red),
                    action: {}
                )
                .frame(width: 80, height: 60)
                
                // Orange warning badge
                TabBarItem(
                    tab: .diskInfo,
                    isSelected: false,
                    badge: TabBadgeData(type: .count(1), color: .orange),
                    action: {}
                )
                .frame(width: 80, height: 60)
                
                // Large count badge (99+)
                TabBarItem(
                    tab: .systemConfig,
                    isSelected: false,
                    badge: TabBadgeData(type: .count(150), color: .green),
                    action: {}
                )
                .frame(width: 80, height: 60)
            }
        }
        .padding()
        .frame(width: 500)
    }
    
    /// Helper function to generate preview badges for each tab
    private static func previewBadge(for tab: AppTab) -> TabBadgeData? {
        switch tab {
        case .overview:
            return TabBadgeData(type: .count(3), color: .blue)
        case .diskConfig:
            return TabBadgeData(type: .count(1), color: .red)
        case .diskInfo:
            return TabBadgeData(type: .dot, color: .orange)
        case .systemConfig:
            return nil
        }
    }
}
#endif
