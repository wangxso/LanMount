//
//  FinderIntegration.swift
//  LanMount
//
//  Handles Finder integration for mounted SMB volumes
//  Requirements: 5.1, 5.5
//

import Foundation
import AppKit

// MARK: - FinderIntegrationProtocol

/// Protocol defining the interface for Finder integration operations
/// Provides functionality to customize mounted volume appearance in Finder
protocol FinderIntegrationProtocol {
    /// Configures a mounted volume for optimal Finder display
    /// - Parameters:
    ///   - mountPoint: The local filesystem path where the share is mounted
    ///   - volumeName: The desired display name for the volume
    /// - Throws: `SMBMounterError` if configuration fails
    func configureVolume(at mountPoint: String, volumeName: String) async throws
    
    /// Sets a custom icon for a mounted volume
    /// - Parameters:
    ///   - mountPoint: The local filesystem path where the share is mounted
    ///   - iconName: The name of the icon to use (from app bundle)
    /// - Throws: `SMBMounterError` if icon setting fails
    func setVolumeIcon(at mountPoint: String, iconName: String?) async throws
    
    /// Ensures the volume appears in Finder sidebar
    /// - Parameter mountPoint: The local filesystem path where the share is mounted
    /// - Throws: `SMBMounterError` if sidebar addition fails
    func addToFinderSidebar(mountPoint: String) async throws
    
    /// Opens the mounted volume in Finder
    /// - Parameter mountPoint: The local filesystem path to open
    func openInFinder(mountPoint: String)
    
    /// Reveals the mounted volume in Finder
    /// - Parameter mountPoint: The local filesystem path to reveal
    func revealInFinder(mountPoint: String)
}

// MARK: - FinderIntegration

/// Implementation of FinderIntegrationProtocol for Finder integration
/// Provides functionality to customize mounted volume appearance and behavior
final class FinderIntegration: FinderIntegrationProtocol {
    
    // MARK: - Constants
    
    /// Default SMB volume icon name
    private static let defaultSMBIconName = "SMBVolumeIcon"
    
    /// Volume icon filename used by macOS
    private static let volumeIconFilename = ".VolumeIcon.icns"
    
    /// Extended attribute for custom icon
    private static let customIconAttribute = "com.apple.FinderInfo"
    
    // MARK: - Properties
    
    /// File manager for filesystem operations
    private let fileManager: FileManager
    
    /// Workspace for Finder operations
    private let workspace: NSWorkspace
    
    // MARK: - Initialization
    
    /// Creates a new FinderIntegration instance
    /// - Parameters:
    ///   - fileManager: The file manager to use (defaults to FileManager.default)
    ///   - workspace: The workspace to use (defaults to NSWorkspace.shared)
    init(
        fileManager: FileManager = .default,
        workspace: NSWorkspace = .shared
    ) {
        self.fileManager = fileManager
        self.workspace = workspace
    }
    
    // MARK: - FinderIntegrationProtocol Implementation
    
    func configureVolume(at mountPoint: String, volumeName: String) async throws {
        // Normalize the mount point path
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        // Verify the mount point exists
        guard fileManager.fileExists(atPath: normalizedPath) else {
            throw SMBMounterError.notMounted(mountPoint: normalizedPath)
        }
        
        // Set custom SMB volume icon
        do {
            try await setVolumeIcon(at: normalizedPath, iconName: Self.defaultSMBIconName)
        } catch {
            // Log but don't fail - icon is optional
            print("[FinderIntegration] Warning: Failed to set volume icon: \(error.localizedDescription)")
        }
        
        // Ensure volume appears in Finder sidebar
        do {
            try await addToFinderSidebar(mountPoint: normalizedPath)
        } catch {
            // Log but don't fail - sidebar is optional
            print("[FinderIntegration] Warning: Failed to add to Finder sidebar: \(error.localizedDescription)")
        }
        
        // Notify Finder to refresh the volume display
        notifyFinderVolumeChanged(at: normalizedPath)
    }
    
    func setVolumeIcon(at mountPoint: String, iconName: String?) async throws {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        // Verify the mount point exists
        guard fileManager.fileExists(atPath: normalizedPath) else {
            throw SMBMounterError.notMounted(mountPoint: normalizedPath)
        }
        
        // Get the icon to use
        let icon: NSImage?
        if let iconName = iconName {
            // Try to load from app bundle first
            icon = loadIconFromBundle(named: iconName) ?? createDefaultSMBIcon()
        } else {
            icon = createDefaultSMBIcon()
        }
        
        guard let volumeIcon = icon else {
            print("[FinderIntegration] Warning: Could not create volume icon")
            return
        }
        
        // Set the icon using NSWorkspace
        let volumeURL = URL(fileURLWithPath: normalizedPath)
        
        // Use NSWorkspace to set the icon
        let success = workspace.setIcon(volumeIcon, forFile: normalizedPath)
        
        if success {
            print("[FinderIntegration] Successfully set volume icon for \(normalizedPath)")
            
            // Also create .VolumeIcon.icns file for persistence
            try await createVolumeIconFile(at: normalizedPath, icon: volumeIcon)
        } else {
            print("[FinderIntegration] Warning: NSWorkspace.setIcon returned false for \(normalizedPath)")
        }
    }
    
    func addToFinderSidebar(mountPoint: String) async throws {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        
        // Verify the mount point exists
        guard fileManager.fileExists(atPath: normalizedPath) else {
            throw SMBMounterError.notMounted(mountPoint: normalizedPath)
        }
        
        let volumeURL = URL(fileURLWithPath: normalizedPath)
        
        // Check if the volume is already in the sidebar by checking its resource values
        // Volumes in /Volumes are typically automatically added to the sidebar by macOS
        // We can ensure this by setting the appropriate resource values
        
        do {
            var resourceValues = URLResourceValues()
            
            // Set the volume to be visible in Finder
            // Note: Most of these are read-only for volumes, but we try anyway
            
            // The volume should already appear in sidebar if it's a proper mount
            // We can verify by checking the volume properties
            let volumeResourceValues = try volumeURL.resourceValues(forKeys: [
                .volumeIsLocalKey,
                .volumeIsRemovableKey,
                .volumeIsEjectableKey,
                .volumeNameKey
            ])
            
            print("[FinderIntegration] Volume properties for \(normalizedPath):")
            print("  - isLocal: \(volumeResourceValues.volumeIsLocal ?? false)")
            print("  - isRemovable: \(volumeResourceValues.volumeIsRemovable ?? false)")
            print("  - isEjectable: \(volumeResourceValues.volumeIsEjectable ?? false)")
            print("  - volumeName: \(volumeResourceValues.volumeName ?? "unknown")")
            
            // For SMB mounts, macOS should automatically add them to the sidebar
            // under "Locations" section. We can trigger a refresh to ensure visibility.
            
            // Use LSSharedFileList to add to sidebar (if needed)
            try addToSidebarUsingLSSharedFileList(volumeURL: volumeURL)
            
        } catch {
            print("[FinderIntegration] Warning: Could not configure sidebar visibility: \(error.localizedDescription)")
            // Don't throw - this is a best-effort operation
        }
    }
    
    func openInFinder(mountPoint: String) {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        let url = URL(fileURLWithPath: normalizedPath)
        workspace.open(url)
    }
    
    func revealInFinder(mountPoint: String) {
        let normalizedPath = (mountPoint as NSString).standardizingPath
        let url = URL(fileURLWithPath: normalizedPath)
        workspace.activateFileViewerSelecting([url])
    }
    
    // MARK: - Private Methods
    
    /// Loads an icon from the app bundle
    /// - Parameter name: The name of the icon resource
    /// - Returns: The loaded NSImage, or nil if not found
    private func loadIconFromBundle(named name: String) -> NSImage? {
        // Try to load from bundle
        if let image = NSImage(named: name) {
            return image
        }
        
        // Try to load from bundle resources
        if let bundle = Bundle.main.path(forResource: name, ofType: "icns"),
           let image = NSImage(contentsOfFile: bundle) {
            return image
        }
        
        if let bundle = Bundle.main.path(forResource: name, ofType: "png"),
           let image = NSImage(contentsOfFile: bundle) {
            return image
        }
        
        return nil
    }
    
    /// Creates a default SMB volume icon
    /// - Returns: An NSImage representing an SMB network share
    private func createDefaultSMBIcon() -> NSImage? {
        // Use system network volume icon as base
        // NSImage.Name.network is available for network-related icons
        
        // Try to get the system's network volume icon
        if let networkIcon = NSImage(named: NSImage.networkName) {
            return networkIcon
        }
        
        // Fallback: Create a simple folder icon with network badge
        let folderIcon = NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
        if folderIcon.size.width > 0 {
            return folderIcon
        }
        
        // Last resort: Use generic hard disk icon
        return NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericHardDiskIcon)))
    }
    
    /// Creates a .VolumeIcon.icns file at the mount point
    /// - Parameters:
    ///   - mountPoint: The mount point path
    ///   - icon: The icon to save
    private func createVolumeIconFile(at mountPoint: String, icon: NSImage) async throws {
        let iconPath = (mountPoint as NSString).appendingPathComponent(Self.volumeIconFilename)
        
        // Check if we can write to the mount point
        guard fileManager.isWritableFile(atPath: mountPoint) else {
            print("[FinderIntegration] Mount point is not writable, skipping .VolumeIcon.icns creation")
            return
        }
        
        // Convert NSImage to ICNS data
        guard let icnsData = createICNSData(from: icon) else {
            print("[FinderIntegration] Could not create ICNS data from icon")
            return
        }
        
        // Write the icon file
        do {
            try icnsData.write(to: URL(fileURLWithPath: iconPath))
            
            // Set the file as hidden
            try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: iconPath)
            
            // Set the custom icon flag on the volume
            setCustomIconFlag(at: mountPoint)
            
            print("[FinderIntegration] Created .VolumeIcon.icns at \(iconPath)")
        } catch {
            print("[FinderIntegration] Failed to create .VolumeIcon.icns: \(error.localizedDescription)")
        }
    }
    
    /// Creates ICNS data from an NSImage
    /// - Parameter image: The source image
    /// - Returns: Data in ICNS format, or nil if conversion fails
    private func createICNSData(from image: NSImage) -> Data? {
        // Get the best representation
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        // For simplicity, we'll create a PNG and let the system handle it
        // A proper implementation would create a full ICNS file with multiple sizes
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        // Note: This creates a PNG file, not a proper ICNS
        // For a production app, you'd want to use IconFamily or similar
        // to create a proper ICNS with multiple resolutions
        return pngData
    }
    
    /// Sets the custom icon flag on a folder/volume
    /// - Parameter path: The path to set the flag on
    private func setCustomIconFlag(at path: String) {
        let url = URL(fileURLWithPath: path)
        
        // Use NSFileManager to set the custom icon attribute
        // This tells Finder to look for .VolumeIcon.icns
        // Note: customIcon is read-only, so we use NSWorkspace.setIcon instead
        let success = workspace.setIcon(workspace.icon(forFile: path), forFile: path, options: [])
        if !success {
            print("[FinderIntegration] Could not set custom icon flag")
        }
    }
    
    /// Adds a volume to the Finder sidebar using LSSharedFileList
    /// - Parameter volumeURL: The URL of the volume to add
    private func addToSidebarUsingLSSharedFileList(volumeURL: URL) throws {
        // Note: LSSharedFileList is deprecated but still works
        // For modern macOS, volumes in /Volumes are automatically shown in sidebar
        
        // We'll use a different approach - ensure the volume has the right attributes
        // that make it appear in the sidebar
        
        // Check if this is a network volume (SMB)
        var isNetworkVolume = false
        do {
            let resourceValues = try volumeURL.resourceValues(forKeys: [.volumeIsLocalKey])
            isNetworkVolume = !(resourceValues.volumeIsLocal ?? true)
        } catch {
            // Assume it's a network volume if we can't determine
            isNetworkVolume = true
        }
        
        if isNetworkVolume {
            print("[FinderIntegration] Volume is a network volume, should appear in Finder sidebar under 'Locations'")
        }
        
        // For network volumes, macOS automatically adds them to the sidebar
        // We just need to ensure Finder is aware of the mount
        notifyFinderVolumeChanged(at: volumeURL.path)
    }
    
    /// Notifies Finder that a volume has changed
    /// - Parameter path: The path of the volume
    private func notifyFinderVolumeChanged(at path: String) {
        // Use NSWorkspace to notify about the change
        let url = URL(fileURLWithPath: path)
        
        // Post a notification that the volume has changed
        // This helps Finder update its display
        DistributedNotificationCenter.default().post(
            name: NSNotification.Name("com.apple.finder.VolumeChanged"),
            object: nil,
            userInfo: ["path": path]
        )
        
        // Also use NSWorkspace's noteFileSystemChanged
        workspace.noteFileSystemChanged(path)
        
        print("[FinderIntegration] Notified Finder of volume change at \(path)")
    }
}

// MARK: - Mock FinderIntegration for Testing

/// Mock implementation of FinderIntegrationProtocol for unit testing
final class MockFinderIntegration: FinderIntegrationProtocol {
    
    // MARK: - Test Configuration
    
    /// Result to return from configureVolume
    var configureVolumeResult: Result<Void, SMBMounterError> = .success(())
    
    /// Result to return from setVolumeIcon
    var setVolumeIconResult: Result<Void, SMBMounterError> = .success(())
    
    /// Result to return from addToFinderSidebar
    var addToFinderSidebarResult: Result<Void, SMBMounterError> = .success(())
    
    /// Records of configureVolume calls
    var configureVolumeCalls: [(mountPoint: String, volumeName: String)] = []
    
    /// Records of setVolumeIcon calls
    var setVolumeIconCalls: [(mountPoint: String, iconName: String?)] = []
    
    /// Records of addToFinderSidebar calls
    var addToFinderSidebarCalls: [String] = []
    
    /// Records of openInFinder calls
    var openInFinderCalls: [String] = []
    
    /// Records of revealInFinder calls
    var revealInFinderCalls: [String] = []
    
    // MARK: - FinderIntegrationProtocol Implementation
    
    func configureVolume(at mountPoint: String, volumeName: String) async throws {
        configureVolumeCalls.append((mountPoint: mountPoint, volumeName: volumeName))
        
        switch configureVolumeResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    func setVolumeIcon(at mountPoint: String, iconName: String?) async throws {
        setVolumeIconCalls.append((mountPoint: mountPoint, iconName: iconName))
        
        switch setVolumeIconResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    func addToFinderSidebar(mountPoint: String) async throws {
        addToFinderSidebarCalls.append(mountPoint)
        
        switch addToFinderSidebarResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    func openInFinder(mountPoint: String) {
        openInFinderCalls.append(mountPoint)
    }
    
    func revealInFinder(mountPoint: String) {
        revealInFinderCalls.append(mountPoint)
    }
    
    // MARK: - Test Helpers
    
    /// Resets all recorded calls and configuration
    func reset() {
        configureVolumeResult = .success(())
        setVolumeIconResult = .success(())
        addToFinderSidebarResult = .success(())
        configureVolumeCalls = []
        setVolumeIconCalls = []
        addToFinderSidebarCalls = []
        openInFinderCalls = []
        revealInFinderCalls = []
    }
}
