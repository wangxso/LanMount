//
//  NavigationModels.swift
//  LanMount
//
//  Created for bottom navigation bar refactor
//

import SwiftUI

// MARK: - AppTab

/// 应用选项卡枚举
/// Defines all tab types for the bottom navigation bar
enum AppTab: Int, CaseIterable, Identifiable {
    case overview = 0
    case diskConfig = 1
    case diskInfo = 2
    case systemConfig = 3
    
    var id: Int { rawValue }
    
    /// 选项卡标题
    var title: String {
        switch self {
        case .overview: return NSLocalizedString("概览", comment: "Overview tab")
        case .diskConfig: return NSLocalizedString("磁盘配置", comment: "Disk config tab")
        case .diskInfo: return NSLocalizedString("磁盘信息", comment: "Disk info tab")
        case .systemConfig: return NSLocalizedString("系统配置", comment: "System config tab")
        }
    }
    
    /// 选项卡图标 (SF Symbols)
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .diskConfig: return "externaldrive.badge.plus"
        case .diskInfo: return "chart.pie"
        case .systemConfig: return "gearshape"
        }
    }
    
    /// 键盘快捷键
    var keyboardShortcut: KeyEquivalent {
        switch self {
        case .overview: return "1"
        case .diskConfig: return "2"
        case .diskInfo: return "3"
        case .systemConfig: return "4"
        }
    }
}

// MARK: - TabBadgeData

/// 选项卡徽章数据
/// Represents badge information displayed on tab items
struct TabBadgeData: Equatable {
    
    // MARK: - BadgeType
    
    /// 徽章类型
    enum BadgeType: Equatable {
        case count(Int)     // 数字徽章
        case dot            // 圆点徽章
    }
    
    // MARK: - BadgeColor
    
    /// 徽章颜色
    enum BadgeColor: Equatable {
        case red            // 错误
        case orange         // 警告
        case blue           // 信息
        case green          // 成功
        
        var color: Color {
            switch self {
            case .red: return .red
            case .orange: return .orange
            case .blue: return .blue
            case .green: return .green
            }
        }
    }
    
    // MARK: - Properties
    
    let type: BadgeType
    let color: BadgeColor
    
    // MARK: - Computed Properties
    
    /// 是否应该显示徽章
    /// Returns true if the badge should be visible
    var shouldShow: Bool {
        switch type {
        case .count(let count): return count > 0
        case .dot: return true
        }
    }
    
    // MARK: - Initialization
    
    init(type: BadgeType, color: BadgeColor) {
        self.type = type
        self.color = color
    }
}
