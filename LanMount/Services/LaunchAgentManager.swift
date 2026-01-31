//
//  LaunchAgentManager.swift
//  LanMount
//
//  Manages application launch at login using macOS ServiceManagement framework
//  Requirements: 2.1
//

import Foundation
import ServiceManagement

#if canImport(AppKit)
import AppKit
#endif

// MARK: - LaunchAgentManagerProtocol

/// Protocol defining the interface for managing application launch at login
/// Uses macOS ServiceManagement framework's SMAppService for modern login item management
protocol LaunchAgentManagerProtocol {
    /// Enables the application to launch automatically at user login
    /// - Throws: `SMBMounterError.launchAgentRegistrationFailed` if registration fails
    func enableLaunchAtLogin() throws
    
    /// Disables the application from launching automatically at user login
    /// - Throws: `SMBMounterError.launchAgentUnregistrationFailed` if unregistration fails
    func disableLaunchAtLogin() throws
    
    /// Checks whether the application is currently configured to launch at login
    /// - Returns: `true` if launch at login is enabled, `false` otherwise
    func isLaunchAtLoginEnabled() -> Bool
}

// MARK: - LaunchAgentManager

/// Implementation of LaunchAgentManagerProtocol using SMAppService
/// Manages the application's login item status through the modern ServiceManagement API
/// The login item will appear in "System Settings > General > Login Items"
@available(macOS 13.0, *)
final class LaunchAgentManager: LaunchAgentManagerProtocol {
    
    // MARK: - Properties
    
    /// The main app service instance for managing login items
    private var appService: SMAppService {
        return SMAppService.mainApp
    }
    
    // MARK: - Initialization
    
    /// Creates a new LaunchAgentManager instance
    init() {}
    
    // MARK: - LaunchAgentManagerProtocol Implementation
    
    func enableLaunchAtLogin() throws {
        do {
            try appService.register()
        } catch {
            throw SMBMounterError.launchAgentRegistrationFailed(
                reason: mapServiceError(error)
            )
        }
    }
    
    func disableLaunchAtLogin() throws {
        do {
            try appService.unregister()
        } catch {
            // If the app is not registered, unregister will fail
            // Check if it's already disabled and treat that as success
            if appService.status == .notRegistered || appService.status == .notFound {
                return
            }
            
            throw SMBMounterError.launchAgentUnregistrationFailed(
                reason: mapServiceError(error)
            )
        }
    }
    
    func isLaunchAtLoginEnabled() -> Bool {
        let status = appService.status
        return status == .enabled
    }
    
    // MARK: - Private Helpers
    
    /// Maps SMAppService errors to human-readable descriptions
    /// - Parameter error: The error from SMAppService
    /// - Returns: A human-readable error description
    private func mapServiceError(_ error: Error) -> String {
        // Check for specific SMAppService error codes
        let nsError = error as NSError
        
        switch nsError.code {
        case 1:
            return "The application is not properly signed or notarized"
        case 2:
            return "The login item is already registered"
        case 3:
            return "The login item was not found"
        case 4:
            return "The operation requires user approval in System Settings"
        default:
            return error.localizedDescription
        }
    }
}

// MARK: - LaunchAgentManager Extension for Status Details

@available(macOS 13.0, *)
extension LaunchAgentManager {
    
    /// Returns the current status of the login item
    /// - Returns: The SMAppService.Status value
    var currentStatus: SMAppService.Status {
        return appService.status
    }
    
    /// Returns a human-readable description of the current status
    /// - Returns: A string describing the current login item status
    var statusDescription: String {
        switch appService.status {
        case .notRegistered:
            return NSLocalizedString(
                "Launch at login is not configured",
                comment: "Login item status"
            )
        case .enabled:
            return NSLocalizedString(
                "Launch at login is enabled",
                comment: "Login item status"
            )
        case .requiresApproval:
            return NSLocalizedString(
                "Launch at login requires approval in System Settings",
                comment: "Login item status"
            )
        case .notFound:
            return NSLocalizedString(
                "Login item configuration not found",
                comment: "Login item status"
            )
        @unknown default:
            return NSLocalizedString(
                "Unknown login item status",
                comment: "Login item status"
            )
        }
    }
    
    /// Checks if the login item requires user approval
    /// - Returns: `true` if the user needs to approve the login item in System Settings
    var requiresApproval: Bool {
        return appService.status == .requiresApproval
    }
    
    /// Opens System Settings to the Login Items section
    /// This allows users to manually enable/disable the login item
    func openLoginItemsSettings() {
        #if canImport(AppKit)
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}

// MARK: - Legacy LaunchAgentManager for macOS 12

/// Legacy implementation for macOS 12 (Monterey) using LSSharedFileList
/// Note: This is a fallback for older systems; SMAppService is preferred for macOS 13+
final class LegacyLaunchAgentManager: LaunchAgentManagerProtocol {
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - LaunchAgentManagerProtocol Implementation
    
    func enableLaunchAtLogin() throws {
        // On macOS 12, we use the older SMLoginItemSetEnabled API
        // However, this requires a helper app bundle structure
        // For simplicity, we'll indicate this feature requires macOS 13+
        throw SMBMounterError.launchAgentRegistrationFailed(
            reason: "Launch at login requires macOS 13.0 or later. Please upgrade your system or manually add the app to Login Items in System Preferences."
        )
    }
    
    func disableLaunchAtLogin() throws {
        throw SMBMounterError.launchAgentUnregistrationFailed(
            reason: "Launch at login requires macOS 13.0 or later."
        )
    }
    
    func isLaunchAtLoginEnabled() -> Bool {
        // Cannot determine status on older systems
        return false
    }
}

// MARK: - Factory Function

/// Creates the appropriate LaunchAgentManager based on the current macOS version
/// - Returns: A LaunchAgentManagerProtocol implementation suitable for the current system
func createLaunchAgentManager() -> LaunchAgentManagerProtocol {
    if #available(macOS 13.0, *) {
        return LaunchAgentManager()
    } else {
        return LegacyLaunchAgentManager()
    }
}
