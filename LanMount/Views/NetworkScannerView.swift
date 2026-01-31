//
//  NetworkScannerView.swift
//  LanMount
//
//  SwiftUI view for network scanning and SMB service discovery
//  Requirements: 9.4 - Display network scanner and discovered shares
//

import SwiftUI

// MARK: - NetworkScannerView

/// A SwiftUI view for scanning the network and displaying discovered SMB services
/// Provides real-time updates as services are discovered via Bonjour/mDNS
/// Requirements: 9.4 - Start Bonjour_Scanner and display discovered shares when user selects "Scan Network"
struct NetworkScannerView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State Properties
    
    /// The network scanner instance
    @StateObject private var viewModel: NetworkScannerViewModel
    
    /// Currently selected service
    @State private var selectedService: DiscoveredService?
    
    // MARK: - Callbacks
    
    /// Called when a service is selected to auto-fill the configuration form
    var onServiceSelected: ((DiscoveredService) -> Void)?
    
    /// Called when the user cancels
    var onCancel: (() -> Void)?
    
    // MARK: - Initialization
    
    /// Creates a new NetworkScannerView
    /// - Parameters:
    ///   - scanner: The network scanner to use (defaults to a new NetworkScanner instance)
    ///   - onServiceSelected: Callback when a service is selected
    ///   - onCancel: Callback when the view is cancelled
    init(
        scanner: NetworkScannerProtocol? = nil,
        onServiceSelected: ((DiscoveredService) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: NetworkScannerViewModel(scanner: scanner ?? NetworkScanner()))
        self.onServiceSelected = onServiceSelected
        self.onCancel = onCancel
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            contentView
            
            Divider()
            
            // Footer with buttons
            footerView
        }
        .frame(width: 500, height: 450)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            viewModel.startScanning()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Image(systemName: "network")
                .font(.title2)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            
            Text(NSLocalizedString("Network Scanner", comment: "Network scanner window title"))
                .font(.headline)
            
            Spacer()
            
            // Scanning status indicator
            if viewModel.isScanning {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                    
                    Text(NSLocalizedString("Scanning...", comment: "Scanning status"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(NSLocalizedString("Scanning network", comment: "Accessibility: Scanning status"))
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        VStack(spacing: 0) {
            // Scanning progress section
            if viewModel.isScanning && viewModel.discoveredServices.isEmpty {
                scanningProgressView
            } else if viewModel.discoveredServices.isEmpty && !viewModel.isScanning {
                emptyStateView
            } else {
                // Services list
                serviceListView
            }
        }
    }
    
    // MARK: - Scanning Progress View
    
    private var scanningProgressView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityHidden(true)
            
            Text(NSLocalizedString("Scanning network for SMB services...", comment: "Scanning message"))
                .font(.callout)
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("This may take up to 30 seconds", comment: "Scanning duration hint"))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("Scanning network for SMB services. This may take up to 30 seconds.", comment: "Accessibility: Scanning progress"))
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text(NSLocalizedString("No SMB Services Found", comment: "Empty state title"))
                .font(.headline)
            
            Text(NSLocalizedString("Make sure your SMB servers are online and on the same network.", comment: "Empty state message"))
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                viewModel.startScanning()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .accessibilityHidden(true)
                    Text(NSLocalizedString("Scan Again", comment: "Button title"))
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(NSLocalizedString("Scan Again", comment: "Accessibility: Scan again button"))
            .accessibilityHint(NSLocalizedString("Starts a new network scan for SMB services", comment: "Accessibility: Scan again hint"))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NSLocalizedString("No SMB services found. Make sure your SMB servers are online and on the same network.", comment: "Accessibility: Empty state"))
    }
    
    // MARK: - Service List View
    
    private var serviceListView: some View {
        VStack(spacing: 0) {
            // List header
            HStack {
                Text(NSLocalizedString("Discovered Services", comment: "List header"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                Text("\(viewModel.discoveredServices.count) " + NSLocalizedString("found", comment: "Services count suffix"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel(String(format: NSLocalizedString("%d services found", comment: "Accessibility: Services count"), viewModel.discoveredServices.count))
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Services list
            List(viewModel.discoveredServices, selection: $selectedService) { service in
                ServiceRowView(service: service, isSelected: selectedService?.id == service.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedService = service
                    }
                    .onTapGesture(count: 2) {
                        handleServiceSelection(service)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(serviceAccessibilityLabel(for: service))
                    .accessibilityHint(NSLocalizedString("Double-tap to select this service", comment: "Accessibility: Service row hint"))
                    .accessibilityAddTraits(selectedService?.id == service.id ? [.isSelected] : [])
            }
            .listStyle(.inset)
            .accessibilityLabel(NSLocalizedString("Discovered SMB services list", comment: "Accessibility: Services list"))
        }
    }
    
    /// Creates an accessibility label for a discovered service
    private func serviceAccessibilityLabel(for service: DiscoveredService) -> String {
        var label = service.name + ", " + NSLocalizedString("IP address", comment: "Accessibility: IP label") + " " + service.ipAddress
        if !service.shares.isEmpty {
            label += ", " + NSLocalizedString("Shares", comment: "Accessibility: Shares label") + ": " + service.shares.joined(separator: ", ")
        }
        return label
    }
    
    // MARK: - Footer View
    
    private var footerView: some View {
        HStack(spacing: 12) {
            // Refresh button
            Button(action: {
                viewModel.startScanning()
            }) {
                HStack(spacing: 6) {
                    if viewModel.isScanning {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .accessibilityHidden(true)
                    }
                    Text(NSLocalizedString("Refresh", comment: "Button title"))
                }
            }
            .disabled(viewModel.isScanning)
            .accessibilityLabel(NSLocalizedString("Refresh", comment: "Accessibility: Refresh button"))
            .accessibilityHint(NSLocalizedString("Starts a new network scan", comment: "Accessibility: Refresh hint"))
            .accessibilityValue(viewModel.isScanning ? NSLocalizedString("Scanning in progress", comment: "Accessibility: Scanning") : "")
            
            Spacer()
            
            // Cancel button
            Button(NSLocalizedString("Cancel", comment: "Button title")) {
                handleCancel()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel(NSLocalizedString("Cancel", comment: "Accessibility: Cancel button"))
            .accessibilityHint(NSLocalizedString("Closes this window without selecting a service", comment: "Accessibility: Cancel hint"))
            
            // Select button
            Button(action: {
                if let service = selectedService {
                    handleServiceSelection(service)
                }
            }) {
                Text(NSLocalizedString("Select", comment: "Button title"))
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedService == nil)
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(NSLocalizedString("Select", comment: "Accessibility: Select button"))
            .accessibilityHint(selectedService != nil 
                ? String(format: NSLocalizedString("Selects %@ and opens mount configuration", comment: "Accessibility: Select hint with service"), selectedService!.name)
                : NSLocalizedString("Select a service from the list first", comment: "Accessibility: Select hint no selection"))
        }
        .padding()
    }
    
    // MARK: - Actions
    
    /// Handles service selection
    private func handleServiceSelection(_ service: DiscoveredService) {
        onServiceSelected?(service)
        dismiss()
    }
    
    /// Handles cancel action
    private func handleCancel() {
        viewModel.stopScanning()
        onCancel?()
        dismiss()
    }
}

// MARK: - ServiceRowView

/// A row view for displaying a discovered SMB service
struct ServiceRowView: View {
    
    /// The discovered service to display
    let service: DiscoveredService
    
    /// Whether this row is selected
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Service icon
            Image(systemName: "server.rack")
                .font(.title2)
                .foregroundColor(isSelected ? .white : .accentColor)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            
            // Service details
            VStack(alignment: .leading, spacing: 4) {
                // Service name
                Text(service.name)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                // IP address and port
                HStack(spacing: 8) {
                    Label(service.ipAddress, systemImage: "network")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .labelStyle(.titleAndIcon)
                    
                    if service.port != 445 {
                        Text(":\(service.port)")
                            .font(.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                }
                
                // Available shares (if any)
                if !service.shares.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                            .accessibilityHidden(true)
                        
                        Text(service.shares.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - NetworkScannerViewModel

/// ViewModel for managing network scanning state and discovered services
@MainActor
final class NetworkScannerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// List of discovered SMB services
    @Published private(set) var discoveredServices: [DiscoveredService] = []
    
    /// Whether scanning is currently in progress
    @Published private(set) var isScanning: Bool = false
    
    /// Error message if scanning failed
    @Published private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    
    /// The network scanner instance
    private let scanner: NetworkScannerProtocol
    
    /// Task for consuming the discovered services stream
    private var scanTask: Task<Void, Never>?
    
    /// Set of discovered service IDs to avoid duplicates
    private var discoveredServiceIds: Set<UUID> = []
    
    // MARK: - Initialization
    
    /// Creates a new NetworkScannerViewModel
    /// - Parameter scanner: The network scanner to use
    init(scanner: NetworkScannerProtocol) {
        self.scanner = scanner
    }
    
    deinit {
        scanTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Starts scanning the network for SMB services
    func startScanning() {
        // Cancel any existing scan
        stopScanning()
        
        // Clear previous results
        discoveredServices.removeAll()
        discoveredServiceIds.removeAll()
        errorMessage = nil
        isScanning = true
        
        // Start the scan task
        scanTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Start the scanner
            await self.scanner.startScan()
            
            // Consume discovered services
            for await service in self.scanner.discoveredServices {
                guard !Task.isCancelled else { break }
                
                // Check for duplicates
                if !self.discoveredServiceIds.contains(service.id) {
                    self.discoveredServiceIds.insert(service.id)
                    self.discoveredServices.append(service)
                }
            }
            
            // Scanning completed
            self.isScanning = false
        }
    }
    
    /// Stops the current network scan
    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
        scanner.stopScan()
        isScanning = false
    }
}

// MARK: - Preview

#Preview("Scanning") {
    let mockScanner = MockNetworkScanner()
    mockScanner.servicesToEmit = []
    
    return NetworkScannerView(scanner: mockScanner)
}

#Preview("With Services") {
    let mockScanner = MockNetworkScanner()
    mockScanner.servicesToEmit = [
        DiscoveredService(
            name: "NAS Server",
            hostname: "nas.local",
            ipAddress: "192.168.1.100",
            port: 445,
            shares: ["Documents", "Media", "Backup"]
        ),
        DiscoveredService(
            name: "File Server",
            hostname: "fileserver.local",
            ipAddress: "192.168.1.101",
            port: 445,
            shares: ["Public"]
        ),
        DiscoveredService(
            name: "Mac Mini",
            hostname: "macmini.local",
            ipAddress: "192.168.1.102",
            port: 445,
            shares: []
        )
    ]
    mockScanner.emitDelay = 0.5
    
    return NetworkScannerView(scanner: mockScanner)
}

#Preview("Empty State") {
    let mockScanner = MockNetworkScanner()
    mockScanner.servicesToEmit = []
    mockScanner.emitDelay = 0.01
    
    return NetworkScannerView(scanner: mockScanner)
}
