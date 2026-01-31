//
//  VoiceOverAnnouncer.swift
//  LanMount
//
//  VoiceOver announcement utility for accessibility support
//  Requirements: 8.4 - Send VoiceOver announcements when status changes
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - VoiceOverAnnouncer

/// A utility class for sending VoiceOver announcements
///
/// This class provides a cross-platform way to send accessibility announcements
/// that will be read by VoiceOver on macOS or iOS.
///
/// Example usage:
/// ```swift
/// VoiceOverAnnouncer.shared.announce("Volume mounted successfully")
/// ```
@MainActor
class VoiceOverAnnouncer {
    /// Shared instance of the announcer
    static let shared = VoiceOverAnnouncer()

    /// Private initializer to enforce singleton pattern
    private init() {}

    /// Sends an accessibility announcement
    ///
    /// - Parameters:
    ///   - message: The message to announce
    ///   - priority: The announcement priority (default: .polite)
    func announce(_ message: String, priority: AnnouncementPriority = .polite) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #elseif canImport(AppKit)
        if let mainWindow = NSApp.mainWindow {
            NSAccessibility.post(element: mainWindow, notification: .announcementRequested, userInfo: [NSAccessibility.NotificationUserInfoKey.announcement: message])
        }
        #endif
    }

    /// Sends an accessibility announcement with a localized string
    ///
    /// - Parameters:
    ///   - key: The localization key
    ///   - comment: The localization comment
    ///   - priority: The announcement priority (default: .polite)
    func announceLocalized(_ key: String, comment: String, priority: AnnouncementPriority = .polite) {
        let message = NSLocalizedString(key, comment: comment)
        announce(message, priority: priority)
    }
}

// MARK: - AnnouncementPriority

/// Enumerates announcement priority levels
enum AnnouncementPriority {
    /// Polite announcements are queued and delivered when convenient
    case polite

    /// Assertive announcements interrupt current speech and are delivered immediately
    case assertive
}