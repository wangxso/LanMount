//
//  ConfigurationStore.swift
//  LanMount
//
//  Manages persistent storage of mount configurations and application settings
//  Requirements: 6.1, 6.2, 6.3, 6.4, 6.5
//

import Foundation

// MARK: - ConfigurationStoreProtocol

/// Protocol defining the interface for configuration storage operations
/// Uses JSON format for persistent storage of mount configurations and app settings
protocol ConfigurationStoreProtocol {
    /// Saves a mount configuration to persistent storage
    /// - Parameter config: The mount configuration to save
    /// - Throws: `SMBMounterError` if the save operation fails
    func saveMountConfig(_ config: MountConfiguration) throws
    
    /// Retrieves all saved mount configurations
    /// - Returns: Array of all stored mount configurations
    /// - Throws: `SMBMounterError` if the read operation fails
    func getAllMountConfigs() throws -> [MountConfiguration]
    
    /// Deletes a mount configuration by its ID
    /// - Parameter id: The unique identifier of the configuration to delete
    /// - Throws: `SMBMounterError` if the delete operation fails
    func deleteMountConfig(id: UUID) throws
    
    /// Updates an existing mount configuration
    /// - Parameter config: The updated mount configuration
    /// - Throws: `SMBMounterError` if the update operation fails
    func updateMountConfig(_ config: MountConfiguration) throws
    
    /// Retrieves the application settings
    /// - Returns: The current application settings, or default settings if none exist
    func getAppSettings() -> AppSettings
    
    /// Saves the application settings
    /// - Parameter settings: The settings to save
    /// - Throws: `SMBMounterError` if the save operation fails
    func saveAppSettings(_ settings: AppSettings) throws
}

// MARK: - ConfigurationStore

/// Implementation of ConfigurationStoreProtocol using JSON file storage
/// Stores configurations in ~/Library/Application Support/SMBMounter/config.json
/// File permissions are set to 0600 (user read/write only) for security
final class ConfigurationStore: ConfigurationStoreProtocol {
    
    // MARK: - Types
    
    /// Container structure for all persisted data
    private struct ConfigurationData: Codable {
        var mountConfigs: [MountConfiguration]
        var appSettings: AppSettings
        
        static let empty = ConfigurationData(
            mountConfigs: [],
            appSettings: .default
        )
    }
    
    // MARK: - Constants
    
    /// Application support directory name
    private static let appDirectoryName = "SMBMounter"
    
    /// Configuration file name
    private static let configFileName = "config.json"
    
    /// File permissions: owner read/write only (0600)
    private static let filePermissions: Int16 = 0o600
    
    // MARK: - Properties
    
    /// File manager for file system operations
    private let fileManager: FileManager
    
    /// JSON encoder configured for pretty printing
    private let encoder: JSONEncoder
    
    /// JSON decoder
    private let decoder: JSONDecoder
    
    /// Cached configuration data
    private var cachedData: ConfigurationData?
    
    /// Lock for thread-safe access
    private let lock = NSLock()
    
    // MARK: - Computed Properties
    
    /// Path to the application support directory
    private var appSupportDirectory: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(Self.appDirectoryName)
    }
    
    /// Path to the configuration file
    private var configFilePath: URL {
        return appSupportDirectory.appendingPathComponent(Self.configFileName)
    }
    
    // MARK: - Initialization
    
    /// Creates a new ConfigurationStore instance
    /// - Parameter fileManager: The file manager to use (defaults to FileManager.default)
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        // Configure JSON encoder for readable output
        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        // Configure JSON decoder
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - ConfigurationStoreProtocol Implementation
    
    func saveMountConfig(_ config: MountConfiguration) throws {
        lock.lock()
        defer { lock.unlock() }
        
        var data = try loadConfigurationData()
        
        // Check if config with same ID already exists
        if let index = data.mountConfigs.firstIndex(where: { $0.id == config.id }) {
            // Update existing config
            data.mountConfigs[index] = config
        } else {
            // Add new config
            data.mountConfigs.append(config)
        }
        
        try saveConfigurationData(data)
    }
    
    func getAllMountConfigs() throws -> [MountConfiguration] {
        lock.lock()
        defer { lock.unlock() }
        
        let data = try loadConfigurationData()
        return data.mountConfigs
    }
    
    func deleteMountConfig(id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        
        var data = try loadConfigurationData()
        data.mountConfigs.removeAll { $0.id == id }
        try saveConfigurationData(data)
    }
    
    func updateMountConfig(_ config: MountConfiguration) throws {
        lock.lock()
        defer { lock.unlock() }
        
        var data = try loadConfigurationData()
        
        guard let index = data.mountConfigs.firstIndex(where: { $0.id == config.id }) else {
            throw SMBMounterError.invalidConfiguration(reason: "Configuration with ID \(config.id) not found")
        }
        
        // Update the configuration with new lastModified timestamp
        var updatedConfig = config
        updatedConfig.lastModified = Date()
        data.mountConfigs[index] = updatedConfig
        
        try saveConfigurationData(data)
    }
    
    func getAppSettings() -> AppSettings {
        lock.lock()
        defer { lock.unlock() }
        
        do {
            let data = try loadConfigurationData()
            return data.appSettings
        } catch {
            // Return default settings if loading fails
            return .default
        }
    }
    
    func saveAppSettings(_ settings: AppSettings) throws {
        lock.lock()
        defer { lock.unlock() }
        
        var data = try loadConfigurationData()
        data.appSettings = settings
        try saveConfigurationData(data)
    }
    
    // MARK: - Private Methods
    
    /// Ensures the application support directory exists
    /// - Throws: `SMBMounterError` if directory creation fails
    private func ensureDirectoryExists() throws {
        let directoryPath = appSupportDirectory.path
        
        if !fileManager.fileExists(atPath: directoryPath) {
            do {
                try fileManager.createDirectory(
                    at: appSupportDirectory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
            } catch {
                throw SMBMounterError.configurationDirectoryCreationFailed(path: directoryPath)
            }
        }
    }
    
    /// Loads configuration data from the file
    /// - Returns: The loaded configuration data, or empty data if file doesn't exist
    /// - Throws: `SMBMounterError` if reading or parsing fails
    private func loadConfigurationData() throws -> ConfigurationData {
        // Return cached data if available
        if let cached = cachedData {
            return cached
        }
        
        let filePath = configFilePath.path
        
        // If file doesn't exist, return empty configuration
        guard fileManager.fileExists(atPath: filePath) else {
            let emptyData = ConfigurationData.empty
            cachedData = emptyData
            return emptyData
        }
        
        // Read file data
        guard let fileData = fileManager.contents(atPath: filePath) else {
            throw SMBMounterError.configurationReadFailed(path: filePath)
        }
        
        // Parse JSON
        do {
            let data = try decoder.decode(ConfigurationData.self, from: fileData)
            cachedData = data
            return data
        } catch {
            throw SMBMounterError.invalidConfiguration(reason: "Failed to parse configuration: \(error.localizedDescription)")
        }
    }
    
    /// Saves configuration data to the file atomically
    /// - Parameter data: The configuration data to save
    /// - Throws: `SMBMounterError` if writing fails
    private func saveConfigurationData(_ data: ConfigurationData) throws {
        // Ensure directory exists
        try ensureDirectoryExists()
        
        // Encode to JSON
        let jsonData: Data
        do {
            jsonData = try encoder.encode(data)
        } catch {
            throw SMBMounterError.configurationWriteFailed(path: configFilePath.path)
        }
        
        // Write atomically to a temporary file first
        let tempURL = appSupportDirectory.appendingPathComponent("config.tmp.json")
        let finalURL = configFilePath
        
        do {
            // Write to temporary file
            try jsonData.write(to: tempURL, options: [.atomic])
            
            // Set file permissions to 0600 (owner read/write only)
            try setFilePermissions(at: tempURL)
            
            // Remove existing file if it exists
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            
            // Move temporary file to final location (atomic operation)
            try fileManager.moveItem(at: tempURL, to: finalURL)
            
            // Update cache
            cachedData = data
            
        } catch let error as SMBMounterError {
            // Clean up temp file if it exists
            try? fileManager.removeItem(at: tempURL)
            throw error
        } catch {
            // Clean up temp file if it exists
            try? fileManager.removeItem(at: tempURL)
            throw SMBMounterError.configurationWriteFailed(path: finalURL.path)
        }
    }
    
    /// Sets file permissions to 0600 (owner read/write only)
    /// - Parameter url: The file URL to set permissions on
    /// - Throws: Error if setting permissions fails
    private func setFilePermissions(at url: URL) throws {
        let attributes: [FileAttributeKey: Any] = [
            .posixPermissions: Self.filePermissions
        ]
        try fileManager.setAttributes(attributes, ofItemAtPath: url.path)
    }
}

// MARK: - ConfigurationStore Extension for Testing

extension ConfigurationStore {
    /// Returns the path to the configuration file (for testing/debugging)
    var configurationFilePath: String {
        return configFilePath.path
    }
    
    /// Clears the in-memory cache (for testing)
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cachedData = nil
    }
    
    /// Deletes all configuration data (for testing)
    /// WARNING: This permanently deletes all saved configurations
    func deleteAllConfigurations() throws {
        lock.lock()
        defer { lock.unlock() }
        
        let filePath = configFilePath.path
        
        if fileManager.fileExists(atPath: filePath) {
            do {
                try fileManager.removeItem(atPath: filePath)
            } catch {
                throw SMBMounterError.configurationWriteFailed(path: filePath)
            }
        }
        
        cachedData = nil
    }
    
    /// Checks if the configuration file exists
    func configurationFileExists() -> Bool {
        return fileManager.fileExists(atPath: configFilePath.path)
    }
    
    /// Gets the file permissions of the configuration file
    /// - Returns: The POSIX permissions as an integer, or nil if file doesn't exist
    func getConfigurationFilePermissions() -> Int? {
        guard fileManager.fileExists(atPath: configFilePath.path) else {
            return nil
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: configFilePath.path)
            return attributes[.posixPermissions] as? Int
        } catch {
            return nil
        }
    }
    
    /// Gets a mount configuration by ID
    /// - Parameter id: The unique identifier of the configuration
    /// - Returns: The configuration if found, nil otherwise
    func getMountConfig(id: UUID) throws -> MountConfiguration? {
        let configs = try getAllMountConfigs()
        return configs.first { $0.id == id }
    }
    
    /// Gets mount configurations that are marked for auto-mount
    /// - Returns: Array of configurations with autoMount enabled
    func getAutoMountConfigs() throws -> [MountConfiguration] {
        let configs = try getAllMountConfigs()
        return configs.filter { $0.autoMount }
    }
    
    /// Gets mount configurations for a specific server
    /// - Parameter server: The server address to filter by
    /// - Returns: Array of configurations for the specified server
    func getMountConfigs(forServer server: String) throws -> [MountConfiguration] {
        let configs = try getAllMountConfigs()
        return configs.filter { $0.server.lowercased() == server.lowercased() }
    }
}
