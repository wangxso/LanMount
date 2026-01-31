//
//  TabBadgeView.swift
//  LanMount
//
//  Created for bottom navigation bar refactor
//  Implements badge display for tab items
//

import SwiftUI

// MARK: - TabBadgeView

/// 选项卡徽章视图
/// Displays badges on tab items with support for count and dot modes
/// 
/// Supports two display modes:
/// - Count: Shows a number (displays "99+" for values > 99)
/// - Dot: Shows a simple colored dot
///
/// Supports four colors:
/// - Red: For errors
/// - Orange: For warnings
/// - Blue: For information
/// - Green: For success
///
/// **Validates: Requirements 8.5**
struct TabBadgeView: View {
    
    // MARK: - Properties
    
    /// The badge data to display
    let badge: TabBadgeData
    
    // MARK: - Body
    
    var body: some View {
        switch badge.type {
        case .count(let count):
            countBadge(count: count)
        case .dot:
            dotBadge
        }
    }
    
    // MARK: - Private Views
    
    /// Creates a count badge displaying a number
    /// - Parameter count: The count to display (shows "99+" if > 99)
    /// - Returns: A view displaying the count badge
    @ViewBuilder
    private func countBadge(count: Int) -> some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(badge.color.color))
            .fixedSize()
    }
    
    /// A dot badge view
    private var dotBadge: some View {
        Circle()
            .fill(badge.color.color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Preview

#if DEBUG
struct TabBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Count badges
            Group {
                Text("Count Badges").font(.headline)
                
                HStack(spacing: 20) {
                    // Red count badge
                    VStack {
                        TabBadgeView(badge: TabBadgeData(type: .count(5), color: .red))
                        Text("Red (5)").font(.caption)
                    }
                    
                    // Orange count badge
                    VStack {
                        TabBadgeView(badge: TabBadgeData(type: .count(12), color: .orange))
                        Text("Orange (12)").font(.caption)
                    }
                    
                    // Blue count badge
                    VStack {
                        TabBadgeView(badge: TabBadgeData(type: .count(99), color: .blue))
                        Text("Blue (99)").font(.caption)
                    }
                    
                    // Green count badge with overflow
                    VStack {
                        TabBadgeView(badge: TabBadgeData(type: .count(150), color: .green))
                        Text("Green (150→99+)").font(.caption)
                    }
                }
            }
            
            Divider()
            
            // Dot badges
            Group {
                Text("Dot Badges").font(.headline)
                
                HStack(spacing: 30) {
                    // Red dot
                    VStack {
                        TabBadgeView(badge: TabBadgeData(type: .dot, color: .red))
                        Text("Red").font(.caption)
                    }
                    
                    // Orange dot
                    VStack {
                        TabBadgeView(badge: TabBadgeData(type: .dot, color: .orange))
                        Text("Orange").font(.caption)
                    }
                    
                    // Blue dot
                    VStack {
                        TabBadgeView(badge: TabBadgeData(type: .dot, color: .blue))
                        Text("Blue").font(.caption)
                    }
                    
                    // Green dot
                    VStack {
                        TabBadgeView(badge: TabBadgeData(type: .dot, color: .green))
                        Text("Green").font(.caption)
                    }
                }
            }
            
            Divider()
            
            // Edge cases
            Group {
                Text("Edge Cases").font(.headline)
                
                HStack(spacing: 20) {
                    // Zero count (should still render, but shouldShow would be false)
                    VStack {
                        TabBadgeView(badge: TabBadgeData(type: .count(0), color: .red))
                        Text("Count 0").font(.caption)
                    }
                    
                    // Single digit
                    VStack {
                        TabBadgeView(badge: TabBadgeData(type: .count(1), color: .blue))
                        Text("Count 1").font(.caption)
                    }
                    
                    // Exactly 99
                    VStack {
                        TabBadgeView(badge: TabBadgeData(type: .count(99), color: .orange))
                        Text("Count 99").font(.caption)
                    }
                    
                    // Just over 99
                    VStack {
                        TabBadgeView(badge: TabBadgeData(type: .count(100), color: .green))
                        Text("Count 100").font(.caption)
                    }
                }
            }
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
