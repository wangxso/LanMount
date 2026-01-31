//
//  ConnectionManagerViewModel.swift
//  LanMount
//
//  ViewModel for managing SMB mount configurations
//  Requirements: 5.1 - Display all saved SMB disk source configurations as card list
//  Requirements: 5.2 - Support drag-and-drop reordering of configurations
//  Requirements: 5.4 - Support batch selection and batch deletion
//  Requirements: 5.5 - Support export and import configurations (JSON format)
//

import Foundation
import Combine
import SwiftUI

// MARK: - ConnectionManagerTestResult

/// Result of a connection test operation for ConnectionManagerViewModel
/// Note: Named differently from ConnectionTestResult in MountConfigView to avoid conflicts
struct ConnectionManagerTestResult: Equatable {
    /// Whether the connection test succeeded
    let success: Bool
    /// The latency in milliseconds if successful
    let latencyMs: Double?
    /// Error message if the test failed
    let errorMessage: String?
    /// Timestamp when the test was performed
    let testedAt: Date
    
    /// Creates a successful connection test result
    /// - Parameter latencyMs: The measured latency in milliseconds
    /// - Returns: A successful ConnectionManagerTestResult
    static func success(latencyMs: Double) -> ConnectionManagerTestResult {
        return ConnectionManagerTestResult(
            success: true,
            latencyMs: latencyMs,
            errorMessage: nil,
            testedAt: Date()
        )
    }
    
    /// Creates a failed connection test result
    /// - Parameter error: The error message describing the failure
    /// - Returns: A failed ConnectionManagerTestResult
    static func failure(_ error: String) -> ConnectionManagerTestResult {
        return ConnectionManagerTestResult(
            success: false,
            latencyMs: nil,
            errorMessage: error,
            testedAt: Date()
        )
    }
}

// MARK: - ConnectionManagerViewModel

/// ViewModel for managing SMB mount configurations
/// Provides functionality for adding, updating, deleting, reordering, and exporting/importing configurations
/// - Note: This class is MainActor-isolated for safe UI updates
@MainActor
final class ConnectionManagerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Array of all mount configurations
    /// Requirements: 5.1 - Display all saved SMB disk source configurations
    @Published private(set) var configurations: [MountConfiguration] = []
    
    /// Dictionary mapping configuration IDs to their connection statistics
    /// Requirements: 5.7 - Display last connection time and success rate statistics
    @Published private(set) var connectionStats: [UUID: ConnectionStatistics] = [:]
    
    /// Indicates whether a loading operation is in progress
    @Published private(set) var isLoading: Bool = false
    
    /// The most recent error encountered during operations
    @Published private(set) var error: Error?
    
    // MARK: - Private Properties
    
    /// The configuration store service for persistence
    private let configurationStore: ConfigurationStoreProtocol
    
    /// The mount manager for testing connections
    private let mountManager: MountManagerProtocol?
    
    /// Set of Combine cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Creates a new ConnectionManagerViewModel
    /// - Parameters:
    ///   - configurationStore: The configuration store service for persistence
    ///   - mountManager: Optional mount manager for testing connections
    init(
        configurationStore: ConfigurationStoreProtocol,
        mountManager: MountManagerProtocol? = nil
    ) {
        self.configurationStore = configurationStore
        self.mountManager = mountManager
    }
    
    /// Convenience initializer using the default ConfigurationStore
    convenience init() {
        self.init(
            configurationStore: ConfigurationStore(),
            mountManager: MountManager()
        )
    }
    
    // MARK: - Public Methods
    
    /// Loads all configurations from the store
    func loadConfigurations() async {
        isLoading = true
        error = nil
        
        do {
            let configs = try configurationStore.getAllMountConfigs()
            configurations = configs
            
            // Initialize connection statistics for each configuration
            for config in configs {
                if connectionStats[config.id] == nil {
                    connectionStats[config.id] = ConnectionStatistics(configurationId: config.id)
                }
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    /// Adds a new configuration
    /// - Parameter config: The configuration to add
    /// - Throws: Error if the save operation fails
    /// Requirements: 5.1 - Add new configurations
    func addConfiguration(_ config: MountConfiguration) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        // Validate the configuration
        let validationErrors = config.validate()
        if !validationErrors.isEmpty {
            let combinedError = ConnectionManagerViewModelError.validationFailed(errors: validationErrors)
            self.error = combinedError
            throw combinedError
        }
        
        do {
            try configurationStore.saveMountConfig(config)
            configurations.append(config)
            
            // Initialize connection statistics for the new configuration
            connectionStats[config.id] = ConnectionStatistics(configurationId: config.id)
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Updates an existing configuration
    /// - Parameter config: The configuration to update
    /// - Throws: Error if the update operation fails
    /// Requirements: 5.1 - Update existing configurations
    func updateConfiguration(_ config: MountConfiguration) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        // Validate the configuration
        let validationErrors = config.validate()
        if !validationErrors.isEmpty {
            let combinedError = ConnectionManagerViewModelError.validationFailed(errors: validationErrors)
            self.error = combinedError
            throw combinedError
        }
        
        do {
            try configurationStore.updateMountConfig(config)
            
            // Update the configuration in the local array
            if let index = configurations.firstIndex(where: { $0.id == config.id }) {
                configurations[index] = config
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Deletes configurations by their IDs
    /// - Parameter ids: The set of configuration IDs to delete
    /// - Throws: Error if any delete operation fails
    /// Requirements: 5.4 - Support batch selection and batch deletion
    func deleteConfigurations(_ ids: Set<UUID>) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        var failedDeletions: [(UUID, Error)] = []
        
        for id in ids {
            do {
                try configurationStore.deleteMountConfig(id: id)
                
                // Remove from local array
                configurations.removeAll { $0.id == id }
                
                // Remove connection statistics
                connectionStats.removeValue(forKey: id)
            } catch {
                failedDeletions.append((id, error))
            }
        }
        
        if !failedDeletions.isEmpty {
            let batchError = ConnectionManagerViewModelError.batchDeleteFailed(
                failedIds: failedDeletions.map { $0.0 },
                errors: failedDeletions.map { $0.1 }
            )
            self.error = batchError
            throw batchError
        }
    }
    
    /// Reorders configurations by moving items from source indices to a destination index
    /// - Parameters:
    ///   - source: The source indices of items to move
    ///   - destination: The destination index
    /// Requirements: 5.2 - Support drag-and-drop reordering
    func reorderConfigurations(from source: IndexSet, to destination: Int) {
        configurations.move(fromOffsets: source, toOffset: destination)
        
        // Persist the new order by saving all configurations
        // Note: This is a simple approach; a more sophisticated implementation
        // might store order separately or use a sortOrder field
        Task {
            for config in configurations {
                try? configurationStore.updateMountConfig(config)
            }
        }
    }
    
    /// Tests the connection for a configuration
    /// - Parameter config: The configuration to test
    /// - Returns: The result of the connection test
    /// Requirements: 5.6 - Provide "test connection" functionality
    func testConnection(_ config: MountConfiguration) async -> ConnectionManagerTestResult {
        guard let mountManager = mountManager else {
            return .failure("Mount manager not available")
        }
        
        let startTime = Date()
        
        do {
            // Try to mount and immediately unmount to test the connection
            let result = try await mountManager.mount(
                server: config.server,
                share: config.share,
                mountPoint: config.mountPoint,
                credentials: nil
            )
            
            let endTime = Date()
            let latencyMs = endTime.timeIntervalSince(startTime) * 1000
            
            // Unmount immediately after successful test
            if result.success, let mountPoint = result.mountPoint {
                try? await mountManager.unmount(mountPoint: mountPoint)
            }
            
            // Update connection statistics
            updateConnectionStats(for: config.id, success: true, latencyMs: latencyMs)
            
            return .success(latencyMs: latencyMs)
        } catch {
            // Update connection statistics for failure
            updateConnectionStats(for: config.id, success: false, latencyMs: nil)
            
            return .failure(error.localizedDescription)
        }
    }
    
    /// Exports configurations to JSON data
    /// - Parameter ids: The set of configuration IDs to export
    /// - Returns: JSON data containing the exported configurations
    /// Requirements: 5.5 - Support export configurations (JSON format)
    func exportConfigurations(_ ids: Set<UUID>) -> Data {
        // Filter configurations by the provided IDs
        let configsToExport = configurations.filter { ids.contains($0.id) }
        
        // Create the export structure
        let export = ConfigurationExport(configurations: configsToExport)
        
        // Convert to JSON
        do {
            return try export.toJSON()
        } catch {
            // Return empty data if encoding fails
            self.error = ConnectionManagerViewModelError.exportFailed(underlying: error)
            return Data()
        }
    }
    
    /// Exports all configurations to JSON data
    /// - Returns: JSON data containing all configurations
    /// Requirements: 5.5 - Support export configurations (JSON format)
    func exportAllConfigurations() -> Data {
        let allIds = Set(configurations.map { $0.id })
        return exportConfigurations(allIds)
    }
    
    /// Imports configurations from JSON data
    /// - Parameter data: The JSON data to import
    /// - Returns: Array of imported configurations
    /// - Throws: Error if the import operation fails
    /// Requirements: 5.5 - Support import configurations (JSON format)
    func importConfigurations(from data: Data) async throws -> [MountConfiguration] {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            // Parse the JSON data
            let export = try ConfigurationExport.fromJSON(data)
            
            // Convert to MountConfigurations
            let importedConfigs = export.toMountConfigurations()
            
            // Save each imported configuration
            var savedConfigs: [MountConfiguration] = []
            for config in importedConfigs {
                do {
                    try configurationStore.saveMountConfig(config)
                    configurations.append(config)
                    connectionStats[config.id] = ConnectionStatistics(configurationId: config.id)
                    savedConfigs.append(config)
                } catch {
                    // Continue importing other configurations even if one fails
                    continue
                }
            }
            
            return savedConfigs
        } catch {
            let importError = ConnectionManagerViewModelError.importFailed(underlying: error)
            self.error = importError
            throw importError
        }
    }
    
    // MARK: - Computed Properties
    
    /// Returns the number of configurations
    var configurationCount: Int {
        return configurations.count
    }
    
    /// Returns configurations that have auto-mount enabled
    var autoMountConfigurations: [MountConfiguration] {
        return configurations.filter { $0.autoMount }
    }
    
    /// Returns configurations that have sync enabled
    var syncEnabledConfigurations: [MountConfiguration] {
        return configurations.filter { $0.syncEnabled }
    }
    
    /// Returns true if there are any configurations
    var hasConfigurations: Bool {
        return !configurations.isEmpty
    }
    
    // MARK: - Private Methods
    
    /// Updates connection statistics for a configuration
    /// - Parameters:
    ///   - configId: The configuration ID
    ///   - success: Whether the connection was successful
    ///   - latencyMs: The latency in milliseconds (if successful)
    private func updateConnectionStats(for configId: UUID, success: Bool, latencyMs: Double?) {
        let existingStats = connectionStats[configId] ?? ConnectionStatistics(configurationId: configId)
        
        let newTotalConnections = existingStats.totalConnections + 1
        let newSuccessfulConnections = existingStats.successfulConnections + (success ? 1 : 0)
        
        // Calculate new average latency
        var newAverageLatency: Double? = existingStats.averageLatencyMs
        if success, let latency = latencyMs {
            if let existingAverage = existingStats.averageLatencyMs {
                // Weighted average
                newAverageLatency = (existingAverage * Double(existingStats.successfulConnections) + latency) / Double(newSuccessfulConnections)
            } else {
                newAverageLatency = latency
            }
        }
        
        connectionStats[configId] = ConnectionStatistics(
            configurationId: configId,
            lastConnectedAt: success ? Date() : existingStats.lastConnectedAt,
            totalConnections: newTotalConnections,
            successfulConnections: newSuccessfulConnections,
            averageLatencyMs: newAverageLatency
        )
    }
    
    /// Gets a configuration by ID
    /// - Parameter id: The configuration ID
    /// - Returns: The configuration if found, nil otherwise
    func getConfiguration(by id: UUID) -> MountConfiguration? {
        return configurations.first { $0.id == id }
    }
    
    /// Gets connection statistics for a configuration
    /// - Parameter configId: The configuration ID
    /// - Returns: The connection statistics if available, nil otherwise
    func getConnectionStats(for configId: UUID) -> ConnectionStatistics? {
        return connectionStats[configId]
    }
}

// MARK: - ConnectionManagerViewModelError

/// Errors that can occur during connection manager view model operations
enum ConnectionManagerViewModelError: LocalizedError {
    /// Configuration validation failed
    case validationFailed(errors: [MountConfigurationValidationError])
    /// Batch delete operation partially failed
    case batchDeleteFailed(failedIds: [UUID], errors: [Error])
    /// Export operation failed
    case exportFailed(underlying: Error)
    /// Import operation failed
    case importFailed(underlying: Error)
    /// Configuration not found
    case configurationNotFound(id: UUID)
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let errors):
            let errorMessages = errors.map { $0.localizedDescription }.joined(separator: ", ")
            return String(
                format: NSLocalizedString(
                    "Configuration validation failed: %@",
                    comment: "Validation error"
                ),
                errorMessages
            )
        case .batchDeleteFailed(let failedIds, _):
            return String(
                format: NSLocalizedString(
                    "Failed to delete %d configuration(s)",
                    comment: "Batch delete error"
                ),
                failedIds.count
            )
        case .exportFailed(let underlying):
            return String(
                format: NSLocalizedString(
                    "Failed to export configurations: %@",
                    comment: "Export error"
                ),
                underlying.localizedDescription
            )
        case .importFailed(let underlying):
            return String(
                format: NSLocalizedString(
                    "Failed to import configurations: %@",
                    comment: "Import error"
                ),
                underlying.localizedDescription
            )
        case .configurationNotFound(let id):
            return String(
                format: NSLocalizedString(
                    "Configuration with ID %@ not found",
                    comment: "Configuration not found error"
                ),
                id.uuidString
            )
        }
    }
}
