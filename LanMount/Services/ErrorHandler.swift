//
//  ErrorHandler.swift
//  LanMount
//
//  Centralized error handling with localization, retry logic, and logging
//  Requirements: 10.1, 10.2
//

import Foundation

// MARK: - ErrorHandlerProtocol

/// Protocol defining the interface for centralized error handling
/// Provides error localization, retry logic, and logging capabilities
protocol ErrorHandlerProtocol {
    /// Gets a user-friendly localized description for an error
    /// - Parameter error: The error to describe
    /// - Returns: A localized, user-friendly error message
    func localizedDescription(for error: Error) -> String
    
    /// Gets a brief title for an error suitable for alert dialogs
    /// - Parameter error: The error to get a title for
    /// - Returns: A localized error title
    func errorTitle(for error: Error) -> String
    
    /// Gets a recovery suggestion for an error
    /// - Parameter error: The error to get a suggestion for
    /// - Returns: A localized recovery suggestion, or nil if none available
    func recoverySuggestion(for error: Error) -> String?
    
    /// Handles an error by logging it and optionally showing user notification
    /// - Parameters:
    ///   - error: The error to handle
    ///   - operation: Description of the operation that failed
    ///   - component: The component where the error occurred
    ///   - showNotification: Whether to show a user notification
    func handle(error: Error, operation: String, component: String, showNotification: Bool)
    
    /// Executes an async operation with retry logic for network errors
    /// - Parameters:
    ///   - operation: The async operation to execute
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    ///   - baseDelay: Base delay in seconds for exponential backoff (default: 1.0)
    ///   - operationName: Name of the operation for logging
    ///   - component: The component performing the operation
    /// - Returns: The result of the operation
    /// - Throws: The last error if all retries fail
    func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        maxRetries: Int,
        baseDelay: TimeInterval,
        operationName: String,
        component: String
    ) async throws -> T
    
    /// Determines if an error is retryable (network-related)
    /// - Parameter error: The error to check
    /// - Returns: True if the error is retryable
    func isRetryable(error: Error) -> Bool
}

// MARK: - Default Protocol Extension

extension ErrorHandlerProtocol {
    /// Executes with default retry parameters (3 retries, 1 second base delay)
    func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        operationName: String,
        component: String
    ) async throws -> T {
        return try await executeWithRetry(
            operation: operation,
            maxRetries: 3,
            baseDelay: 1.0,
            operationName: operationName,
            component: component
        )
    }
}

// MARK: - ErrorHandler

/// Centralized error handling implementation
/// Features:
/// - Localized error messages for all SMBMounterError types
/// - Retry logic with exponential backoff for network errors
/// - Integration with Logger for error logging
/// - User-friendly error descriptions
final class ErrorHandler: ErrorHandlerProtocol {
    
    // MARK: - Constants
    
    /// Default maximum number of retries for network operations
    static let defaultMaxRetries = 3
    
    /// Default base delay for exponential backoff (in seconds)
    static let defaultBaseDelay: TimeInterval = 1.0
    
    /// Maximum delay cap for exponential backoff (in seconds)
    static let maxDelay: TimeInterval = 30.0
    
    // MARK: - Properties
    
    /// Logger instance for error logging
    private let logger: LoggerProtocol
    
    /// Notification handler for showing user notifications
    private var notificationHandler: ((String, String) -> Void)?
    
    // MARK: - Singleton
    
    /// Shared error handler instance
    static let shared = ErrorHandler()
    
    // MARK: - Initialization
    
    /// Creates a new ErrorHandler instance
    /// - Parameters:
    ///   - logger: Logger to use for error logging (defaults to Logger.shared)
    ///   - notificationHandler: Optional handler for showing notifications
    init(logger: LoggerProtocol = Logger.shared, notificationHandler: ((String, String) -> Void)? = nil) {
        self.logger = logger
        self.notificationHandler = notificationHandler
    }
    
    /// Sets the notification handler
    /// - Parameter handler: Handler that receives (title, body) for notifications
    func setNotificationHandler(_ handler: @escaping (String, String) -> Void) {
        self.notificationHandler = handler
    }
    
    // MARK: - ErrorHandlerProtocol Implementation
    
    func localizedDescription(for error: Error) -> String {
        if let smbError = error as? SMBMounterError {
            return smbError.errorDescription ?? genericErrorMessage(for: error)
        }
        
        // Handle NSError with localized description
        if let nsError = error as NSError? {
            return nsError.localizedDescription
        }
        
        return genericErrorMessage(for: error)
    }
    
    func errorTitle(for error: Error) -> String {
        if let smbError = error as? SMBMounterError {
            return smbError.failureReason ?? NSLocalizedString("Error", comment: "Generic error title")
        }
        
        return NSLocalizedString("Error", comment: "Generic error title")
    }
    
    func recoverySuggestion(for error: Error) -> String? {
        if let smbError = error as? SMBMounterError {
            return smbError.recoverySuggestion ?? defaultRecoverySuggestion(for: smbError)
        }
        
        return nil
    }
    
    func handle(error: Error, operation: String, component: String, showNotification: Bool = true) {
        // Log the error
        logError(error, operation: operation, component: component)
        
        // Show notification if requested
        if showNotification, let handler = notificationHandler {
            let title = errorTitle(for: error)
            let body = localizedDescription(for: error)
            handler(title, body)
        }
    }
    
    func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        maxRetries: Int = defaultMaxRetries,
        baseDelay: TimeInterval = defaultBaseDelay,
        operationName: String,
        component: String
    ) async throws -> T {
        var lastError: Error?
        var attempt = 0
        
        while attempt <= maxRetries {
            do {
                // Attempt the operation
                let result = try await operation()
                
                // Log success if this was a retry
                if attempt > 0 {
                    logger.info(
                        "Operation '\(operationName)' succeeded after \(attempt) retry(ies)",
                        component: component
                    )
                }
                
                return result
                
            } catch {
                lastError = error
                
                // Check if we should retry
                if attempt < maxRetries && isRetryable(error: error) {
                    // Calculate delay with exponential backoff
                    let delay = calculateBackoffDelay(attempt: attempt, baseDelay: baseDelay)
                    
                    logger.warning(
                        "Operation '\(operationName)' failed (attempt \(attempt + 1)/\(maxRetries + 1)): \(localizedDescription(for: error)). Retrying in \(String(format: "%.1f", delay))s...",
                        component: component
                    )
                    
                    // Wait before retrying
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                    attempt += 1
                } else {
                    // Not retryable or max retries reached
                    if attempt >= maxRetries {
                        logger.error(
                            "Operation '\(operationName)' failed after \(maxRetries + 1) attempt(s): \(localizedDescription(for: error))",
                            component: component
                        )
                    } else {
                        logger.error(
                            "Operation '\(operationName)' failed (non-retryable): \(localizedDescription(for: error))",
                            component: component
                        )
                    }
                    break
                }
            }
        }
        
        throw lastError ?? SMBMounterError.unknown(message: "Operation failed with unknown error")
    }
    
    func isRetryable(error: Error) -> Bool {
        if let smbError = error as? SMBMounterError {
            return isRetryableSMBError(smbError)
        }
        
        // Check for common network-related NSError codes
        if let nsError = error as NSError? {
            return isRetryableNSError(nsError)
        }
        
        return false
    }
    
    // MARK: - Private Methods - Error Classification
    
    /// Determines if an SMBMounterError is retryable
    private func isRetryableSMBError(_ error: SMBMounterError) -> Bool {
        switch error {
        // Network errors are retryable
        case .networkUnreachable,
             .mountTimeout,
             .scanTimeout,
             .networkInterfaceUnavailable,
             .serviceResolutionFailed:
            return true
            
        // Mount operation failures may be retryable (transient issues)
        case .mountOperationFailed:
            return true
            
        // Volume status check failures may be transient
        case .volumeStatusCheckFailed:
            return true
            
        // Sync failures may be transient
        case .syncFailed:
            return true
            
        // Authentication errors should NOT be retried (avoid account lockout)
        case .authenticationFailed:
            return false
            
        // Permission errors should NOT be retried
        case .permissionDenied,
             .keychainAccessDenied:
            return false
            
        // Configuration errors should NOT be retried
        case .configurationReadFailed,
             .configurationWriteFailed,
             .invalidConfiguration,
             .configurationNotFound,
             .configurationDirectoryCreationFailed:
            return false
            
        // Keychain errors (except access denied) should NOT be retried
        case .keychainItemNotFound,
             .keychainSaveFailed,
             .keychainUpdateFailed,
             .keychainDeleteFailed,
             .keychainError:
            return false
            
        // Mount point errors should NOT be retried
        case .mountPointExists,
             .mountPointCreationFailed,
             .notMounted,
             .unmountFailed:
            return false
            
        // Invalid input should NOT be retried
        case .invalidURL,
             .invalidInput:
            return false
            
        // Share not found should NOT be retried
        case .shareNotFound:
            return false
            
        // Scanner initialization should NOT be retried
        case .scannerInitializationFailed:
            return false
            
        // Sync conflicts require user intervention
        case .syncConflict:
            return false
            
        // File monitoring failures should NOT be retried
        case .fileMonitoringFailed,
             .syncReadFailed,
             .syncWriteFailed:
            return false
            
        // Volume monitoring failures should NOT be retried
        case .volumeMonitoringFailed:
            return false
            
        // Launch agent errors should NOT be retried
        case .launchAgentRegistrationFailed,
             .launchAgentUnregistrationFailed:
            return false
            
        // Cancelled operations should NOT be retried
        case .cancelled:
            return false
            
        // Unknown errors - don't retry by default
        case .unknown:
            return false
        }
    }
    
    /// Determines if an NSError is retryable based on domain and code
    private func isRetryableNSError(_ error: NSError) -> Bool {
        // Network-related error domains
        let networkDomains = [
            NSURLErrorDomain,
            "NSPOSIXErrorDomain",
            "kCFErrorDomainCFNetwork"
        ]
        
        if networkDomains.contains(error.domain) {
            // Common retryable network error codes
            let retryableCodes = [
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorDNSLookupFailed,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorSecureConnectionFailed
            ]
            
            return retryableCodes.contains(error.code)
        }
        
        return false
    }
    
    // MARK: - Private Methods - Backoff Calculation
    
    /// Calculates the delay for exponential backoff
    /// - Parameters:
    ///   - attempt: Current attempt number (0-based)
    ///   - baseDelay: Base delay in seconds
    /// - Returns: Delay in seconds with jitter
    private func calculateBackoffDelay(attempt: Int, baseDelay: TimeInterval) -> TimeInterval {
        // Exponential backoff: baseDelay * 2^attempt
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        
        // Cap at maximum delay
        let cappedDelay = min(exponentialDelay, Self.maxDelay)
        
        // Add jitter (±25%) to prevent thundering herd
        let jitterRange = cappedDelay * 0.25
        let jitter = Double.random(in: -jitterRange...jitterRange)
        
        return max(0.1, cappedDelay + jitter)
    }
    
    // MARK: - Private Methods - Logging
    
    /// Logs an error with full context
    private func logError(_ error: Error, operation: String, component: String) {
        let errorDescription = localizedDescription(for: error)
        let errorType = String(describing: type(of: error))
        
        // Build detailed log message
        var logMessage = "Operation '\(operation)' failed"
        logMessage += " | Error Type: \(errorType)"
        logMessage += " | Description: \(errorDescription)"
        
        // Add recovery suggestion if available
        if let suggestion = recoverySuggestion(for: error) {
            logMessage += " | Suggestion: \(suggestion)"
        }
        
        // Add underlying error info for NSError
        if let nsError = error as NSError? {
            logMessage += " | Domain: \(nsError.domain)"
            logMessage += " | Code: \(nsError.code)"
            
            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                logMessage += " | Underlying: \(underlyingError.localizedDescription)"
            }
        }
        
        logger.error(logMessage, component: component)
    }
    
    // MARK: - Private Methods - Default Messages
    
    /// Returns a generic error message for unknown errors
    private func genericErrorMessage(for error: Error) -> String {
        return String(format: NSLocalizedString(
            "An error occurred: %@",
            comment: "Generic error message"
        ), error.localizedDescription)
    }
    
    /// Returns a default recovery suggestion for SMBMounterError types
    private func defaultRecoverySuggestion(for error: SMBMounterError) -> String? {
        switch error {
        case .mountOperationFailed:
            return NSLocalizedString(
                "Try again later or check if the server is available.",
                comment: "Recovery suggestion"
            )
            
        case .syncFailed:
            return NSLocalizedString(
                "Check your network connection and try syncing again.",
                comment: "Recovery suggestion"
            )
            
        case .volumeStatusCheckFailed:
            return NSLocalizedString(
                "The volume may have been disconnected. Try remounting.",
                comment: "Recovery suggestion"
            )
            
        case .configurationReadFailed, .configurationWriteFailed:
            return NSLocalizedString(
                "Check file permissions and available disk space.",
                comment: "Recovery suggestion"
            )
            
        case .keychainSaveFailed, .keychainUpdateFailed:
            return NSLocalizedString(
                "Try saving the credentials again or check Keychain Access.",
                comment: "Recovery suggestion"
            )
            
        case .unmountFailed:
            return NSLocalizedString(
                "Close any applications using files on this volume and try again.",
                comment: "Recovery suggestion"
            )
            
        case .syncConflict:
            return NSLocalizedString(
                "Review the conflicting files and choose which version to keep.",
                comment: "Recovery suggestion"
            )
            
        default:
            return nil
        }
    }
}

// MARK: - ErrorHandler Extension for Convenience Methods

extension ErrorHandler {
    
    /// Handles an SMBMounterError with automatic component detection
    /// - Parameters:
    ///   - error: The SMBMounterError to handle
    ///   - operation: Description of the operation that failed
    func handleSMBError(_ error: SMBMounterError, operation: String) {
        let component = componentForError(error)
        handle(error: error, operation: operation, component: component, showNotification: true)
    }
    
    /// Determines the appropriate component for an error type
    private func componentForError(_ error: SMBMounterError) -> String {
        switch error {
        case .networkUnreachable, .authenticationFailed, .mountPointExists,
             .mountPointCreationFailed, .permissionDenied, .invalidURL,
             .mountOperationFailed, .shareNotFound, .mountTimeout,
             .notMounted, .unmountFailed:
            return Logger.Component.mountManager
            
        case .keychainAccessDenied, .keychainItemNotFound, .keychainSaveFailed,
             .keychainUpdateFailed, .keychainDeleteFailed, .keychainError:
            return Logger.Component.credentialManager
            
        case .configurationReadFailed, .configurationWriteFailed,
             .invalidConfiguration, .configurationNotFound,
             .configurationDirectoryCreationFailed:
            return Logger.Component.configurationStore
            
        case .scannerInitializationFailed, .scanTimeout,
             .serviceResolutionFailed, .networkInterfaceUnavailable:
            return Logger.Component.networkScanner
            
        case .syncConflict, .syncFailed, .fileMonitoringFailed,
             .syncReadFailed, .syncWriteFailed:
            return Logger.Component.syncEngine
            
        case .volumeMonitoringFailed, .volumeStatusCheckFailed:
            return Logger.Component.volumeMonitor
            
        case .launchAgentRegistrationFailed, .launchAgentUnregistrationFailed:
            return Logger.Component.launchAgent
            
        case .unknown, .cancelled, .invalidInput:
            return Logger.Component.app
        }
    }
    
    /// Creates an error result with full context for display
    /// - Parameter error: The error to create a result for
    /// - Returns: A tuple containing title, description, and optional suggestion
    func errorDisplayInfo(for error: Error) -> (title: String, description: String, suggestion: String?) {
        return (
            title: errorTitle(for: error),
            description: localizedDescription(for: error),
            suggestion: recoverySuggestion(for: error)
        )
    }
    
    /// Wraps an async operation with error handling
    /// - Parameters:
    ///   - operation: The async operation to execute
    ///   - operationName: Name of the operation for logging
    ///   - component: The component performing the operation
    ///   - onError: Optional callback when an error occurs
    /// - Returns: The result of the operation, or nil if it failed
    func executeWithErrorHandling<T>(
        operation: @escaping () async throws -> T,
        operationName: String,
        component: String,
        onError: ((Error) -> Void)? = nil
    ) async -> T? {
        do {
            return try await operation()
        } catch {
            handle(error: error, operation: operationName, component: component, showNotification: true)
            onError?(error)
            return nil
        }
    }
}

// MARK: - Global Error Handling Functions

/// Handles an error using the shared ErrorHandler
/// - Parameters:
///   - error: The error to handle
///   - operation: Description of the operation that failed
///   - component: The component where the error occurred
func handleError(_ error: Error, operation: String, component: String) {
    ErrorHandler.shared.handle(error: error, operation: operation, component: component, showNotification: true)
}

/// Executes an async operation with retry logic using the shared ErrorHandler
/// - Parameters:
///   - operation: The async operation to execute
///   - operationName: Name of the operation for logging
///   - component: The component performing the operation
/// - Returns: The result of the operation
/// - Throws: The last error if all retries fail
func executeWithRetry<T>(
    operation: @escaping () async throws -> T,
    operationName: String,
    component: String
) async throws -> T {
    return try await ErrorHandler.shared.executeWithRetry(
        operation: operation,
        operationName: operationName,
        component: component
    )
}

/// Gets a user-friendly error description using the shared ErrorHandler
/// - Parameter error: The error to describe
/// - Returns: A localized, user-friendly error message
func localizedErrorDescription(_ error: Error) -> String {
    return ErrorHandler.shared.localizedDescription(for: error)
}
