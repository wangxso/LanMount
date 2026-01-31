//
//  CacheManager.swift
//  LanMount
//
//  Manages caching for discovered services and mount status to improve performance
//  Requirements: 11.1, 11.2 - Performance and resource management
//

import Foundation

// MARK: - CacheManagerProtocol

/// Protocol defining the interface for cache management operations
/// Provides caching for discovered services and mount status to reduce system calls
protocol CacheManagerProtocol {
    // MARK: - Service Cache
    
    /// Caches a discovered service
    /// - Parameter service: The discovered service to cache
    func cacheService(_ service: DiscoveredService)
    
    /// Caches multiple discovered services
    /// - Parameter services: The services to cache
    func cacheServices(_ services: [DiscoveredService])
    
    /// Retrieves a cached service by its identifier
    /// - Parameter identifier: The unique identifier (typically hostname or IP)
    /// - Returns: The cached service if found and not expired, nil otherwise
    func getCachedService(identifier: String) -> DiscoveredService?
    
    /// Retrieves all cached services that haven't expired
    /// - Returns: Array of cached services
    func getAllCachedServices() -> [DiscoveredService]
    
    /// Invalidates a specific cached service
    /// - Parameter identifier: The identifier of the service to invalidate
    func invalidateService(identifier: String)
    
    /// Invalidates all cached services
    func invalidateAllServices()
    
    // MARK: - Mount Status Cache
    
    /// Caches the mount status for a mount point
    /// - Parameters:
    ///   - status: The mount status to cache
    ///   - mountPoint: The mount point path
    func cacheMountStatus(_ status: MountStatusCacheEntry, for mountPoint: String)
    
    /// Retrieves the cached mount status for a mount point
    /// - Parameter mountPoint: The mount point path
    /// - Returns: The cached status if found and not expired, nil otherwise
    func getCachedMountStatus(for mountPoint: String) -> MountStatusCacheEntry?
    
    /// Invalidates the cached mount status for a mount point
    /// - Parameter mountPoint: The mount point path
    func invalidateMountStatus(for mountPoint: String)
    
    /// Invalidates all cached mount statuses
    func invalidateAllMountStatuses()
    
    // MARK: - Cache Management
    
    /// Clears all caches
    func clearAllCaches()
    
    /// Gets cache statistics for debugging
    /// - Returns: Current cache statistics
    func getStatistics() -> CacheStatistics
    
    /// Sets the TTL for service cache entries
    /// - Parameter ttl: Time-to-live in seconds
    func setServiceCacheTTL(_ ttl: TimeInterval)
    
    /// Sets the TTL for mount status cache entries
    /// - Parameter ttl: Time-to-live in seconds
    func setMountStatusCacheTTL(_ ttl: TimeInterval)
}

// MARK: - Cache Entry Types

/// Wrapper for cached service entries with expiration tracking
final class CachedServiceEntry: NSObject {
    /// The cached service
    let service: DiscoveredService
    /// Timestamp when the entry was cached
    let cachedAt: Date
    /// Time-to-live for this entry
    let ttl: TimeInterval
    
    /// Creates a new cached service entry
    init(service: DiscoveredService, ttl: TimeInterval) {
        self.service = service
        self.cachedAt = Date()
        self.ttl = ttl
        super.init()
    }
    
    /// Checks if the entry has expired
    var isExpired: Bool {
        return Date().timeIntervalSince(cachedAt) > ttl
    }
    
    /// Time remaining until expiration
    var timeRemaining: TimeInterval {
        let elapsed = Date().timeIntervalSince(cachedAt)
        return max(0, ttl - elapsed)
    }
}

/// Cached mount status entry with accessibility information
struct MountStatusCacheEntry: Equatable {
    /// Whether the mount point is accessible
    let isAccessible: Bool
    /// Whether it's an SMB mount
    let isSMBMount: Bool
    /// The filesystem type (e.g., "smbfs")
    let filesystemType: String?
    /// Mount source (e.g., "//server/share")
    let mountSource: String?
    /// Timestamp when the status was cached
    let cachedAt: Date
    /// Time-to-live for this entry
    let ttl: TimeInterval
    
    /// Creates a new mount status cache entry
    init(
        isAccessible: Bool,
        isSMBMount: Bool = false,
        filesystemType: String? = nil,
        mountSource: String? = nil,
        ttl: TimeInterval
    ) {
        self.isAccessible = isAccessible
        self.isSMBMount = isSMBMount
        self.filesystemType = filesystemType
        self.mountSource = mountSource
        self.cachedAt = Date()
        self.ttl = ttl
    }
    
    /// Checks if the entry has expired
    var isExpired: Bool {
        return Date().timeIntervalSince(cachedAt) > ttl
    }
    
    /// Time remaining until expiration
    var timeRemaining: TimeInterval {
        let elapsed = Date().timeIntervalSince(cachedAt)
        return max(0, ttl - elapsed)
    }
}

/// Wrapper for mount status entries to use with NSCache
final class CachedMountStatusEntry: NSObject {
    let entry: MountStatusCacheEntry
    
    init(entry: MountStatusCacheEntry) {
        self.entry = entry
        super.init()
    }
}

/// Statistics about cache usage for debugging
struct CacheStatistics: Equatable {
    /// Number of services currently cached
    let serviceCacheCount: Int
    /// Number of mount statuses currently cached
    let mountStatusCacheCount: Int
    /// Number of cache hits for services
    let serviceHits: Int
    /// Number of cache misses for services
    let serviceMisses: Int
    /// Number of cache hits for mount status
    let mountStatusHits: Int
    /// Number of cache misses for mount status
    let mountStatusMisses: Int
    /// Current service cache TTL
    let serviceTTL: TimeInterval
    /// Current mount status cache TTL
    let mountStatusTTL: TimeInterval
    /// Timestamp when statistics were collected
    let collectedAt: Date
    
    /// Service cache hit rate (0.0 - 1.0)
    var serviceHitRate: Double {
        let total = serviceHits + serviceMisses
        guard total > 0 else { return 0.0 }
        return Double(serviceHits) / Double(total)
    }
    
    /// Mount status cache hit rate (0.0 - 1.0)
    var mountStatusHitRate: Double {
        let total = mountStatusHits + mountStatusMisses
        guard total > 0 else { return 0.0 }
        return Double(mountStatusHits) / Double(total)
    }
}

// MARK: - CacheManager

/// Implementation of CacheManagerProtocol using NSCache for memory management
/// Provides caching for discovered services (5 minute TTL) and mount status
final class CacheManager: CacheManagerProtocol {
    
    // MARK: - Constants
    
    /// Default TTL for service cache entries (5 minutes as per requirements)
    static let defaultServiceTTL: TimeInterval = 300.0 // 5 minutes
    
    /// Default TTL for mount status cache entries (30 seconds to balance freshness and performance)
    static let defaultMountStatusTTL: TimeInterval = 30.0
    
    /// Maximum number of service entries to cache
    static let maxServiceCacheCount = 100
    
    /// Maximum number of mount status entries to cache
    static let maxMountStatusCacheCount = 50
    
    // MARK: - Properties
    
    /// NSCache for service entries
    private let serviceCache: NSCache<NSString, CachedServiceEntry>
    
    /// NSCache for mount status entries
    private let mountStatusCache: NSCache<NSString, CachedMountStatusEntry>
    
    /// Dictionary to track all service cache keys for enumeration
    private var serviceCacheKeys: Set<String> = []
    
    /// Dictionary to track all mount status cache keys for enumeration
    private var mountStatusCacheKeys: Set<String> = []
    
    /// Lock for thread-safe access to service cache keys
    private let serviceCacheKeysLock = NSLock()
    
    /// Lock for thread-safe access to mount status cache keys
    private let mountStatusCacheKeysLock = NSLock()
    
    /// Current TTL for service cache entries
    private var _serviceTTL: TimeInterval
    
    /// Current TTL for mount status cache entries
    private var _mountStatusTTL: TimeInterval
    
    /// Lock for thread-safe access to TTL values
    private let ttlLock = NSLock()
    
    /// Statistics tracking
    private var _serviceHits: Int = 0
    private var _serviceMisses: Int = 0
    private var _mountStatusHits: Int = 0
    private var _mountStatusMisses: Int = 0
    
    /// Lock for thread-safe access to statistics
    private let statsLock = NSLock()
    
    // MARK: - Initialization
    
    /// Creates a new CacheManager instance
    /// - Parameters:
    ///   - serviceTTL: TTL for service cache entries (defaults to 5 minutes)
    ///   - mountStatusTTL: TTL for mount status cache entries (defaults to 30 seconds)
    init(
        serviceTTL: TimeInterval = CacheManager.defaultServiceTTL,
        mountStatusTTL: TimeInterval = CacheManager.defaultMountStatusTTL
    ) {
        self._serviceTTL = serviceTTL
        self._mountStatusTTL = mountStatusTTL
        
        // Initialize service cache
        self.serviceCache = NSCache<NSString, CachedServiceEntry>()
        self.serviceCache.countLimit = Self.maxServiceCacheCount
        self.serviceCache.name = "com.lanmount.cache.services"
        
        // Initialize mount status cache
        self.mountStatusCache = NSCache<NSString, CachedMountStatusEntry>()
        self.mountStatusCache.countLimit = Self.maxMountStatusCacheCount
        self.mountStatusCache.name = "com.lanmount.cache.mountstatus"
        
        // Set up cache eviction delegate
        setupCacheEvictionHandling()
    }
    
    // MARK: - Service Cache Implementation
    
    func cacheService(_ service: DiscoveredService) {
        let identifier = createServiceIdentifier(for: service)
        let key = identifier as NSString
        
        ttlLock.lock()
        let ttl = _serviceTTL
        ttlLock.unlock()
        
        let entry = CachedServiceEntry(service: service, ttl: ttl)
        
        serviceCache.setObject(entry, forKey: key)
        
        serviceCacheKeysLock.lock()
        serviceCacheKeys.insert(identifier)
        serviceCacheKeysLock.unlock()
    }
    
    func cacheServices(_ services: [DiscoveredService]) {
        for service in services {
            cacheService(service)
        }
    }
    
    func getCachedService(identifier: String) -> DiscoveredService? {
        let key = identifier as NSString
        
        guard let entry = serviceCache.object(forKey: key) else {
            incrementServiceMisses()
            return nil
        }
        
        // Check if expired
        if entry.isExpired {
            invalidateService(identifier: identifier)
            incrementServiceMisses()
            return nil
        }
        
        incrementServiceHits()
        return entry.service
    }
    
    func getAllCachedServices() -> [DiscoveredService] {
        serviceCacheKeysLock.lock()
        let keys = Array(serviceCacheKeys)
        serviceCacheKeysLock.unlock()
        
        var services: [DiscoveredService] = []
        var expiredKeys: [String] = []
        
        for key in keys {
            if let entry = serviceCache.object(forKey: key as NSString) {
                if entry.isExpired {
                    expiredKeys.append(key)
                } else {
                    services.append(entry.service)
                }
            } else {
                expiredKeys.append(key)
            }
        }
        
        // Clean up expired entries
        for key in expiredKeys {
            invalidateService(identifier: key)
        }
        
        return services
    }
    
    func invalidateService(identifier: String) {
        let key = identifier as NSString
        serviceCache.removeObject(forKey: key)
        
        serviceCacheKeysLock.lock()
        serviceCacheKeys.remove(identifier)
        serviceCacheKeysLock.unlock()
    }
    
    func invalidateAllServices() {
        serviceCache.removeAllObjects()
        
        serviceCacheKeysLock.lock()
        serviceCacheKeys.removeAll()
        serviceCacheKeysLock.unlock()
    }
    
    // MARK: - Mount Status Cache Implementation
    
    func cacheMountStatus(_ status: MountStatusCacheEntry, for mountPoint: String) {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        let key = normalizedPath as NSString
        
        let wrapper = CachedMountStatusEntry(entry: status)
        
        mountStatusCache.setObject(wrapper, forKey: key)
        
        mountStatusCacheKeysLock.lock()
        mountStatusCacheKeys.insert(normalizedPath)
        mountStatusCacheKeysLock.unlock()
    }
    
    func getCachedMountStatus(for mountPoint: String) -> MountStatusCacheEntry? {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        let key = normalizedPath as NSString
        
        guard let wrapper = mountStatusCache.object(forKey: key) else {
            incrementMountStatusMisses()
            return nil
        }
        
        // Check if expired
        if wrapper.entry.isExpired {
            invalidateMountStatus(for: mountPoint)
            incrementMountStatusMisses()
            return nil
        }
        
        incrementMountStatusHits()
        return wrapper.entry
    }
    
    func invalidateMountStatus(for mountPoint: String) {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        let key = normalizedPath as NSString
        
        mountStatusCache.removeObject(forKey: key)
        
        mountStatusCacheKeysLock.lock()
        mountStatusCacheKeys.remove(normalizedPath)
        mountStatusCacheKeysLock.unlock()
    }
    
    func invalidateAllMountStatuses() {
        mountStatusCache.removeAllObjects()
        
        mountStatusCacheKeysLock.lock()
        mountStatusCacheKeys.removeAll()
        mountStatusCacheKeysLock.unlock()
    }
    
    // MARK: - Cache Management Implementation
    
    func clearAllCaches() {
        invalidateAllServices()
        invalidateAllMountStatuses()
        resetStatistics()
    }
    
    func getStatistics() -> CacheStatistics {
        serviceCacheKeysLock.lock()
        let serviceCount = serviceCacheKeys.count
        serviceCacheKeysLock.unlock()
        
        mountStatusCacheKeysLock.lock()
        let mountStatusCount = mountStatusCacheKeys.count
        mountStatusCacheKeysLock.unlock()
        
        statsLock.lock()
        let serviceHits = _serviceHits
        let serviceMisses = _serviceMisses
        let mountStatusHits = _mountStatusHits
        let mountStatusMisses = _mountStatusMisses
        statsLock.unlock()
        
        ttlLock.lock()
        let serviceTTL = _serviceTTL
        let mountStatusTTL = _mountStatusTTL
        ttlLock.unlock()
        
        return CacheStatistics(
            serviceCacheCount: serviceCount,
            mountStatusCacheCount: mountStatusCount,
            serviceHits: serviceHits,
            serviceMisses: serviceMisses,
            mountStatusHits: mountStatusHits,
            mountStatusMisses: mountStatusMisses,
            serviceTTL: serviceTTL,
            mountStatusTTL: mountStatusTTL,
            collectedAt: Date()
        )
    }
    
    func setServiceCacheTTL(_ ttl: TimeInterval) {
        ttlLock.lock()
        _serviceTTL = ttl
        ttlLock.unlock()
    }
    
    func setMountStatusCacheTTL(_ ttl: TimeInterval) {
        ttlLock.lock()
        _mountStatusTTL = ttl
        ttlLock.unlock()
    }
    
    // MARK: - Private Methods
    
    /// Creates a unique identifier for a discovered service
    /// - Parameter service: The service to create an identifier for
    /// - Returns: A unique identifier string
    private func createServiceIdentifier(for service: DiscoveredService) -> String {
        // Use IP address as primary identifier, fall back to hostname
        if !service.ipAddress.isEmpty {
            return service.ipAddress
        }
        return service.hostname
    }
    
    /// Sets up handling for cache eviction events
    private func setupCacheEvictionHandling() {
        // NSCache automatically handles memory pressure eviction
        // We track keys separately to allow enumeration
    }
    
    /// Increments the service cache hit counter
    private func incrementServiceHits() {
        statsLock.lock()
        _serviceHits += 1
        statsLock.unlock()
    }
    
    /// Increments the service cache miss counter
    private func incrementServiceMisses() {
        statsLock.lock()
        _serviceMisses += 1
        statsLock.unlock()
    }
    
    /// Increments the mount status cache hit counter
    private func incrementMountStatusHits() {
        statsLock.lock()
        _mountStatusHits += 1
        statsLock.unlock()
    }
    
    /// Increments the mount status cache miss counter
    private func incrementMountStatusMisses() {
        statsLock.lock()
        _mountStatusMisses += 1
        statsLock.unlock()
    }
    
    /// Resets all statistics counters
    private func resetStatistics() {
        statsLock.lock()
        _serviceHits = 0
        _serviceMisses = 0
        _mountStatusHits = 0
        _mountStatusMisses = 0
        statsLock.unlock()
    }
}

// MARK: - CacheManager Extension for Convenience Methods

extension CacheManager {
    /// Caches a service and returns whether it was a new entry
    /// - Parameter service: The service to cache
    /// - Returns: true if this was a new entry, false if it updated an existing one
    @discardableResult
    func cacheServiceIfNew(_ service: DiscoveredService) -> Bool {
        let identifier = createServiceIdentifier(for: service)
        let existingService = getCachedService(identifier: identifier)
        cacheService(service)
        return existingService == nil
    }
    
    /// Gets a cached service by IP address
    /// - Parameter ipAddress: The IP address to look up
    /// - Returns: The cached service if found and not expired
    func getCachedServiceByIP(_ ipAddress: String) -> DiscoveredService? {
        return getCachedService(identifier: ipAddress)
    }
    
    /// Gets a cached service by hostname
    /// - Parameter hostname: The hostname to look up
    /// - Returns: The cached service if found and not expired
    func getCachedServiceByHostname(_ hostname: String) -> DiscoveredService? {
        return getCachedService(identifier: hostname)
    }
    
    /// Checks if a mount point has a valid cached status
    /// - Parameter mountPoint: The mount point to check
    /// - Returns: true if there's a valid (non-expired) cached status
    func hasCachedMountStatus(for mountPoint: String) -> Bool {
        return getCachedMountStatus(for: mountPoint) != nil
    }
    
    /// Creates and caches a mount status entry from statfs result
    /// - Parameters:
    ///   - mountPoint: The mount point path
    ///   - isAccessible: Whether the mount point is accessible
    ///   - isSMBMount: Whether it's an SMB mount
    ///   - filesystemType: The filesystem type
    ///   - mountSource: The mount source
    func cacheMountStatusFromStatfs(
        mountPoint: String,
        isAccessible: Bool,
        isSMBMount: Bool = false,
        filesystemType: String? = nil,
        mountSource: String? = nil
    ) {
        ttlLock.lock()
        let ttl = _mountStatusTTL
        ttlLock.unlock()
        
        let entry = MountStatusCacheEntry(
            isAccessible: isAccessible,
            isSMBMount: isSMBMount,
            filesystemType: filesystemType,
            mountSource: mountSource,
            ttl: ttl
        )
        
        cacheMountStatus(entry, for: mountPoint)
    }
}

// MARK: - Mock CacheManager for Testing

/// Mock implementation of CacheManagerProtocol for unit testing
final class MockCacheManager: CacheManagerProtocol {
    
    // MARK: - Test State
    
    /// Cached services for testing
    var cachedServices: [String: DiscoveredService] = [:]
    
    /// Cached mount statuses for testing
    var cachedMountStatuses: [String: MountStatusCacheEntry] = [:]
    
    /// Service TTL for testing
    var serviceTTL: TimeInterval = CacheManager.defaultServiceTTL
    
    /// Mount status TTL for testing
    var mountStatusTTL: TimeInterval = CacheManager.defaultMountStatusTTL
    
    /// Statistics for testing
    var serviceHits: Int = 0
    var serviceMisses: Int = 0
    var mountStatusHits: Int = 0
    var mountStatusMisses: Int = 0
    
    // MARK: - Call Recording
    
    var cacheServiceCalls: [DiscoveredService] = []
    var getCachedServiceCalls: [String] = []
    var invalidateServiceCalls: [String] = []
    var cacheMountStatusCalls: [(MountStatusCacheEntry, String)] = []
    var getCachedMountStatusCalls: [String] = []
    var invalidateMountStatusCalls: [String] = []
    var clearAllCachesCalls: Int = 0
    
    // MARK: - Service Cache Implementation
    
    func cacheService(_ service: DiscoveredService) {
        cacheServiceCalls.append(service)
        let identifier = service.ipAddress.isEmpty ? service.hostname : service.ipAddress
        cachedServices[identifier] = service
    }
    
    func cacheServices(_ services: [DiscoveredService]) {
        for service in services {
            cacheService(service)
        }
    }
    
    func getCachedService(identifier: String) -> DiscoveredService? {
        getCachedServiceCalls.append(identifier)
        if let service = cachedServices[identifier] {
            serviceHits += 1
            return service
        }
        serviceMisses += 1
        return nil
    }
    
    func getAllCachedServices() -> [DiscoveredService] {
        return Array(cachedServices.values)
    }
    
    func invalidateService(identifier: String) {
        invalidateServiceCalls.append(identifier)
        cachedServices.removeValue(forKey: identifier)
    }
    
    func invalidateAllServices() {
        cachedServices.removeAll()
    }
    
    // MARK: - Mount Status Cache Implementation
    
    func cacheMountStatus(_ status: MountStatusCacheEntry, for mountPoint: String) {
        cacheMountStatusCalls.append((status, mountPoint))
        let normalizedPath = (mountPoint as NSString).standardizingPath
        cachedMountStatuses[normalizedPath] = status
    }
    
    func getCachedMountStatus(for mountPoint: String) -> MountStatusCacheEntry? {
        getCachedMountStatusCalls.append(mountPoint)
        let normalizedPath = (mountPoint as NSString).standardizingPath
        if let status = cachedMountStatuses[normalizedPath] {
            mountStatusHits += 1
            return status
        }
        mountStatusMisses += 1
        return nil
    }
    
    func invalidateMountStatus(for mountPoint: String) {
        invalidateMountStatusCalls.append(mountPoint)
        let normalizedPath = (mountPoint as NSString).standardizingPath
        cachedMountStatuses.removeValue(forKey: normalizedPath)
    }
    
    func invalidateAllMountStatuses() {
        cachedMountStatuses.removeAll()
    }
    
    // MARK: - Cache Management Implementation
    
    func clearAllCaches() {
        clearAllCachesCalls += 1
        cachedServices.removeAll()
        cachedMountStatuses.removeAll()
        serviceHits = 0
        serviceMisses = 0
        mountStatusHits = 0
        mountStatusMisses = 0
    }
    
    func getStatistics() -> CacheStatistics {
        return CacheStatistics(
            serviceCacheCount: cachedServices.count,
            mountStatusCacheCount: cachedMountStatuses.count,
            serviceHits: serviceHits,
            serviceMisses: serviceMisses,
            mountStatusHits: mountStatusHits,
            mountStatusMisses: mountStatusMisses,
            serviceTTL: serviceTTL,
            mountStatusTTL: mountStatusTTL,
            collectedAt: Date()
        )
    }
    
    func setServiceCacheTTL(_ ttl: TimeInterval) {
        serviceTTL = ttl
    }
    
    func setMountStatusCacheTTL(_ ttl: TimeInterval) {
        mountStatusTTL = ttl
    }
    
    // MARK: - Test Helpers
    
    /// Resets all recorded calls and state
    func reset() {
        cachedServices.removeAll()
        cachedMountStatuses.removeAll()
        serviceTTL = CacheManager.defaultServiceTTL
        mountStatusTTL = CacheManager.defaultMountStatusTTL
        serviceHits = 0
        serviceMisses = 0
        mountStatusHits = 0
        mountStatusMisses = 0
        cacheServiceCalls.removeAll()
        getCachedServiceCalls.removeAll()
        invalidateServiceCalls.removeAll()
        cacheMountStatusCalls.removeAll()
        getCachedMountStatusCalls.removeAll()
        invalidateMountStatusCalls.removeAll()
        clearAllCachesCalls = 0
    }
}
