//
//  SMBMounterError.swift
//  LanMount
//
//  Error types for the SMB Mounter application
//  Requirements: 12.1, 12.2, 12.3, 12.4, 12.5
//

import Foundation

/// Comprehensive error type for all SMB Mounter operations
enum SMBMounterError: Error, Equatable, LocalizedError {
    
    // MARK: - Mount Errors
    
    /// Network is unreachable or server cannot be contacted
    case networkUnreachable(server: String)
    
    /// Authentication failed due to invalid credentials
    case authenticationFailed(server: String, share: String)
    
    /// The specified mount point already exists
    case mountPointExists(path: String)
    
    /// Failed to create the mount point directory
    case mountPointCreationFailed(path: String)
    
    /// Permission denied for the requested operation
    case permissionDenied(operation: String)
    
    /// The provided URL is invalid or malformed
    case invalidURL(url: String)
    
    /// Generic mount operation failure
    case mountOperationFailed(reason: String)
    
    /// The share does not exist on the server
    case shareNotFound(server: String, share: String)
    
    /// Mount operation timed out
    case mountTimeout(server: String)
    
    /// The mount point is not currently mounted
    case notMounted(mountPoint: String)
    
    /// Failed to unmount the volume
    case unmountFailed(mountPoint: String, reason: String)
    
    // MARK: - Keychain/Credential Errors
    
    /// Access to the Keychain was denied
    case keychainAccessDenied
    
    /// The requested item was not found in the Keychain
    case keychainItemNotFound(identifier: String)
    
    /// Failed to save credentials to the Keychain
    case keychainSaveFailed(reason: String)
    
    /// Failed to update credentials in the Keychain
    case keychainUpdateFailed(reason: String)
    
    /// Failed to delete credentials from the Keychain
    case keychainDeleteFailed(reason: String)
    
    /// Keychain operation failed with a system error
    case keychainError(status: Int32)
    
    // MARK: - Configuration Errors
    
    /// Failed to read the configuration file
    case configurationReadFailed(path: String)
    
    /// Failed to write the configuration file
    case configurationWriteFailed(path: String)
    
    /// The configuration is invalid or corrupted
    case invalidConfiguration(reason: String)
    
    /// Configuration file not found
    case configurationNotFound(path: String)
    
    /// Failed to create configuration directory
    case configurationDirectoryCreationFailed(path: String)
    
    // MARK: - Network Scanner Errors
    
    /// Failed to initialize the network scanner
    case scannerInitializationFailed
    
    /// Network scan timed out
    case scanTimeout
    
    /// Failed to resolve service endpoint
    case serviceResolutionFailed(serviceName: String)
    
    /// Network interface not available
    case networkInterfaceUnavailable
    
    // MARK: - Sync Errors
    
    /// A synchronization conflict occurred
    case syncConflict(filePath: String)
    
    /// Synchronization operation failed
    case syncFailed(reason: String)
    
    /// File monitoring failed
    case fileMonitoringFailed(path: String)
    
    /// Failed to read file for synchronization
    case syncReadFailed(filePath: String)
    
    /// Failed to write file during synchronization
    case syncWriteFailed(filePath: String)
    
    // MARK: - Volume Monitor Errors
    
    /// Failed to start volume monitoring
    case volumeMonitoringFailed(reason: String)
    
    /// Volume status check failed
    case volumeStatusCheckFailed(mountPoint: String)
    
    // MARK: - Launch Agent Errors
    
    /// Failed to register launch agent
    case launchAgentRegistrationFailed(reason: String)
    
    /// Failed to unregister launch agent
    case launchAgentUnregistrationFailed(reason: String)
    
    // MARK: - General Errors
    
    /// An unknown error occurred
    case unknown(message: String)
    
    /// Operation was cancelled
    case cancelled
    
    /// Invalid input parameter
    case invalidInput(parameter: String, reason: String)
    
    // MARK: - LocalizedError Implementation
    
    var errorDescription: String? {
        switch self {
        // Mount Errors
        case .networkUnreachable(let server):
            return String(format: NSLocalizedString(
                "Cannot connect to server '%@'. Please check your network connection and verify the server address.",
                comment: "Network unreachable error"
            ), server)
            
        case .authenticationFailed(let server, let share):
            return String(format: NSLocalizedString(
                "Authentication failed for '%@/%@'. Please check your username and password.",
                comment: "Authentication failed error"
            ), server, share)
            
        case .mountPointExists(let path):
            return String(format: NSLocalizedString(
                "Mount point '%@' already exists. Please choose a different location or unmount the existing volume.",
                comment: "Mount point exists error"
            ), path)
            
        case .mountPointCreationFailed(let path):
            return String(format: NSLocalizedString(
                "Failed to create mount point at '%@'. Please check permissions.",
                comment: "Mount point creation failed error"
            ), path)
            
        case .permissionDenied(let operation):
            return String(format: NSLocalizedString(
                "Permission denied for operation: %@. Please check your access rights.",
                comment: "Permission denied error"
            ), operation)
            
        case .invalidURL(let url):
            return String(format: NSLocalizedString(
                "Invalid SMB URL: '%@'. Please use the format smb://server/share.",
                comment: "Invalid URL error"
            ), url)
            
        case .mountOperationFailed(let reason):
            return String(format: NSLocalizedString(
                "Mount operation failed: %@",
                comment: "Mount operation failed error"
            ), reason)
            
        case .shareNotFound(let server, let share):
            return String(format: NSLocalizedString(
                "Share '%@' not found on server '%@'. Please verify the share name.",
                comment: "Share not found error"
            ), share, server)
            
        case .mountTimeout(let server):
            return String(format: NSLocalizedString(
                "Connection to '%@' timed out. The server may be slow or unreachable.",
                comment: "Mount timeout error"
            ), server)
            
        case .notMounted(let mountPoint):
            return String(format: NSLocalizedString(
                "The volume at '%@' is not currently mounted.",
                comment: "Not mounted error"
            ), mountPoint)
            
        case .unmountFailed(let mountPoint, let reason):
            return String(format: NSLocalizedString(
                "Failed to unmount '%@': %@",
                comment: "Unmount failed error"
            ), mountPoint, reason)
            
        // Keychain Errors
        case .keychainAccessDenied:
            return NSLocalizedString(
                "Access to the Keychain was denied. Please check your security settings.",
                comment: "Keychain access denied error"
            )
            
        case .keychainItemNotFound(let identifier):
            return String(format: NSLocalizedString(
                "Credentials for '%@' not found in Keychain.",
                comment: "Keychain item not found error"
            ), identifier)
            
        case .keychainSaveFailed(let reason):
            return String(format: NSLocalizedString(
                "Failed to save credentials to Keychain: %@",
                comment: "Keychain save failed error"
            ), reason)
            
        case .keychainUpdateFailed(let reason):
            return String(format: NSLocalizedString(
                "Failed to update credentials in Keychain: %@",
                comment: "Keychain update failed error"
            ), reason)
            
        case .keychainDeleteFailed(let reason):
            return String(format: NSLocalizedString(
                "Failed to delete credentials from Keychain: %@",
                comment: "Keychain delete failed error"
            ), reason)
            
        case .keychainError(let status):
            return String(format: NSLocalizedString(
                "Keychain error occurred (status: %d).",
                comment: "Keychain error"
            ), status)
            
        // Configuration Errors
        case .configurationReadFailed(let path):
            return String(format: NSLocalizedString(
                "Failed to read configuration from '%@'.",
                comment: "Configuration read failed error"
            ), path)
            
        case .configurationWriteFailed(let path):
            return String(format: NSLocalizedString(
                "Failed to write configuration to '%@'.",
                comment: "Configuration write failed error"
            ), path)
            
        case .invalidConfiguration(let reason):
            return String(format: NSLocalizedString(
                "Invalid configuration: %@",
                comment: "Invalid configuration error"
            ), reason)
            
        case .configurationNotFound(let path):
            return String(format: NSLocalizedString(
                "Configuration file not found at '%@'.",
                comment: "Configuration not found error"
            ), path)
            
        case .configurationDirectoryCreationFailed(let path):
            return String(format: NSLocalizedString(
                "Failed to create configuration directory at '%@'.",
                comment: "Configuration directory creation failed error"
            ), path)
            
        // Network Scanner Errors
        case .scannerInitializationFailed:
            return NSLocalizedString(
                "Failed to initialize network scanner. Please check network permissions.",
                comment: "Scanner initialization failed error"
            )
            
        case .scanTimeout:
            return NSLocalizedString(
                "Network scan timed out. No SMB services were found within the time limit.",
                comment: "Scan timeout error"
            )
            
        case .serviceResolutionFailed(let serviceName):
            return String(format: NSLocalizedString(
                "Failed to resolve service '%@'.",
                comment: "Service resolution failed error"
            ), serviceName)
            
        case .networkInterfaceUnavailable:
            return NSLocalizedString(
                "No network interface available. Please check your network connection.",
                comment: "Network interface unavailable error"
            )
            
        // Sync Errors
        case .syncConflict(let filePath):
            return String(format: NSLocalizedString(
                "Synchronization conflict detected for '%@'. Please resolve the conflict.",
                comment: "Sync conflict error"
            ), filePath)
            
        case .syncFailed(let reason):
            return String(format: NSLocalizedString(
                "Synchronization failed: %@",
                comment: "Sync failed error"
            ), reason)
            
        case .fileMonitoringFailed(let path):
            return String(format: NSLocalizedString(
                "Failed to monitor file changes at '%@'.",
                comment: "File monitoring failed error"
            ), path)
            
        case .syncReadFailed(let filePath):
            return String(format: NSLocalizedString(
                "Failed to read file '%@' for synchronization.",
                comment: "Sync read failed error"
            ), filePath)
            
        case .syncWriteFailed(let filePath):
            return String(format: NSLocalizedString(
                "Failed to write file '%@' during synchronization.",
                comment: "Sync write failed error"
            ), filePath)
            
        // Volume Monitor Errors
        case .volumeMonitoringFailed(let reason):
            return String(format: NSLocalizedString(
                "Volume monitoring failed: %@",
                comment: "Volume monitoring failed error"
            ), reason)
            
        case .volumeStatusCheckFailed(let mountPoint):
            return String(format: NSLocalizedString(
                "Failed to check status of volume at '%@'.",
                comment: "Volume status check failed error"
            ), mountPoint)
            
        // Launch Agent Errors
        case .launchAgentRegistrationFailed(let reason):
            return String(format: NSLocalizedString(
                "Failed to enable launch at login: %@",
                comment: "Launch agent registration failed error"
            ), reason)
            
        case .launchAgentUnregistrationFailed(let reason):
            return String(format: NSLocalizedString(
                "Failed to disable launch at login: %@",
                comment: "Launch agent unregistration failed error"
            ), reason)
            
        // General Errors
        case .unknown(let message):
            return String(format: NSLocalizedString(
                "An unknown error occurred: %@",
                comment: "Unknown error"
            ), message)
            
        case .cancelled:
            return NSLocalizedString(
                "The operation was cancelled.",
                comment: "Operation cancelled error"
            )
            
        case .invalidInput(let parameter, let reason):
            return String(format: NSLocalizedString(
                "Invalid input for '%@': %@",
                comment: "Invalid input error"
            ), parameter, reason)
        }
    }
    
    /// A brief title for the error suitable for alert dialogs
    var failureReason: String? {
        switch self {
        case .networkUnreachable:
            return NSLocalizedString("Network Unreachable", comment: "Error title")
        case .authenticationFailed:
            return NSLocalizedString("Authentication Failed", comment: "Error title")
        case .mountPointExists:
            return NSLocalizedString("Mount Point Exists", comment: "Error title")
        case .mountPointCreationFailed:
            return NSLocalizedString("Mount Point Creation Failed", comment: "Error title")
        case .permissionDenied:
            return NSLocalizedString("Permission Denied", comment: "Error title")
        case .invalidURL:
            return NSLocalizedString("Invalid URL", comment: "Error title")
        case .mountOperationFailed:
            return NSLocalizedString("Mount Failed", comment: "Error title")
        case .shareNotFound:
            return NSLocalizedString("Share Not Found", comment: "Error title")
        case .mountTimeout:
            return NSLocalizedString("Connection Timeout", comment: "Error title")
        case .notMounted:
            return NSLocalizedString("Not Mounted", comment: "Error title")
        case .unmountFailed:
            return NSLocalizedString("Unmount Failed", comment: "Error title")
        case .keychainAccessDenied:
            return NSLocalizedString("Keychain Access Denied", comment: "Error title")
        case .keychainItemNotFound:
            return NSLocalizedString("Credentials Not Found", comment: "Error title")
        case .keychainSaveFailed:
            return NSLocalizedString("Save Credentials Failed", comment: "Error title")
        case .keychainUpdateFailed:
            return NSLocalizedString("Update Credentials Failed", comment: "Error title")
        case .keychainDeleteFailed:
            return NSLocalizedString("Delete Credentials Failed", comment: "Error title")
        case .keychainError:
            return NSLocalizedString("Keychain Error", comment: "Error title")
        case .configurationReadFailed:
            return NSLocalizedString("Configuration Read Failed", comment: "Error title")
        case .configurationWriteFailed:
            return NSLocalizedString("Configuration Write Failed", comment: "Error title")
        case .invalidConfiguration:
            return NSLocalizedString("Invalid Configuration", comment: "Error title")
        case .configurationNotFound:
            return NSLocalizedString("Configuration Not Found", comment: "Error title")
        case .configurationDirectoryCreationFailed:
            return NSLocalizedString("Directory Creation Failed", comment: "Error title")
        case .scannerInitializationFailed:
            return NSLocalizedString("Scanner Initialization Failed", comment: "Error title")
        case .scanTimeout:
            return NSLocalizedString("Scan Timeout", comment: "Error title")
        case .serviceResolutionFailed:
            return NSLocalizedString("Service Resolution Failed", comment: "Error title")
        case .networkInterfaceUnavailable:
            return NSLocalizedString("Network Unavailable", comment: "Error title")
        case .syncConflict:
            return NSLocalizedString("Sync Conflict", comment: "Error title")
        case .syncFailed:
            return NSLocalizedString("Sync Failed", comment: "Error title")
        case .fileMonitoringFailed:
            return NSLocalizedString("File Monitoring Failed", comment: "Error title")
        case .syncReadFailed:
            return NSLocalizedString("Sync Read Failed", comment: "Error title")
        case .syncWriteFailed:
            return NSLocalizedString("Sync Write Failed", comment: "Error title")
        case .volumeMonitoringFailed:
            return NSLocalizedString("Volume Monitoring Failed", comment: "Error title")
        case .volumeStatusCheckFailed:
            return NSLocalizedString("Status Check Failed", comment: "Error title")
        case .launchAgentRegistrationFailed:
            return NSLocalizedString("Launch Agent Registration Failed", comment: "Error title")
        case .launchAgentUnregistrationFailed:
            return NSLocalizedString("Launch Agent Unregistration Failed", comment: "Error title")
        case .unknown:
            return NSLocalizedString("Unknown Error", comment: "Error title")
        case .cancelled:
            return NSLocalizedString("Operation Cancelled", comment: "Error title")
        case .invalidInput:
            return NSLocalizedString("Invalid Input", comment: "Error title")
        }
    }
    
    /// Suggested recovery action for the error
    var recoverySuggestion: String? {
        switch self {
        case .networkUnreachable:
            return NSLocalizedString(
                "Check your network connection and verify the server address is correct.",
                comment: "Recovery suggestion"
            )
        case .authenticationFailed:
            return NSLocalizedString(
                "Verify your username and password are correct. If using a domain account, include the domain name.",
                comment: "Recovery suggestion"
            )
        case .mountPointExists:
            return NSLocalizedString(
                "Choose a different mount point or unmount the existing volume first.",
                comment: "Recovery suggestion"
            )
        case .keychainAccessDenied:
            return NSLocalizedString(
                "Open System Preferences > Security & Privacy and grant Keychain access to LanMount.",
                comment: "Recovery suggestion"
            )
        case .scanTimeout:
            return NSLocalizedString(
                "Try scanning again or manually enter the server address.",
                comment: "Recovery suggestion"
            )
        default:
            return nil
        }
    }
}

// MARK: - Error Conversion Helpers

extension SMBMounterError {
    /// Creates an SMBMounterError from a system error code
    static func fromOSStatus(_ status: OSStatus, context: String) -> SMBMounterError {
        switch status {
        case -25291: // errSecNotAvailable
            return .keychainAccessDenied
        case -25300: // errSecItemNotFound
            return .keychainItemNotFound(identifier: context)
        case -25299: // errSecDuplicateItem
            return .keychainSaveFailed(reason: "Item already exists")
        default:
            return .keychainError(status: status)
        }
    }
}
