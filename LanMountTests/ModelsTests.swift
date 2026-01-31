//
//  ModelsTests.swift
//  LanMountTests
//
//  Unit tests for core data models
//

import XCTest
@testable import LanMountCore

final class ModelsTests: XCTestCase {
    
    // MARK: - MountedVolume Tests
    
    func testMountedVolumeCreation() {
        let volume = MountedVolume(
            server: "192.168.1.100",
            share: "Documents",
            mountPoint: "/Volumes/Documents"
        )
        
        XCTAssertEqual(volume.server, "192.168.1.100")
        XCTAssertEqual(volume.share, "Documents")
        XCTAssertEqual(volume.mountPoint, "/Volumes/Documents")
        XCTAssertEqual(volume.volumeName, "Documents")
        XCTAssertEqual(volume.status, .disconnected)
        XCTAssertEqual(volume.smbURL, "smb://192.168.1.100/Documents")
    }
    
    func testMountedVolumeUsagePercentage() {
        var volume = MountedVolume(
            server: "server",
            share: "share",
            mountPoint: "/Volumes/share",
            bytesUsed: 500,
            bytesTotal: 1000
        )
        
        XCTAssertEqual(volume.usagePercentage, 50.0)
        
        volume.bytesTotal = -1
        XCTAssertNil(volume.usagePercentage)
    }
    
    // MARK: - Credentials Tests
    
    func testCredentialsCreation() {
        let creds = Credentials(username: "user", password: "pass")
        XCTAssertEqual(creds.username, "user")
        XCTAssertEqual(creds.password, "pass")
        XCTAssertNil(creds.domain)
        XCTAssertEqual(creds.fullUsername, "user")
    }
    
    func testCredentialsWithDomain() {
        let creds = Credentials(username: "user", password: "pass", domain: "WORKGROUP")
        XCTAssertEqual(creds.fullUsername, "WORKGROUP\\user")
    }
    
    // MARK: - MountConfiguration Tests
    
    func testMountConfigurationCreation() {
        let config = MountConfiguration(
            server: "nas.local",
            share: "Media"
        )
        
        XCTAssertEqual(config.server, "nas.local")
        XCTAssertEqual(config.share, "Media")
        XCTAssertEqual(config.mountPoint, "/Volumes/Media")
        XCTAssertFalse(config.autoMount)
        XCTAssertFalse(config.rememberCredentials)
        XCTAssertFalse(config.syncEnabled)
        XCTAssertEqual(config.smbURL, "smb://nas.local/Media")
        XCTAssertEqual(config.keychainIdentifier, "nas.local/Media")
    }
    
    func testMountConfigurationCodable() throws {
        let config = MountConfiguration(
            server: "server",
            share: "share",
            autoMount: true,
            rememberCredentials: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MountConfiguration.self, from: data)
        
        XCTAssertEqual(config.id, decoded.id)
        XCTAssertEqual(config.server, decoded.server)
        XCTAssertEqual(config.share, decoded.share)
        XCTAssertEqual(config.autoMount, decoded.autoMount)
        XCTAssertEqual(config.rememberCredentials, decoded.rememberCredentials)
    }
    
    // MARK: - DiscoveredService Tests
    
    func testDiscoveredServiceCreation() {
        let service = DiscoveredService(
            name: "NAS Server",
            hostname: "nas.local",
            ipAddress: "192.168.1.50",
            port: 445,
            shares: ["Documents", "Media"]
        )
        
        XCTAssertEqual(service.name, "NAS Server")
        XCTAssertEqual(service.hostname, "nas.local")
        XCTAssertEqual(service.ipAddress, "192.168.1.50")
        XCTAssertEqual(service.port, 445)
        XCTAssertEqual(service.shares.count, 2)
        XCTAssertEqual(service.smbURL, "smb://192.168.1.50")
    }
    
    // MARK: - MountResult Tests
    
    func testMountResultSuccess() {
        let result = MountResult.success(mountPoint: "/Volumes/Test", volumeName: "Test")
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.mountPoint, "/Volumes/Test")
        XCTAssertEqual(result.volumeName, "Test")
        XCTAssertNil(result.error)
    }
    
    func testMountResultFailure() {
        let error = SMBMounterError.networkUnreachable(server: "server")
        let result = MountResult.failure(error)
        
        XCTAssertFalse(result.success)
        XCTAssertNil(result.mountPoint)
        XCTAssertNil(result.volumeName)
        XCTAssertEqual(result.error, error)
    }
    
    // MARK: - ConflictInfo Tests
    
    func testConflictInfoCreation() {
        let now = Date()
        let earlier = now.addingTimeInterval(-3600)
        
        let conflict = ConflictInfo(
            filePath: "/path/to/file.txt",
            localModifiedAt: now,
            remoteModifiedAt: earlier,
            localSize: 1024,
            remoteSize: 2048
        )
        
        XCTAssertEqual(conflict.fileName, "file.txt")
        XCTAssertEqual(conflict.timeDifference, 3600, accuracy: 1)
        XCTAssertEqual(conflict.sizeDifference, 1024)
    }
    
    // MARK: - MountStatus Tests
    
    func testMountStatusCodable() throws {
        let statuses: [MountStatus] = [
            .connected,
            .disconnected,
            .connecting,
            .error("Test error")
        ]
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for status in statuses {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(MountStatus.self, from: data)
            XCTAssertEqual(status, decoded)
        }
    }
    
    // MARK: - AppSettings Tests
    
    func testAppSettingsDefault() {
        let settings = AppSettings.default
        
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertTrue(settings.autoReconnect)
        XCTAssertTrue(settings.notificationsEnabled)
        XCTAssertEqual(settings.scanInterval, 300)
        XCTAssertEqual(settings.logLevel, .info)
    }
    
    func testAppSettingsCodable() throws {
        let settings = AppSettings(
            launchAtLogin: true,
            autoReconnect: false,
            notificationsEnabled: true,
            scanInterval: 600,
            logLevel: .debug
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSettings.self, from: data)
        
        XCTAssertEqual(settings, decoded)
    }
}
