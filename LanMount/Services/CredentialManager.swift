//
//  CredentialManager.swift
//  LanMount
//
//  Manages secure storage and retrieval of SMB credentials using macOS Keychain
//  Requirements: 4.2, 4.3, 4.4, 4.5
//

import Foundation
import Security

// MARK: - CredentialManagerProtocol

/// Protocol defining the interface for credential management operations
/// Uses macOS Keychain for secure storage of SMB authentication credentials
protocol CredentialManagerProtocol {
    /// Saves credentials to the Keychain for a specific SMB share
    /// - Parameters:
    ///   - server: The SMB server address (hostname or IP)
    ///   - share: The name of the shared folder
    ///   - username: The username for authentication
    ///   - password: The password for authentication
    /// - Throws: `SMBMounterError` if the save operation fails
    func saveCredentials(
        server: String,
        share: String,
        username: String,
        password: String
    ) throws
    
    /// Retrieves credentials from the Keychain for a specific SMB share
    /// - Parameters:
    ///   - server: The SMB server address (hostname or IP)
    ///   - share: The name of the shared folder
    /// - Returns: The stored credentials, or nil if not found
    /// - Throws: `SMBMounterError` if the retrieval operation fails (except for not found)
    func getCredentials(
        server: String,
        share: String
    ) throws -> Credentials?
    
    /// Updates existing credentials in the Keychain for a specific SMB share
    /// - Parameters:
    ///   - server: The SMB server address (hostname or IP)
    ///   - share: The name of the shared folder
    ///   - username: The new username for authentication
    ///   - password: The new password for authentication
    /// - Throws: `SMBMounterError` if the update operation fails
    func updateCredentials(
        server: String,
        share: String,
        username: String,
        password: String
    ) throws
    
    /// Deletes credentials from the Keychain for a specific SMB share
    /// - Parameters:
    ///   - server: The SMB server address (hostname or IP)
    ///   - share: The name of the shared folder
    /// - Throws: `SMBMounterError` if the delete operation fails
    func deleteCredentials(
        server: String,
        share: String
    ) throws
}

// MARK: - CredentialManager

/// Implementation of CredentialManagerProtocol using macOS Keychain Services
/// Stores credentials as Internet Password items with SMB protocol type
final class CredentialManager: CredentialManagerProtocol {
    
    // MARK: - Constants
    
    /// Service name prefix for Keychain items
    private static let servicePrefix = "com.lanmount.smb"
    
    // MARK: - Initialization
    
    /// Creates a new CredentialManager instance
    init() {}
    
    // MARK: - CredentialManagerProtocol Implementation
    
    func saveCredentials(
        server: String,
        share: String,
        username: String,
        password: String
    ) throws {
        // Validate inputs
        guard !server.isEmpty else {
            throw SMBMounterError.invalidInput(parameter: "server", reason: "Server address cannot be empty")
        }
        guard !share.isEmpty else {
            throw SMBMounterError.invalidInput(parameter: "share", reason: "Share name cannot be empty")
        }
        guard !username.isEmpty else {
            throw SMBMounterError.invalidInput(parameter: "username", reason: "Username cannot be empty")
        }
        
        // Convert password to data
        guard let passwordData = password.data(using: .utf8) else {
            throw SMBMounterError.keychainSaveFailed(reason: "Failed to encode password")
        }
        
        // Build the query dictionary for SecItemAdd
        // Using kSecClassInternetPassword with kSecAttrProtocolSMB as specified in design
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server.lowercased(),
            kSecAttrPath as String: "/\(share)",
            kSecAttrAccount as String: username,
            kSecAttrProtocol as String: kSecAttrProtocolSMB,
            kSecAttrPort as String: 445,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrLabel as String: "\(Self.servicePrefix).\(server).\(share)",
            kSecAttrComment as String: "SMB credentials for \(server)/\(share)"
        ]
        
        // Attempt to add the item to Keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess:
            return // Successfully saved
            
        case errSecDuplicateItem:
            // Item already exists, try to update instead
            try updateCredentials(server: server, share: share, username: username, password: password)
            
        case errSecAuthFailed, errSecInteractionNotAllowed:
            throw SMBMounterError.keychainAccessDenied
            
        default:
            throw SMBMounterError.keychainSaveFailed(reason: "Keychain error: \(status)")
        }
    }
    
    func getCredentials(
        server: String,
        share: String
    ) throws -> Credentials? {
        // Validate inputs
        guard !server.isEmpty else {
            throw SMBMounterError.invalidInput(parameter: "server", reason: "Server address cannot be empty")
        }
        guard !share.isEmpty else {
            throw SMBMounterError.invalidInput(parameter: "share", reason: "Share name cannot be empty")
        }
        
        // Build the query dictionary for SecItemCopyMatching
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server.lowercased(),
            kSecAttrPath as String: "/\(share)",
            kSecAttrProtocol as String: kSecAttrProtocolSMB,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            // Parse the result
            guard let item = result as? [String: Any],
                  let username = item[kSecAttrAccount as String] as? String,
                  let passwordData = item[kSecValueData as String] as? Data,
                  let password = String(data: passwordData, encoding: .utf8) else {
                throw SMBMounterError.keychainError(status: errSecDecode)
            }
            
            return Credentials(username: username, password: password, domain: nil)
            
        case errSecItemNotFound:
            // Item not found is not an error, just return nil
            return nil
            
        case errSecAuthFailed, errSecInteractionNotAllowed:
            throw SMBMounterError.keychainAccessDenied
            
        default:
            throw SMBMounterError.keychainError(status: status)
        }
    }
    
    func updateCredentials(
        server: String,
        share: String,
        username: String,
        password: String
    ) throws {
        // Validate inputs
        guard !server.isEmpty else {
            throw SMBMounterError.invalidInput(parameter: "server", reason: "Server address cannot be empty")
        }
        guard !share.isEmpty else {
            throw SMBMounterError.invalidInput(parameter: "share", reason: "Share name cannot be empty")
        }
        guard !username.isEmpty else {
            throw SMBMounterError.invalidInput(parameter: "username", reason: "Username cannot be empty")
        }
        
        // Convert password to data
        guard let passwordData = password.data(using: .utf8) else {
            throw SMBMounterError.keychainUpdateFailed(reason: "Failed to encode password")
        }
        
        // Build the query dictionary to find the existing item
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server.lowercased(),
            kSecAttrPath as String: "/\(share)",
            kSecAttrProtocol as String: kSecAttrProtocolSMB
        ]
        
        // Build the attributes to update
        let attributesToUpdate: [String: Any] = [
            kSecAttrAccount as String: username,
            kSecValueData as String: passwordData
        ]
        
        // Attempt to update the item in Keychain
        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        
        switch status {
        case errSecSuccess:
            return // Successfully updated
            
        case errSecItemNotFound:
            // Item doesn't exist, create it instead
            try saveCredentialsDirectly(server: server, share: share, username: username, password: password)
            
        case errSecAuthFailed, errSecInteractionNotAllowed:
            throw SMBMounterError.keychainAccessDenied
            
        default:
            throw SMBMounterError.keychainUpdateFailed(reason: "Keychain error: \(status)")
        }
    }
    
    func deleteCredentials(
        server: String,
        share: String
    ) throws {
        // Validate inputs
        guard !server.isEmpty else {
            throw SMBMounterError.invalidInput(parameter: "server", reason: "Server address cannot be empty")
        }
        guard !share.isEmpty else {
            throw SMBMounterError.invalidInput(parameter: "share", reason: "Share name cannot be empty")
        }
        
        // Build the query dictionary to find the item to delete
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server.lowercased(),
            kSecAttrPath as String: "/\(share)",
            kSecAttrProtocol as String: kSecAttrProtocolSMB
        ]
        
        // Attempt to delete the item from Keychain
        let status = SecItemDelete(query as CFDictionary)
        
        switch status {
        case errSecSuccess:
            return // Successfully deleted
            
        case errSecItemNotFound:
            // Item doesn't exist, nothing to delete - this is not an error
            return
            
        case errSecAuthFailed, errSecInteractionNotAllowed:
            throw SMBMounterError.keychainAccessDenied
            
        default:
            throw SMBMounterError.keychainDeleteFailed(reason: "Keychain error: \(status)")
        }
    }
    
    // MARK: - Private Helpers
    
    /// Saves credentials directly without checking for duplicates
    /// Used internally when we know the item doesn't exist
    private func saveCredentialsDirectly(
        server: String,
        share: String,
        username: String,
        password: String
    ) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw SMBMounterError.keychainSaveFailed(reason: "Failed to encode password")
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server.lowercased(),
            kSecAttrPath as String: "/\(share)",
            kSecAttrAccount as String: username,
            kSecAttrProtocol as String: kSecAttrProtocolSMB,
            kSecAttrPort as String: 445,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrLabel as String: "\(Self.servicePrefix).\(server).\(share)",
            kSecAttrComment as String: "SMB credentials for \(server)/\(share)"
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess:
            return
            
        case errSecAuthFailed, errSecInteractionNotAllowed:
            throw SMBMounterError.keychainAccessDenied
            
        default:
            throw SMBMounterError.keychainSaveFailed(reason: "Keychain error: \(status)")
        }
    }
}

// MARK: - CredentialManager Extension for Testing

extension CredentialManager {
    /// Checks if credentials exist for a specific SMB share without retrieving them
    /// - Parameters:
    ///   - server: The SMB server address (hostname or IP)
    ///   - share: The name of the shared folder
    /// - Returns: true if credentials exist, false otherwise
    func hasCredentials(server: String, share: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server.lowercased(),
            kSecAttrPath as String: "/\(share)",
            kSecAttrProtocol as String: kSecAttrProtocolSMB,
            kSecReturnAttributes as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Deletes all credentials stored by this application
    /// WARNING: This is primarily for testing purposes
    func deleteAllCredentials() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrProtocol as String: kSecAttrProtocolSMB
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
            
        case errSecAuthFailed, errSecInteractionNotAllowed:
            throw SMBMounterError.keychainAccessDenied
            
        default:
            throw SMBMounterError.keychainDeleteFailed(reason: "Keychain error: \(status)")
        }
    }
}
