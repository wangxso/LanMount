//
//  NetworkScanner.swift
//  LanMount
//
//  Network scanner for discovering SMB services on the local network using Bonjour/mDNS
//  Requirements: 3.1, 3.2, 3.3, 3.4, 3.5
//

import Foundation
import Network

// MARK: - NetworkScannerProtocol

/// Protocol defining the interface for network scanning operations
/// Uses Bonjour/mDNS to discover SMB services on the local network
protocol NetworkScannerProtocol {
    /// Starts scanning the network for SMB services
    /// The scan will automatically stop after the timeout period (30 seconds)
    func startScan() async
    
    /// Stops the current network scan
    func stopScan()
    
    /// Stream of discovered services, updated in real-time as services are found
    var discoveredServices: AsyncStream<DiscoveredService> { get }
    
    /// Indicates whether a scan is currently in progress
    var isScanning: Bool { get }
}

// MARK: - NetworkScanner

/// Implementation of NetworkScannerProtocol using Network framework's NWBrowser
/// Discovers SMB services via Bonjour/mDNS and resolves their endpoints
final class NetworkScanner: NetworkScannerProtocol {
    
    // MARK: - Constants
    
    /// SMB service type for Bonjour discovery
    private static let smbServiceType = "_smb._tcp"
    
    /// Default scan timeout in seconds
    private static let defaultScanTimeout: TimeInterval = 30.0
    
    // MARK: - Properties
    
    /// The NWBrowser instance for service discovery
    private var browser: NWBrowser?
    
    /// Queue for browser operations
    private let browserQueue = DispatchQueue(label: "com.lanmount.networkscanner", qos: .userInitiated)
    
    /// Continuation for the AsyncStream
    private var streamContinuation: AsyncStream<DiscoveredService>.Continuation?
    
    /// Set of discovered service identifiers to avoid duplicates
    private var discoveredServiceIds: Set<String> = []
    
    /// Lock for thread-safe access to discoveredServiceIds
    private let discoveredLock = NSLock()
    
    /// Timer for scan timeout
    private var timeoutTask: Task<Void, Never>?
    
    /// Scan timeout duration
    private let scanTimeout: TimeInterval
    
    /// Current scanning state
    private var _isScanning: Bool = false
    
    /// Lock for thread-safe access to _isScanning
    private let scanningLock = NSLock()
    
    /// The AsyncStream for discovered services
    private var _discoveredServices: AsyncStream<DiscoveredService>?
    
    /// Cache manager for caching discovered services (5 minute TTL)
    /// Requirements: 11.1, 11.2 - Performance optimization
    private let cacheManager: CacheManagerProtocol?
    
    // MARK: - NetworkScannerProtocol Properties
    
    var isScanning: Bool {
        scanningLock.lock()
        defer { scanningLock.unlock() }
        return _isScanning
    }
    
    var discoveredServices: AsyncStream<DiscoveredService> {
        if let existing = _discoveredServices {
            return existing
        }
        
        let stream = AsyncStream<DiscoveredService> { [weak self] continuation in
            self?.streamContinuation = continuation
            
            continuation.onTermination = { @Sendable _ in
                self?.stopScan()
            }
        }
        
        _discoveredServices = stream
        return stream
    }
    
    // MARK: - Initialization
    
    /// Creates a new NetworkScanner instance
    /// - Parameters:
    ///   - scanTimeout: The timeout duration for scans (defaults to 30 seconds)
    ///   - cacheManager: Optional cache manager for caching discovered services
    init(
        scanTimeout: TimeInterval = NetworkScanner.defaultScanTimeout,
        cacheManager: CacheManagerProtocol? = nil
    ) {
        self.scanTimeout = scanTimeout
        self.cacheManager = cacheManager
    }
    
    deinit {
        stopScan()
    }
    
    // MARK: - NetworkScannerProtocol Implementation
    
    func startScan() async {
        // Check if already scanning
        guard !isScanning else {
            return
        }
        
        // Set scanning state
        setScanningState(true)
        
        // Clear previous discoveries
        clearDiscoveredServices()
        
        // Create a new stream if needed
        if _discoveredServices == nil {
            _ = discoveredServices
        }
        
        // Emit cached services first for immediate UI feedback
        // Requirements: 11.1, 11.2 - Performance optimization
        emitCachedServices()
        
        // Create and configure the browser
        let descriptor = NWBrowser.Descriptor.bonjour(type: Self.smbServiceType, domain: "local.")
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        let newBrowser = NWBrowser(for: descriptor, using: parameters)
        browser = newBrowser
        
        // Set up state update handler
        newBrowser.stateUpdateHandler = { [weak self] state in
            self?.handleBrowserStateChange(state)
        }
        
        // Set up results changed handler
        newBrowser.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleBrowseResultsChanged(results: results, changes: changes)
        }
        
        // Start the browser
        newBrowser.start(queue: browserQueue)
        
        // Start timeout timer
        startTimeoutTimer()
    }
    
    func stopScan() {
        // Cancel timeout timer
        timeoutTask?.cancel()
        timeoutTask = nil
        
        // Stop the browser
        browser?.cancel()
        browser = nil
        
        // Finish the stream
        streamContinuation?.finish()
        streamContinuation = nil
        _discoveredServices = nil
        
        // Update scanning state
        setScanningState(false)
    }
    
    // MARK: - Private Methods
    
    /// Sets the scanning state in a thread-safe manner
    /// - Parameter scanning: The new scanning state
    private func setScanningState(_ scanning: Bool) {
        scanningLock.lock()
        defer { scanningLock.unlock() }
        _isScanning = scanning
    }
    
    /// Clears the set of discovered services
    private func clearDiscoveredServices() {
        discoveredLock.lock()
        defer { discoveredLock.unlock() }
        discoveredServiceIds.removeAll()
    }
    
    /// Emits cached services at the start of a scan for immediate UI feedback
    /// Requirements: 11.1, 11.2 - Performance optimization
    private func emitCachedServices() {
        guard let cacheManager = cacheManager else { return }
        
        let cachedServices = cacheManager.getAllCachedServices()
        for service in cachedServices {
            // Mark as already discovered to avoid duplicates
            let serviceId = "\(service.name)._smb._tcp.local."
            discoveredLock.lock()
            discoveredServiceIds.insert(serviceId)
            discoveredLock.unlock()
            
            // Emit the cached service
            streamContinuation?.yield(service)
        }
    }
    
    /// Starts the timeout timer for the scan
    private func startTimeoutTimer() {
        timeoutTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                try await Task.sleep(nanoseconds: UInt64(self.scanTimeout * 1_000_000_000))
                
                // Check if we're still scanning
                if self.isScanning {
                    self.stopScan()
                }
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }
    
    /// Handles browser state changes
    /// - Parameter state: The new browser state
    private func handleBrowserStateChange(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            // Browser is ready and scanning
            break
            
        case .failed(let error):
            // Browser failed, stop scanning
            print("[NetworkScanner] Browser failed with error: \(error)")
            stopScan()
            
        case .cancelled:
            // Browser was cancelled
            setScanningState(false)
            
        case .waiting(let error):
            // Browser is waiting (e.g., no network)
            print("[NetworkScanner] Browser waiting: \(error)")
            
        case .setup:
            // Browser is setting up
            break
            
        @unknown default:
            break
        }
    }
    
    /// Handles changes in browse results
    /// - Parameters:
    ///   - results: The current set of browse results
    ///   - changes: The changes since the last update
    private func handleBrowseResultsChanged(results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                handleServiceAdded(result)
                
            case .removed(let result):
                handleServiceRemoved(result)
                
            case .changed(old: _, new: let newResult, flags: _):
                handleServiceAdded(newResult)
                
            case .identical:
                break
                
            @unknown default:
                break
            }
        }
    }
    
    /// Handles a newly discovered service
    /// - Parameter result: The browse result for the discovered service
    private func handleServiceAdded(_ result: NWBrowser.Result) {
        // Extract service name from the endpoint
        guard case .service(let name, let type, let domain, _) = result.endpoint else {
            return
        }
        
        // Create a unique identifier for this service
        let serviceId = "\(name).\(type).\(domain)"
        
        // Check if we've already discovered this service
        discoveredLock.lock()
        let isNew = discoveredServiceIds.insert(serviceId).inserted
        discoveredLock.unlock()
        
        guard isNew else {
            return
        }
        
        // Resolve the service endpoint to get IP address and port
        resolveServiceEndpoint(result: result, name: name)
    }
    
    /// Handles a removed service
    /// - Parameter result: The browse result for the removed service
    private func handleServiceRemoved(_ result: NWBrowser.Result) {
        guard case .service(let name, let type, let domain, _) = result.endpoint else {
            return
        }
        
        let serviceId = "\(name).\(type).\(domain)"
        
        discoveredLock.lock()
        discoveredServiceIds.remove(serviceId)
        discoveredLock.unlock()
    }
    
    /// Resolves a service endpoint to get IP address and port
    /// - Parameters:
    ///   - result: The browse result to resolve
    ///   - name: The service name
    private func resolveServiceEndpoint(result: NWBrowser.Result, name: String) {
        // Create a connection to resolve the endpoint
        let parameters = NWParameters.tcp
        let connection = NWConnection(to: result.endpoint, using: parameters)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                // Connection is ready, extract endpoint information
                if let resolvedEndpoint = connection.currentPath?.remoteEndpoint {
                    self?.processResolvedEndpoint(
                        endpoint: resolvedEndpoint,
                        serviceName: name,
                        originalEndpoint: result.endpoint
                    )
                }
                connection.cancel()
                
            case .failed(let error):
                print("[NetworkScanner] Failed to resolve endpoint for \(name): \(error)")
                // Try to create service with hostname only
                self?.createServiceFromHostname(result: result, name: name)
                connection.cancel()
                
            case .cancelled:
                break
                
            case .waiting(let error):
                print("[NetworkScanner] Waiting to resolve endpoint for \(name): \(error)")
                // Try to create service with hostname only
                self?.createServiceFromHostname(result: result, name: name)
                connection.cancel()
                
            default:
                break
            }
        }
        
        connection.start(queue: browserQueue)
        
        // Set a timeout for resolution
        browserQueue.asyncAfter(deadline: .now() + 5.0) { [weak connection] in
            if let conn = connection, conn.state != .ready && conn.state != .cancelled {
                conn.cancel()
            }
        }
    }
    
    /// Processes a resolved endpoint and creates a DiscoveredService
    /// - Parameters:
    ///   - endpoint: The resolved network endpoint
    ///   - serviceName: The name of the service
    ///   - originalEndpoint: The original Bonjour endpoint
    private func processResolvedEndpoint(
        endpoint: NWEndpoint,
        serviceName: String,
        originalEndpoint: NWEndpoint
    ) {
        var ipAddress = ""
        var port = 445 // Default SMB port
        var hostname = serviceName
        
        // Extract IP address and port from the resolved endpoint
        switch endpoint {
        case .hostPort(let host, let resolvedPort):
            port = Int(resolvedPort.rawValue)
            
            switch host {
            case .ipv4(let ipv4):
                ipAddress = ipv4.debugDescription
            case .ipv6(let ipv6):
                ipAddress = ipv6.debugDescription
            case .name(let name, _):
                hostname = name
                // Try to resolve the hostname to IP
                ipAddress = resolveHostnameToIP(name) ?? name
            @unknown default:
                break
            }
            
        default:
            break
        }
        
        // Extract hostname from original endpoint if available
        if case .service(_, _, _, let interface) = originalEndpoint {
            // Use the service name as hostname if we don't have a better one
            if hostname == serviceName {
                hostname = serviceName
            }
        }
        
        // If we still don't have an IP address, try to resolve the hostname
        if ipAddress.isEmpty {
            ipAddress = resolveHostnameToIP(hostname) ?? hostname
        }
        
        // Create the discovered service
        let service = DiscoveredService(
            name: serviceName,
            hostname: hostname,
            ipAddress: ipAddress,
            port: port,
            shares: [],
            discoveredAt: Date()
        )
        
        // Cache the discovered service (5 minute TTL)
        // Requirements: 11.1, 11.2 - Performance optimization
        cacheManager?.cacheService(service)
        
        // Emit the service to the stream
        streamContinuation?.yield(service)
    }
    
    /// Creates a service from hostname when IP resolution fails
    /// - Parameters:
    ///   - result: The browse result
    ///   - name: The service name
    private func createServiceFromHostname(result: NWBrowser.Result, name: String) {
        guard case .service(let serviceName, _, _, _) = result.endpoint else {
            return
        }
        
        // Try to resolve hostname to IP
        let hostname = "\(serviceName).local"
        let ipAddress = resolveHostnameToIP(hostname) ?? hostname
        
        let service = DiscoveredService(
            name: serviceName,
            hostname: hostname,
            ipAddress: ipAddress,
            port: 445,
            shares: [],
            discoveredAt: Date()
        )
        
        // Cache the discovered service (5 minute TTL)
        // Requirements: 11.1, 11.2 - Performance optimization
        cacheManager?.cacheService(service)
        
        streamContinuation?.yield(service)
    }
    
    /// Resolves a hostname to an IP address
    /// - Parameter hostname: The hostname to resolve
    /// - Returns: The IP address string, or nil if resolution fails
    private func resolveHostnameToIP(_ hostname: String) -> String? {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        
        var result: UnsafeMutablePointer<addrinfo>?
        
        let status = getaddrinfo(hostname, nil, &hints, &result)
        
        guard status == 0, let addrInfo = result else {
            return nil
        }
        
        defer { freeaddrinfo(result) }
        
        var ipAddress: String?
        var current: UnsafeMutablePointer<addrinfo>? = addrInfo
        
        while let info = current {
            if info.pointee.ai_family == AF_INET {
                // IPv4
                var addr = sockaddr_in()
                memcpy(&addr, info.pointee.ai_addr, Int(MemoryLayout<sockaddr_in>.size))
                
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &addr.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
                ipAddress = String(cString: buffer)
                break
                
            } else if info.pointee.ai_family == AF_INET6 {
                // IPv6 (use as fallback)
                var addr = sockaddr_in6()
                memcpy(&addr, info.pointee.ai_addr, Int(MemoryLayout<sockaddr_in6>.size))
                
                var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                inet_ntop(AF_INET6, &addr.sin6_addr, &buffer, socklen_t(INET6_ADDRSTRLEN))
                
                if ipAddress == nil {
                    ipAddress = String(cString: buffer)
                }
            }
            
            current = info.pointee.ai_next
        }
        
        return ipAddress
    }
}

// MARK: - Mock NetworkScanner for Testing

/// Mock implementation of NetworkScannerProtocol for unit testing
final class MockNetworkScanner: NetworkScannerProtocol {
    
    // MARK: - Test Configuration
    
    /// Services to emit during scanning
    var servicesToEmit: [DiscoveredService] = []
    
    /// Delay between emitting services (in seconds)
    var emitDelay: TimeInterval = 0.1
    
    /// Whether to simulate a scan timeout
    var simulateTimeout: Bool = false
    
    /// Whether to simulate a scan failure
    var simulateFailure: Bool = false
    
    // MARK: - State
    
    private var _isScanning: Bool = false
    private var streamContinuation: AsyncStream<DiscoveredService>.Continuation?
    private var _discoveredServices: AsyncStream<DiscoveredService>?
    private var scanTask: Task<Void, Never>?
    
    /// Records of startScan calls
    var startScanCalls: Int = 0
    
    /// Records of stopScan calls
    var stopScanCalls: Int = 0
    
    // MARK: - NetworkScannerProtocol Properties
    
    var isScanning: Bool {
        return _isScanning
    }
    
    var discoveredServices: AsyncStream<DiscoveredService> {
        if let existing = _discoveredServices {
            return existing
        }
        
        let stream = AsyncStream<DiscoveredService> { [weak self] continuation in
            self?.streamContinuation = continuation
            
            continuation.onTermination = { @Sendable _ in
                self?.stopScan()
            }
        }
        
        _discoveredServices = stream
        return stream
    }
    
    // MARK: - NetworkScannerProtocol Implementation
    
    func startScan() async {
        startScanCalls += 1
        
        guard !_isScanning else { return }
        _isScanning = true
        
        // Create stream if needed
        if _discoveredServices == nil {
            _ = discoveredServices
        }
        
        // Start emitting services
        scanTask = Task { [weak self] in
            guard let self = self else { return }
            
            if self.simulateFailure {
                self.stopScan()
                return
            }
            
            for service in self.servicesToEmit {
                guard !Task.isCancelled else { break }
                
                try? await Task.sleep(nanoseconds: UInt64(self.emitDelay * 1_000_000_000))
                
                guard !Task.isCancelled else { break }
                
                self.streamContinuation?.yield(service)
            }
            
            if self.simulateTimeout {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
            
            self.stopScan()
        }
    }
    
    func stopScan() {
        stopScanCalls += 1
        
        scanTask?.cancel()
        scanTask = nil
        
        streamContinuation?.finish()
        streamContinuation = nil
        _discoveredServices = nil
        
        _isScanning = false
    }
    
    // MARK: - Test Helpers
    
    /// Resets all recorded calls and configuration
    func reset() {
        stopScan()
        servicesToEmit = []
        emitDelay = 0.1
        simulateTimeout = false
        simulateFailure = false
        startScanCalls = 0
        stopScanCalls = 0
    }
    
    /// Manually emits a service (for testing real-time updates)
    func emitService(_ service: DiscoveredService) {
        streamContinuation?.yield(service)
    }
}
