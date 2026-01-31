//
//  BottomTabBar.swift
//  LanMount
//
//  Created for bottom navigation bar refactor
//  Implements the bottom navigation bar with glassmorphism style
//

import SwiftUI

// MARK: - BottomTabBar

/// 底部导航栏视图
/// A custom bottom navigation bar component with glassmorphism styling
///
/// Features:
/// - HStack layout arranging all TabBarItem components
/// - Glassmorphism background style using the existing theme system
/// - Fixed height of 70 pixels as per design specification
/// - Support for tab selection and badge display
/// - Optional callback for tab selection events
///
/// **Validates: Requirements 1.1, 1.6**
/// - 1.1: Tab_Bar fixed at bottom of main window, height 60-80 pixels
/// - 1.6: Tab_Bar uses glassmorphism style consistent with existing theme
struct BottomTabBar: View {
    
    // MARK: - Properties
    
    /// Binding to the currently selected tab
    @Binding var selectedTab: AppTab
    
    /// Dictionary of badge data for each tab
    var badges: [AppTab: TabBadgeData]
    
    /// Optional callback when a tab is selected
    var onTabSelected: ((AppTab) -> Void)?
    
    // MARK: - Constants
    
    /// 导航栏高度
    /// Fixed height for the bottom tab bar (70 pixels as per design)
    static let height: CGFloat = 70
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    badge: badges[tab]
                ) {
                    selectedTab = tab
                    onTabSelected?(tab)
                }
            }
        }
        .frame(height: Self.height)
        .glassBackground(opacity: 0.8, blurRadius: 20, cornerRadius: 0)
    }
}

// MARK: - Preview

#if DEBUG
struct BottomTabBar_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            PreviewWrapper()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            // Dark mode preview
            PreviewWrapper()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // With badges preview
            PreviewWrapperWithBadges()
                .preferredColorScheme(.dark)
                .previewDisplayName("With Badges")
        }
    }
    
    /// Preview wrapper to manage state
    private struct PreviewWrapper: View {
        @State private var selectedTab: AppTab = .overview
        
        var body: some View {
            ZStack {
                // Background gradient to showcase glass effect
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // Content area placeholder
                    Text("Content for: \(selectedTab.title)")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Bottom tab bar
                    BottomTabBar(
                        selectedTab: $selectedTab,
                        badges: [:]
                    )
                }
            }
            .frame(width: 500, height: 400)
        }
    }
    
    /// Preview wrapper with badges
    private struct PreviewWrapperWithBadges: View {
        @State private var selectedTab: AppTab = .overview
        
        var body: some View {
            ZStack {
                // Background gradient to showcase glass effect
                LinearGradient(
                    colors: [.indigo, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // Content area placeholder
                    VStack(spacing: 8) {
                        Text("Selected: \(selectedTab.title)")
                            .font(.title)
                            .foregroundColor(.white)
                        
                        Text("Tap tabs to switch")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Bottom tab bar with badges
                    BottomTabBar(
                        selectedTab: $selectedTab,
                        badges: [
                            .overview: TabBadgeData(type: .count(3), color: .blue),
                            .diskConfig: TabBadgeData(type: .count(2), color: .red),
                            .diskInfo: TabBadgeData(type: .dot, color: .orange)
                        ],
                        onTabSelected: { tab in
                            print("Tab selected: \(tab.title)")
                        }
                    )
                }
            }
            .frame(width: 500, height: 400)
        }
    }
}
#endif
