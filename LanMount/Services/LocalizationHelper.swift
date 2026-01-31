//
//  LocalizationHelper.swift
//  LanMount
//
//  Provides localization utilities including date and number formatters
//  Requirements: 20.1 - Internationalization support with localized date and number formats
//

import Foundation

// MARK: - LocalizationHelper

/// Helper class for localization utilities
/// Provides locale-aware date and number formatters
final class LocalizationHelper {
    
    // MARK: - Singleton
    
    /// Shared instance
    static let shared = LocalizationHelper()
    
    // MARK: - Date Formatters
    
    /// Date formatter for displaying full date and time
    /// Example: "January 15, 2024 at 10:30 AM" (English) or "2024年1月15日 上午10:30" (Chinese)
    lazy var fullDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// Date formatter for displaying short date
    /// Example: "1/15/24" (English) or "2024/1/15" (Chinese)
    lazy var shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Date formatter for displaying medium date
    /// Example: "Jan 15, 2024" (English) or "2024年1月15日" (Chinese)
    lazy var mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Date formatter for displaying time only
    /// Example: "10:30 AM" (English) or "上午10:30" (Chinese)
    lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// Date formatter for log timestamps
    /// Uses ISO 8601 format for consistency
    lazy var logTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    /// Relative date formatter for displaying relative times
    /// Example: "2 hours ago", "yesterday", "in 3 days"
    lazy var relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
    
    // MARK: - Number Formatters
    
    /// Number formatter for displaying file sizes
    lazy var fileSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter
    }()
    
    /// Number formatter for displaying percentages
    /// Example: "75%" or "75.5%"
    lazy var percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    /// Number formatter for displaying integers with grouping
    /// Example: "1,234,567" (English) or "1,234,567" (Chinese)
    lazy var integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    /// Number formatter for displaying decimal numbers
    /// Example: "1,234.56" (English) or "1,234.56" (Chinese)
    lazy var decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Date Formatting Methods
    
    /// Formats a date using the full date and time format
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string
    func formatFullDateTime(_ date: Date) -> String {
        return fullDateTimeFormatter.string(from: date)
    }
    
    /// Formats a date using the short date format
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string
    func formatShortDate(_ date: Date) -> String {
        return shortDateFormatter.string(from: date)
    }
    
    /// Formats a date using the medium date format
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string
    func formatMediumDate(_ date: Date) -> String {
        return mediumDateFormatter.string(from: date)
    }
    
    /// Formats a time
    /// - Parameter date: The date containing the time to format
    /// - Returns: Formatted time string
    func formatTime(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
    
    /// Formats a date for log timestamps
    /// - Parameter date: The date to format
    /// - Returns: Formatted timestamp string
    func formatLogTimestamp(_ date: Date) -> String {
        return logTimestampFormatter.string(from: date)
    }
    
    /// Formats a date as a relative time string
    /// - Parameter date: The date to format
    /// - Returns: Relative time string (e.g., "2 hours ago")
    func formatRelativeDate(_ date: Date) -> String {
        return relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Number Formatting Methods
    
    /// Formats a byte count as a human-readable file size
    /// - Parameter bytes: The number of bytes
    /// - Returns: Formatted file size string (e.g., "1.5 MB")
    func formatFileSize(_ bytes: Int64) -> String {
        return fileSizeFormatter.string(fromByteCount: bytes)
    }
    
    /// Formats a byte count as a human-readable file size
    /// - Parameter bytes: The number of bytes
    /// - Returns: Formatted file size string (e.g., "1.5 MB")
    func formatFileSize(_ bytes: Int) -> String {
        return fileSizeFormatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Formats a decimal value as a percentage
    /// - Parameter value: The decimal value (0.0 to 1.0)
    /// - Returns: Formatted percentage string (e.g., "75%")
    func formatPercent(_ value: Double) -> String {
        return percentFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value * 100))%"
    }
    
    /// Formats an integer with locale-appropriate grouping
    /// - Parameter value: The integer value
    /// - Returns: Formatted integer string (e.g., "1,234,567")
    func formatInteger(_ value: Int) -> String {
        return integerFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    /// Formats a decimal number with locale-appropriate formatting
    /// - Parameter value: The decimal value
    /// - Returns: Formatted decimal string (e.g., "1,234.56")
    func formatDecimal(_ value: Double) -> String {
        return decimalFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
    
    // MARK: - Duration Formatting
    
    /// Formats a time interval as a human-readable duration
    /// - Parameter interval: The time interval in seconds
    /// - Returns: Formatted duration string
    func formatDuration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: interval) ?? ""
    }
    
    /// Formats a time interval as a scan interval description
    /// - Parameter interval: The time interval in seconds
    /// - Returns: Formatted interval string (e.g., "5 minutes")
    func formatScanInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes == 1 {
            return NSLocalizedString("1 minute", comment: "Interval display")
        } else {
            return String(format: NSLocalizedString("%d minutes", comment: "Interval display"), minutes)
        }
    }
}

// MARK: - String Extension for Localization

extension String {
    
    /// Returns a localized version of the string
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Returns a localized version of the string with a comment
    /// - Parameter comment: The comment for translators
    /// - Returns: Localized string
    func localized(comment: String) -> String {
        return NSLocalizedString(self, comment: comment)
    }
    
    /// Returns a localized version of the string with format arguments
    /// - Parameter arguments: The format arguments
    /// - Returns: Localized and formatted string
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Date Extension

extension Date {
    
    /// Returns a formatted string using the full date and time format
    var formattedFullDateTime: String {
        return LocalizationHelper.shared.formatFullDateTime(self)
    }
    
    /// Returns a formatted string using the short date format
    var formattedShortDate: String {
        return LocalizationHelper.shared.formatShortDate(self)
    }
    
    /// Returns a formatted string using the medium date format
    var formattedMediumDate: String {
        return LocalizationHelper.shared.formatMediumDate(self)
    }
    
    /// Returns a formatted time string
    var formattedTime: String {
        return LocalizationHelper.shared.formatTime(self)
    }
    
    /// Returns a relative time string (e.g., "2 hours ago")
    var formattedRelative: String {
        return LocalizationHelper.shared.formatRelativeDate(self)
    }
}

// MARK: - Int64 Extension for File Size

extension Int64 {
    
    /// Returns a formatted file size string
    var formattedFileSize: String {
        return LocalizationHelper.shared.formatFileSize(self)
    }
}

// MARK: - Int Extension for File Size

extension Int {
    
    /// Returns a formatted file size string
    var formattedFileSize: String {
        return LocalizationHelper.shared.formatFileSize(self)
    }
    
    /// Returns a formatted integer string with grouping
    var formattedWithGrouping: String {
        return LocalizationHelper.shared.formatInteger(self)
    }
}

// MARK: - Double Extension

extension Double {
    
    /// Returns a formatted percentage string
    var formattedPercent: String {
        return LocalizationHelper.shared.formatPercent(self)
    }
    
    /// Returns a formatted decimal string
    var formattedDecimal: String {
        return LocalizationHelper.shared.formatDecimal(self)
    }
}
