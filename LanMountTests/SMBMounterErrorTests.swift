//
//  SMBMounterErrorTests.swift
//  LanMountTests
//
//  Unit tests for SMBMounterError
//

import XCTest
@testable import LanMountCore

final class SMBMounterErrorTests: XCTestCase {
    
    // MARK: - Error Description Tests
    
    func testNetworkUnreachableErrorDescription() {
        let error = SMBMounterError.networkUnreachable(server: "192.168.1.100")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("192.168.1.100"))
    }
    
    func testAuthenticationFailedErrorDescription() {
        let error = SMBMounterError.authenticationFailed(server: "server", share: "share")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("server"))
        XCTAssertTrue(error.errorDescription!.contains("share"))
    }
    
    func testMountPointExistsErrorDescription() {
        let error = SMBMounterError.mountPointExists(path: "/Volumes/Test")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("/Volumes/Test"))
    }
    
    func testInvalidURLErrorDescription() {
        let error = SMBMounterError.invalidURL(url: "invalid://url")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("invalid://url"))
    }
    
    func testKeychainAccessDeniedErrorDescription() {
        let error = SMBMounterError.keychainAccessDenied
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Keychain"))
    }
    
    func testKeychainItemNotFoundErrorDescription() {
        let error = SMBMounterError.keychainItemNotFound(identifier: "server/share")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("server/share"))
    }
    
    func testConfigurationReadFailedErrorDescription() {
        let error = SMBMounterError.configurationReadFailed(path: "/path/to/config")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("/path/to/config"))
    }
    
    func testScanTimeoutErrorDescription() {
        let error = SMBMounterError.scanTimeout
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("timeout") || error.errorDescription!.contains("timed out"))
    }
    
    func testSyncConflictErrorDescription() {
        let error = SMBMounterError.syncConflict(filePath: "/path/to/file.txt")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("/path/to/file.txt"))
    }
    
    func testCancelledErrorDescription() {
        let error = SMBMounterError.cancelled
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("cancelled"))
    }
    
    // MARK: - Failure Reason Tests
    
    func testFailureReasonNotNil() {
        let errors: [SMBMounterError] = [
            .networkUnreachable(server: "server"),
            .authenticationFailed(server: "server", share: "share"),
            .mountPointExists(path: "/path"),
            .keychainAccessDenied,
            .scanTimeout,
            .syncConflict(filePath: "/file"),
            .cancelled
        ]
        
        for error in errors {
            XCTAssertNotNil(error.failureReason, "Failure reason should not be nil for \(error)")
        }
    }
    
    // MARK: - Recovery Suggestion Tests
    
    func testRecoverySuggestionForNetworkUnreachable() {
        let error = SMBMounterError.networkUnreachable(server: "server")
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    func testRecoverySuggestionForAuthenticationFailed() {
        let error = SMBMounterError.authenticationFailed(server: "server", share: "share")
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    func testRecoverySuggestionForMountPointExists() {
        let error = SMBMounterError.mountPointExists(path: "/path")
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    func testRecoverySuggestionForKeychainAccessDenied() {
        let error = SMBMounterError.keychainAccessDenied
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    func testRecoverySuggestionForScanTimeout() {
        let error = SMBMounterError.scanTimeout
        XCTAssertNotNil(error.recoverySuggestion)
    }
    
    // MARK: - Equatable Tests
    
    func testErrorEquatable() {
        let error1 = SMBMounterError.networkUnreachable(server: "server")
        let error2 = SMBMounterError.networkUnreachable(server: "server")
        let error3 = SMBMounterError.networkUnreachable(server: "other")
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
    
    func testDifferentErrorTypesNotEqual() {
        let error1 = SMBMounterError.networkUnreachable(server: "server")
        let error2 = SMBMounterError.authenticationFailed(server: "server", share: "share")
        
        XCTAssertNotEqual(error1, error2)
    }
    
    // MARK: - OSStatus Conversion Tests
    
    func testFromOSStatusKeychainAccessDenied() {
        let error = SMBMounterError.fromOSStatus(-25291, context: "test")
        XCTAssertEqual(error, .keychainAccessDenied)
    }
    
    func testFromOSStatusItemNotFound() {
        let error = SMBMounterError.fromOSStatus(-25300, context: "server/share")
        XCTAssertEqual(error, .keychainItemNotFound(identifier: "server/share"))
    }
    
    func testFromOSStatusDuplicateItem() {
        let error = SMBMounterError.fromOSStatus(-25299, context: "test")
        if case .keychainSaveFailed(let reason) = error {
            XCTAssertTrue(reason.contains("exists"))
        } else {
            XCTFail("Expected keychainSaveFailed error")
        }
    }
    
    func testFromOSStatusUnknown() {
        let error = SMBMounterError.fromOSStatus(-99999, context: "test")
        if case .keychainError(let status) = error {
            XCTAssertEqual(status, -99999)
        } else {
            XCTFail("Expected keychainError")
        }
    }
}
