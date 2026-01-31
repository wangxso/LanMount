//
//  Logger.swift
//  LanMount
//
//  Provides logging functionality with file rotation, compression, and sensitive data filtering
//  Requirements: 10.2, 10.3, 10.5
//

import Foundation
import Compression

// MARK: - LoggerProtocol

/// Protocol defining the interface for logging operations
/// Supports multiple log levels, component-based logging, and file persistence
protocol LoggerProtocol {
    /// The current minimum log level (messages below this level are ignored)
    var logLevel: LogLevel { get set }
    
    /// Logs a debug message
    /// - Parameters:
    ///   - message: The message to log
    ///   - component: The component/module generating the log
    func debug(_ message: String, component: String)
    
    /// Logs an info message
    /// - Parameters:
    ///   - message: The message to log
    ///   - component: The component/module generating the log
    func info(_ message: String, component: String)
    
    /// Logs a warning message
    /// - Parameters:
    ///   - message: The message to log
    ///   - component: The component/module generating the log
    func warning(_ message: String, component: String)
    
    /// Logs an error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - component: The component/module generating the log
    func error(_ message: String, component: String)
    
    /// Logs an error with associated Error object
    /// - Parameters:
    ///   - message: The message to log
    ///   - error: The error object
    ///   - component: The component/module generating the log
    func error(_ message: String, error: Error, component: String)
    
    /// Forces a flush of any buffered log entries to disk
    func flush()
}

// MARK: - Logger

/// Implementation of LoggerProtocol with file-based logging
/// Features:
/// - Log rotation: max 10MB per file, keeps 5 files
/// - Compression of rotated logs
/// - Sensitive data filtering (passwords, credentials)
/// - Thread-safe logging
final class Logger: LoggerProtocol {
    
    // MARK: - Types
    
    /// Represents a single log entry
    private struct LogEntry {
        let timestamp: Date
        let level: LogLevel
        let component: String
        let message: String
        
        /// Formats the log entry as a string
        /// Format: [timestamp] [level] [component] message
        func formatted(dateFormatter: DateFormatter) -> String {
            let timestampStr = dateFormatter.string(from: timestamp)
            let levelStr = level.rawValue.uppercased().padding(toLength: 7, withPad: " ", startingAt: 0)
            return "[\(timestampStr)] [\(levelStr)] [\(component)] \(message)"
        }
    }
    
    // MARK: - Constants
    
    /// Log directory name within ~/Library/Logs/
    private static let logDirectoryName = "SMBMounter"
    
    /// Base name for log files
    private static let logFileName = "smb-mounter.log"
    
    /// Maximum size of a single log file in bytes (10MB)
    private static let maxLogFileSize: UInt64 = 10 * 1024 * 1024
    
    /// Maximum number of log files to keep (including current)
    private static let maxLogFiles = 5
    
    /// Buffer size before auto-flush
    private static let bufferFlushThreshold = 50
    
    /// Patterns to detect sensitive information
    private static let sensitivePatterns: [(pattern: String, replacement: String)] = [
        // Password patterns
        ("password\\s*[:=]\\s*[\"']?[^\"'\\s]+[\"']?", "password: [REDACTED]"),
        ("pwd\\s*[:=]\\s*[\"']?[^\"'\\s]+[\"']?", "pwd: [REDACTED]"),
        // Credential patterns in URLs (smb://user:password@server)
        ("smb://[^:]+:[^@]+@", "smb://[CREDENTIALS]@"),
        // Generic secret patterns
        ("secret\\s*[:=]\\s*[\"']?[^\"'\\s]+[\"']?", "secret: [REDACTED]"),
        ("token\\s*[:=]\\s*[\"']?[^\"'\\s]+[\"']?", "token: [REDACTED]"),
        ("api[_-]?key\\s*[:=]\\s*[\"']?[^\"'\\s]+[\"']?", "api_key: [REDACTED]"),
    ]
    
    // MARK: - Properties
    
    /// Current minimum log level
    var logLevel: LogLevel
    
    /// File manager for file system operations
    private let fileManager: FileManager
    
    /// Date formatter for timestamps
    private let dateFormatter: DateFormatter
    
    /// Lock for thread-safe access
    private let lock = NSLock()
    
    /// Buffer for log entries before writing to disk
    private var buffer: [LogEntry] = []
    
    /// File handle for the current log file
    private var fileHandle: FileHandle?
    
    /// Current log file size
    private var currentFileSize: UInt64 = 0
    
    /// Compiled regex patterns for sensitive data detection
    private var sensitiveRegexes: [(regex: NSRegularExpression, replacement: String)] = []
    
    // MARK: - Computed Properties
    
    /// Path to the logs directory
    private var logsDirectory: URL {
        let paths = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)
        return paths[0]
            .appendingPathComponent("Logs")
            .appendingPathComponent(Self.logDirectoryName)
    }
    
    /// Path to the current log file
    private var currentLogFilePath: URL {
        return logsDirectory.appendingPathComponent(Self.logFileName)
    }
    
    // MARK: - Singleton
    
    /// Shared logger instance
    static let shared = Logger()
    
    // MARK: - Initialization
    
    /// Creates a new Logger instance
    /// - Parameters:
    ///   - logLevel: Initial log level (defaults to .info)
    ///   - fileManager: File manager to use (defaults to FileManager.default)
    init(logLevel: LogLevel = .info, fileManager: FileManager = .default) {
        self.logLevel = logLevel
        self.fileManager = fileManager
        
        // Configure date formatter for log timestamps
        self.dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        
        // Compile sensitive data regex patterns
        compileSensitivePatterns()
        
        // Initialize log file
        initializeLogFile()
    }
    
    deinit {
        flush()
        closeFileHandle()
    }
    
    // MARK: - LoggerProtocol Implementation
    
    func debug(_ message: String, component: String) {
        log(level: .debug, message: message, component: component)
    }
    
    func info(_ message: String, component: String) {
        log(level: .info, message: message, component: component)
    }
    
    func warning(_ message: String, component: String) {
        log(level: .warning, message: message, component: component)
    }
    
    func error(_ message: String, component: String) {
        log(level: .error, message: message, component: component)
    }
    
    func error(_ message: String, error: Error, component: String) {
        let fullMessage = "\(message): \(error.localizedDescription)"
        log(level: .error, message: fullMessage, component: component)
    }
    
    func flush() {
        lock.lock()
        defer { lock.unlock() }
        
        flushBuffer()
    }
    
    // MARK: - Private Methods - Core Logging
    
    /// Core logging method
    /// - Parameters:
    ///   - level: The log level
    ///   - message: The message to log
    ///   - component: The component generating the log
    private func log(level: LogLevel, message: String, component: String) {
        // Check if this level should be logged
        guard level.level >= logLevel.level else { return }
        
        // Sanitize the message to remove sensitive information
        let sanitizedMessage = sanitizeMessage(message)
        
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            component: component,
            message: sanitizedMessage
        )
        
        lock.lock()
        defer { lock.unlock() }
        
        // Add to buffer
        buffer.append(entry)
        
        // Also print to console in debug builds
        #if DEBUG
        print(entry.formatted(dateFormatter: dateFormatter))
        #endif
        
        // Flush if buffer is full or if it's an error
        if buffer.count >= Self.bufferFlushThreshold || level == .error {
            flushBuffer()
        }
    }
    
    /// Flushes the buffer to disk (must be called with lock held)
    private func flushBuffer() {
        guard !buffer.isEmpty else { return }
        
        // Ensure log file is ready
        ensureLogFileReady()
        
        guard let handle = fileHandle else {
            buffer.removeAll()
            return
        }
        
        // Format all entries
        let lines = buffer.map { $0.formatted(dateFormatter: dateFormatter) + "\n" }
        let content = lines.joined()
        
        guard let data = content.data(using: .utf8) else {
            buffer.removeAll()
            return
        }
        
        // Write to file
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            currentFileSize += UInt64(data.count)
            
            // Check if rotation is needed
            if currentFileSize >= Self.maxLogFileSize {
                rotateLogFiles()
            }
        } catch {
            // If writing fails, just clear the buffer to prevent memory buildup
            #if DEBUG
            print("[Logger] Failed to write to log file: \(error)")
            #endif
        }
        
        buffer.removeAll()
    }
    
    // MARK: - Private Methods - Sensitive Data Filtering
    
    /// Compiles regex patterns for sensitive data detection
    private func compileSensitivePatterns() {
        for (pattern, replacement) in Self.sensitivePatterns {
            do {
                let regex = try NSRegularExpression(
                    pattern: pattern,
                    options: [.caseInsensitive]
                )
                sensitiveRegexes.append((regex, replacement))
            } catch {
                #if DEBUG
                print("[Logger] Failed to compile regex pattern: \(pattern)")
                #endif
            }
        }
    }
    
    /// Sanitizes a message by removing sensitive information
    /// - Parameter message: The original message
    /// - Returns: The sanitized message with sensitive data redacted
    private func sanitizeMessage(_ message: String) -> String {
        var result = message
        
        for (regex, replacement) in sensitiveRegexes {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: replacement
            )
        }
        
        return result
    }
    
    // MARK: - Private Methods - File Management
    
    /// Initializes the log file and directory
    private func initializeLogFile() {
        lock.lock()
        defer { lock.unlock() }
        
        ensureLogFileReady()
    }
    
    /// Ensures the log directory and file are ready for writing (must be called with lock held)
    private func ensureLogFileReady() {
        // Create logs directory if needed
        let directoryPath = logsDirectory.path
        if !fileManager.fileExists(atPath: directoryPath) {
            do {
                try fileManager.createDirectory(
                    at: logsDirectory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o755]
                )
            } catch {
                #if DEBUG
                print("[Logger] Failed to create logs directory: \(error)")
                #endif
                return
            }
        }
        
        // Create or open log file
        let filePath = currentLogFilePath.path
        
        if !fileManager.fileExists(atPath: filePath) {
            fileManager.createFile(atPath: filePath, contents: nil, attributes: [.posixPermissions: 0o644])
            currentFileSize = 0
        } else {
            // Get current file size
            do {
                let attributes = try fileManager.attributesOfItem(atPath: filePath)
                currentFileSize = attributes[.size] as? UInt64 ?? 0
            } catch {
                currentFileSize = 0
            }
        }
        
        // Open file handle if not already open
        if fileHandle == nil {
            do {
                fileHandle = try FileHandle(forWritingTo: currentLogFilePath)
                try fileHandle?.seekToEnd()
            } catch {
                #if DEBUG
                print("[Logger] Failed to open log file: \(error)")
                #endif
            }
        }
    }
    
    /// Closes the current file handle
    private func closeFileHandle() {
        do {
            try fileHandle?.close()
        } catch {
            #if DEBUG
            print("[Logger] Failed to close file handle: \(error)")
            #endif
        }
        fileHandle = nil
    }
    
    // MARK: - Private Methods - Log Rotation
    
    /// Rotates log files (must be called with lock held)
    private func rotateLogFiles() {
        // Close current file handle
        closeFileHandle()
        
        let basePath = logsDirectory
        let baseFileName = Self.logFileName
        
        // Delete oldest file if we have max files
        let oldestPath = basePath.appendingPathComponent("\(baseFileName).\(Self.maxLogFiles - 1).gz")
        if fileManager.fileExists(atPath: oldestPath.path) {
            try? fileManager.removeItem(at: oldestPath)
        }
        
        // Rotate existing files (4 -> 5, 3 -> 4, etc.)
        for i in stride(from: Self.maxLogFiles - 2, through: 1, by: -1) {
            let sourcePath = basePath.appendingPathComponent("\(baseFileName).\(i).gz")
            let destPath = basePath.appendingPathComponent("\(baseFileName).\(i + 1).gz")
            
            if fileManager.fileExists(atPath: sourcePath.path) {
                try? fileManager.moveItem(at: sourcePath, to: destPath)
            }
        }
        
        // Compress and move current log file to .1.gz
        let currentPath = currentLogFilePath
        let rotatedPath = basePath.appendingPathComponent("\(baseFileName).1.gz")
        
        compressLogFile(from: currentPath, to: rotatedPath)
        
        // Remove the original file after compression
        try? fileManager.removeItem(at: currentPath)
        
        // Reset file size and create new log file
        currentFileSize = 0
        ensureLogFileReady()
    }
    
    /// Compresses a log file using gzip
    /// - Parameters:
    ///   - source: Source file URL
    ///   - destination: Destination file URL (should end in .gz)
    private func compressLogFile(from source: URL, to destination: URL) {
        guard let sourceData = fileManager.contents(atPath: source.path) else {
            return
        }
        
        // Use zlib compression
        guard let compressedData = compress(data: sourceData) else {
            // If compression fails, just copy the file
            try? fileManager.copyItem(at: source, to: destination)
            return
        }
        
        // Write compressed data
        do {
            try compressedData.write(to: destination)
        } catch {
            #if DEBUG
            print("[Logger] Failed to write compressed log file: \(error)")
            #endif
        }
    }
    
    /// Compresses data using zlib/gzip
    /// - Parameter data: The data to compress
    /// - Returns: Compressed data, or nil if compression fails
    private func compress(data: Data) -> Data? {
        // Create gzip header
        var gzipHeader = Data([0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03])
        
        // Compress the data using zlib deflate
        let destinationBufferSize = data.count + 1024
        var destinationBuffer = [UInt8](repeating: 0, count: destinationBufferSize)
        
        let compressedSize = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            
            return compression_encode_buffer(
                &destinationBuffer,
                destinationBufferSize,
                sourcePointer,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        
        guard compressedSize > 0 else {
            return nil
        }
        
        // Build gzip file: header + compressed data + trailer
        var compressedData = gzipHeader
        compressedData.append(contentsOf: destinationBuffer[0..<compressedSize])
        
        // Add gzip trailer (CRC32 + original size)
        let crc = crc32(data: data)
        var crcBytes = withUnsafeBytes(of: crc.littleEndian) { Data($0) }
        var sizeBytes = withUnsafeBytes(of: UInt32(data.count).littleEndian) { Data($0) }
        compressedData.append(crcBytes)
        compressedData.append(sizeBytes)
        
        return compressedData
    }
    
    /// Calculates CRC32 checksum for data
    /// - Parameter data: The data to checksum
    /// - Returns: CRC32 checksum value
    private func crc32(data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let polynomial: UInt32 = 0xEDB88320
        
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ polynomial
                } else {
                    crc >>= 1
                }
            }
        }
        
        return ~crc
    }
}

// MARK: - Logger Extension for Convenience Methods

extension Logger {
    /// Returns the path to the logs directory
    var logsDirectoryPath: String {
        return logsDirectory.path
    }
    
    /// Returns the path to the current log file
    var currentLogFile: String {
        return currentLogFilePath.path
    }
    
    /// Returns all log file paths (current and rotated)
    func getAllLogFiles() -> [URL] {
        var files: [URL] = []
        
        // Current log file
        if fileManager.fileExists(atPath: currentLogFilePath.path) {
            files.append(currentLogFilePath)
        }
        
        // Rotated log files
        for i in 1..<Self.maxLogFiles {
            let rotatedPath = logsDirectory.appendingPathComponent("\(Self.logFileName).\(i).gz")
            if fileManager.fileExists(atPath: rotatedPath.path) {
                files.append(rotatedPath)
            }
        }
        
        return files
    }
    
    /// Reads the contents of the current log file
    /// - Parameter maxLines: Maximum number of lines to return (from the end)
    /// - Returns: Array of log lines
    func readCurrentLog(maxLines: Int = 100) -> [String] {
        flush()
        
        guard let content = try? String(contentsOf: currentLogFilePath, encoding: .utf8) else {
            return []
        }
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        if lines.count <= maxLines {
            return lines
        }
        
        return Array(lines.suffix(maxLines))
    }
    
    /// Clears all log files (for testing purposes)
    func clearAllLogs() {
        lock.lock()
        defer { lock.unlock() }
        
        closeFileHandle()
        
        // Remove all log files
        for file in getAllLogFiles() {
            try? fileManager.removeItem(at: file)
        }
        
        currentFileSize = 0
        buffer.removeAll()
    }
    
    /// Gets the total size of all log files in bytes
    func getTotalLogSize() -> UInt64 {
        var totalSize: UInt64 = 0
        
        for file in getAllLogFiles() {
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let size = attributes[.size] as? UInt64 {
                totalSize += size
            }
        }
        
        return totalSize
    }
}

// MARK: - Logger Extension for Component-Specific Logging

extension Logger {
    /// Pre-defined component names for consistent logging
    enum Component {
        static let mountManager = "MountManager"
        static let networkScanner = "NetworkScanner"
        static let credentialManager = "CredentialManager"
        static let configurationStore = "ConfigurationStore"
        static let volumeMonitor = "VolumeMonitor"
        static let syncEngine = "SyncEngine"
        static let launchAgent = "LaunchAgent"
        static let menuBar = "MenuBar"
        static let app = "App"
    }
}

// MARK: - Global Logging Functions

/// Convenience function for debug logging
/// - Parameters:
///   - message: The message to log
///   - component: The component generating the log
func logDebug(_ message: String, component: String) {
    Logger.shared.debug(message, component: component)
}

/// Convenience function for info logging
/// - Parameters:
///   - message: The message to log
///   - component: The component generating the log
func logInfo(_ message: String, component: String) {
    Logger.shared.info(message, component: component)
}

/// Convenience function for warning logging
/// - Parameters:
///   - message: The message to log
///   - component: The component generating the log
func logWarning(_ message: String, component: String) {
    Logger.shared.warning(message, component: component)
}

/// Convenience function for error logging
/// - Parameters:
///   - message: The message to log
///   - component: The component generating the log
func logError(_ message: String, component: String) {
    Logger.shared.error(message, component: component)
}

/// Convenience function for error logging with Error object
/// - Parameters:
///   - message: The message to log
///   - error: The error object
///   - component: The component generating the log
func logError(_ message: String, error: Error, component: String) {
    Logger.shared.error(message, error: error, component: component)
}
