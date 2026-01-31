//
//  NotificationManager.swift
//  LanMount
//
//  Manages user notifications using UNUserNotificationCenter
//  Requirements: 8.3 - Notify users of mount events and provide reconnection options
//

import Foundation
import UserNotifications

// MARK: - NotificationType

/// Types of notifications that can be sent to the user
enum NotificationType: String, CaseIterable {
    /// SMB share was successfully mounted
    case mountSuccess = "mount_success"
    /// SMB share failed to mount
    case mountFailure = "mount_failure"
    /// SMB share was unexpectedly disconnected
    case disconnection = "disconnection"
    /// File synchronization completed
    case syncComplete = "sync_complete"
    /// File synchronization conflict detected
    case syncConflict = "sync_conflict"
    
    /// The notification category identifier for this type
    var categoryIdentifier: String {
        return "com.lanmount.notification.\(rawValue)"
    }
    
    /// Default title for this notification type
    var defaultTitle: String {
        switch self {
        case .mountSuccess:
            return NSLocalizedString("Mount Successful", comment: "Notification title for successful mount")
        case .mountFailure:
            return NSLocalizedString("Mount Failed", comment: "Notification title for failed mount")
        case .disconnection:
            return NSLocalizedString("Volume Disconnected", comment: "Notification title for disconnection")
        case .syncComplete:
            return NSLocalizedString("Sync Complete", comment: "Notification title for sync completion")
        case .syncConflict:
            return NSLocalizedString("Sync Conflict", comment: "Notification title for sync conflict")
        }
    }
    
    /// Sound to play for this notification type
    var sound: UNNotificationSound {
        switch self {
        case .mountSuccess, .syncComplete:
            return .default
        case .mountFailure, .disconnection, .syncConflict:
            return UNNotificationSound.defaultCritical
        }
    }
}

// MARK: - NotificationAction

/// Actions that can be taken from notifications
enum NotificationAction: String {
    /// Open the mounted volume in Finder
    case openInFinder = "open_in_finder"
    /// Attempt to reconnect a disconnected volume
    case reconnect = "reconnect"
    /// View sync conflict details
    case viewConflict = "view_conflict"
    /// Dismiss the notification
    case dismiss = "dismiss"
    
    /// The action identifier
    var identifier: String {
        return "com.lanmount.action.\(rawValue)"
    }
    
    /// Display title for the action button
    var title: String {
        switch self {
        case .openInFinder:
            return NSLocalizedString("Open in Finder", comment: "Notification action")
        case .reconnect:
            return NSLocalizedString("Reconnect", comment: "Notification action")
        case .viewConflict:
            return NSLocalizedString("View Details", comment: "Notification action")
        case .dismiss:
            return NSLocalizedString("Dismiss", comment: "Notification action")
        }
    }
}

// MARK: - NotificationManagerProtocol

/// Protocol defining the interface for notification management
/// Provides methods for requesting permissions, showing notifications, and handling user preferences
protocol NotificationManagerProtocol: AnyObject {
    /// Whether notifications are currently authorized
    var isAuthorized: Bool { get }
    
    /// Requests notification permissions from the user
    /// - Returns: Whether permission was granted
    @discardableResult
    func requestPermissions() async -> Bool
    
    /// Checks the current authorization status
    /// - Returns: The current authorization status
    func checkAuthorizationStatus() async -> UNAuthorizationStatus
    
    /// Shows a mount success notification
    /// - Parameters:
    ///   - server: The server address
    ///   - share: The share name
    ///   - mountPoint: The mount point path
    func showMountSuccess(server: String, share: String, mountPoint: String)
    
    /// Shows a mount failure notification
    /// - Parameters:
    ///   - server: The server address
    ///   - share: The share name
    ///   - error: The error that occurred
    func showMountFailure(server: String, share: String, error: Error)
    
    /// Shows a disconnection notification
    /// - Parameters:
    ///   - volumeName: The name of the disconnected volume
    ///   - mountPoint: The mount point path
    func showDisconnection(volumeName: String, mountPoint: String)
    
    /// Shows a sync complete notification
    /// - Parameters:
    ///   - mountPoint: The mount point that was synced
    ///   - fileCount: Number of files synced
    func showSyncComplete(mountPoint: String, fileCount: Int)
    
    /// Shows a sync conflict notification
    /// - Parameters:
    ///   - conflictInfo: Information about the conflict
    func showSyncConflict(conflictInfo: ConflictInfo)
    
    /// Removes all pending notifications
    func removeAllPendingNotifications()
    
    /// Removes all delivered notifications
    func removeAllDeliveredNotifications()
}

// MARK: - NotificationManagerDelegate

/// Delegate protocol for handling notification actions
@MainActor
protocol NotificationManagerDelegate: AnyObject {
    /// Called when the user taps on a notification to open a volume in Finder
    /// - Parameter mountPoint: The mount point to open
    func notificationManagerDidRequestOpenInFinder(mountPoint: String)

    /// Called when the user requests to reconnect a disconnected volume
    /// - Parameter mountPoint: The mount point to reconnect
    func notificationManagerDidRequestReconnect(mountPoint: String)

    /// Called when the user wants to view sync conflict details
    /// - Parameter conflictId: The ID of the conflict
    func notificationManagerDidRequestViewConflict(conflictId: UUID)
}

// MARK: - NotificationManager

/// Implementation of NotificationManagerProtocol using UNUserNotificationCenter
/// Handles all user notifications for the application including mount events, sync events, and errors
/// Requirements: 8.3 - Notify users of mount events and provide reconnection options
final class NotificationManager: NSObject, NotificationManagerProtocol {
    
    // MARK: - Properties
    
    /// The notification center instance
    private let notificationCenter: UNUserNotificationCenter
    
    /// Configuration store for checking user preferences
    private let configurationStore: ConfigurationStoreProtocol
    
    /// Logger for logging notification events
    private let logger: Logger
    
    /// Delegate for handling notification actions
    weak var delegate: NotificationManagerDelegate?
    
    /// Current authorization status
    private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    /// Whether notifications are currently authorized
    var isAuthorized: Bool {
        return authorizationStatus == .authorized
    }
    
    // MARK: - Singleton
    
    /// Shared notification manager instance
    static let shared = NotificationManager()
    
    // MARK: - Initialization
    
    /// Creates a new NotificationManager instance
    /// - Parameters:
    ///   - notificationCenter: The notification center to use (defaults to .current())
    ///   - configurationStore: The configuration store for user preferences
    ///   - logger: The logger instance
    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        configurationStore: ConfigurationStoreProtocol = ConfigurationStore(),
        logger: Logger = .shared
    ) {
        self.notificationCenter = notificationCenter
        self.configurationStore = configurationStore
        self.logger = logger
        
        super.init()
        
        // Set self as delegate for handling notification responses
        notificationCenter.delegate = self
        
        // Register notification categories and actions
        registerNotificationCategories()
        
        // Check initial authorization status
        Task {
            _ = await checkAuthorizationStatus()
        }
    }
    
    // MARK: - NotificationManagerProtocol Implementation
    
    @discardableResult
    func requestPermissions() async -> Bool {
        logger.info("Requesting notification permissions", component: Logger.Component.app)
        
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                logger.info("Notification permissions granted", component: Logger.Component.app)
                authorizationStatus = .authorized
            } else {
                logger.warning("Notification permissions denied by user", component: Logger.Component.app)
                authorizationStatus = .denied
            }
            
            return granted
        } catch {
            logger.error("Failed to request notification permissions", error: error, component: Logger.Component.app)
            return false
        }
    }
    
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        return authorizationStatus
    }
    
    func showMountSuccess(server: String, share: String, mountPoint: String) {
        guard shouldShowNotification() else { return }
        
        let body = String(
            format: NSLocalizedString("Connected to %@/%@", comment: "Mount success notification body"),
            server, share
        )
        
        var userInfo: [String: Any] = [
            "type": NotificationType.mountSuccess.rawValue,
            "server": server,
            "share": share,
            "mountPoint": mountPoint
        ]
        
        showNotification(
            type: .mountSuccess,
            title: NotificationType.mountSuccess.defaultTitle,
            body: body,
            userInfo: userInfo
        )
        
        logger.info("Showed mount success notification for \(server)/\(share)", component: Logger.Component.app)
    }
    
    func showMountFailure(server: String, share: String, error: Error) {
        guard shouldShowNotification() else { return }
        
        let body = String(
            format: NSLocalizedString("Failed to connect to %@/%@: %@", comment: "Mount failure notification body"),
            server, share, error.localizedDescription
        )
        
        let userInfo: [String: Any] = [
            "type": NotificationType.mountFailure.rawValue,
            "server": server,
            "share": share,
            "error": error.localizedDescription
        ]
        
        showNotification(
            type: .mountFailure,
            title: NotificationType.mountFailure.defaultTitle,
            body: body,
            userInfo: userInfo
        )
        
        logger.info("Showed mount failure notification for \(server)/\(share)", component: Logger.Component.app)
    }
    
    func showDisconnection(volumeName: String, mountPoint: String) {
        guard shouldShowNotification() else { return }
        
        let body = String(
            format: NSLocalizedString("Connection to %@ was lost", comment: "Disconnection notification body"),
            volumeName
        )
        
        let userInfo: [String: Any] = [
            "type": NotificationType.disconnection.rawValue,
            "volumeName": volumeName,
            "mountPoint": mountPoint
        ]
        
        showNotification(
            type: .disconnection,
            title: NotificationType.disconnection.defaultTitle,
            body: body,
            userInfo: userInfo
        )
        
        logger.info("Showed disconnection notification for \(volumeName)", component: Logger.Component.app)
    }
    
    func showSyncComplete(mountPoint: String, fileCount: Int) {
        guard shouldShowNotification() else { return }
        
        let volumeName = (mountPoint as NSString).lastPathComponent
        let body: String
        
        if fileCount == 1 {
            body = String(
                format: NSLocalizedString("1 file synchronized for %@", comment: "Sync complete notification body (singular)"),
                volumeName
            )
        } else {
            body = String(
                format: NSLocalizedString("%d files synchronized for %@", comment: "Sync complete notification body (plural)"),
                fileCount, volumeName
            )
        }
        
        let userInfo: [String: Any] = [
            "type": NotificationType.syncComplete.rawValue,
            "mountPoint": mountPoint,
            "fileCount": fileCount
        ]
        
        showNotification(
            type: .syncComplete,
            title: NotificationType.syncComplete.defaultTitle,
            body: body,
            userInfo: userInfo
        )
        
        logger.info("Showed sync complete notification for \(mountPoint)", component: Logger.Component.app)
    }
    
    func showSyncConflict(conflictInfo: ConflictInfo) {
        guard shouldShowNotification() else { return }
        
        let body = String(
            format: NSLocalizedString("Conflict detected for %@", comment: "Sync conflict notification body"),
            conflictInfo.fileName
        )
        
        let userInfo: [String: Any] = [
            "type": NotificationType.syncConflict.rawValue,
            "conflictId": conflictInfo.id.uuidString,
            "filePath": conflictInfo.filePath
        ]
        
        showNotification(
            type: .syncConflict,
            title: NotificationType.syncConflict.defaultTitle,
            body: body,
            userInfo: userInfo
        )
        
        logger.info("Showed sync conflict notification for \(conflictInfo.fileName)", component: Logger.Component.app)
    }
    
    func removeAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        logger.debug("Removed all pending notifications", component: Logger.Component.app)
    }
    
    func removeAllDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        logger.debug("Removed all delivered notifications", component: Logger.Component.app)
    }
    
    // MARK: - Private Methods
    
    /// Registers notification categories and actions with the notification center
    private func registerNotificationCategories() {
        var categories = Set<UNNotificationCategory>()
        
        // Mount success category - with "Open in Finder" action
        let openInFinderAction = UNNotificationAction(
            identifier: NotificationAction.openInFinder.identifier,
            title: NotificationAction.openInFinder.title,
            options: [.foreground]
        )
        
        let mountSuccessCategory = UNNotificationCategory(
            identifier: NotificationType.mountSuccess.categoryIdentifier,
            actions: [openInFinderAction],
            intentIdentifiers: [],
            options: []
        )
        categories.insert(mountSuccessCategory)
        
        // Mount failure category - dismiss only
        let mountFailureCategory = UNNotificationCategory(
            identifier: NotificationType.mountFailure.categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        categories.insert(mountFailureCategory)
        
        // Disconnection category - with "Reconnect" action
        let reconnectAction = UNNotificationAction(
            identifier: NotificationAction.reconnect.identifier,
            title: NotificationAction.reconnect.title,
            options: [.foreground]
        )
        
        let disconnectionCategory = UNNotificationCategory(
            identifier: NotificationType.disconnection.categoryIdentifier,
            actions: [reconnectAction],
            intentIdentifiers: [],
            options: []
        )
        categories.insert(disconnectionCategory)
        
        // Sync complete category - with "Open in Finder" action
        let syncCompleteCategory = UNNotificationCategory(
            identifier: NotificationType.syncComplete.categoryIdentifier,
            actions: [openInFinderAction],
            intentIdentifiers: [],
            options: []
        )
        categories.insert(syncCompleteCategory)
        
        // Sync conflict category - with "View Details" action
        let viewConflictAction = UNNotificationAction(
            identifier: NotificationAction.viewConflict.identifier,
            title: NotificationAction.viewConflict.title,
            options: [.foreground]
        )
        
        let syncConflictCategory = UNNotificationCategory(
            identifier: NotificationType.syncConflict.categoryIdentifier,
            actions: [viewConflictAction],
            intentIdentifiers: [],
            options: []
        )
        categories.insert(syncConflictCategory)
        
        // Register all categories
        notificationCenter.setNotificationCategories(categories)
        
        logger.debug("Registered \(categories.count) notification categories", component: Logger.Component.app)
    }
    
    /// Checks if notifications should be shown based on user preferences
    /// - Returns: Whether notifications should be shown
    private func shouldShowNotification() -> Bool {
        // Check authorization status
        guard isAuthorized else {
            logger.debug("Notifications not authorized, skipping notification", component: Logger.Component.app)
            return false
        }
        
        // Check user preferences
        let settings = configurationStore.getAppSettings()
        guard settings.notificationsEnabled else {
            logger.debug("Notifications disabled in preferences, skipping notification", component: Logger.Component.app)
            return false
        }
        
        return true
    }
    
    /// Shows a notification with the specified parameters
    /// - Parameters:
    ///   - type: The notification type
    ///   - title: The notification title
    ///   - body: The notification body
    ///   - userInfo: Additional user info to attach to the notification
    private func showNotification(
        type: NotificationType,
        title: String,
        body: String,
        userInfo: [String: Any]
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = type.sound
        content.categoryIdentifier = type.categoryIdentifier
        content.userInfo = userInfo
        
        // Create a unique identifier for this notification
        let identifier = "\(type.rawValue)_\(UUID().uuidString)"
        
        // Create the request with no trigger (immediate delivery)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        // Add the notification request
        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to show notification", error: error, component: Logger.Component.app)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    /// Called when a notification is about to be presented while the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notifications even when the app is in the foreground
        completionHandler([.banner, .sound])
    }
    
    /// Called when the user interacts with a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier
        
        logger.debug("Received notification response: \(actionIdentifier)", component: Logger.Component.app)
        
        // Handle the action on the main actor
        Task { @MainActor in
            switch actionIdentifier {
            case NotificationAction.openInFinder.identifier:
                if let mountPoint = userInfo["mountPoint"] as? String {
                    delegate?.notificationManagerDidRequestOpenInFinder(mountPoint: mountPoint)
                }
                
            case NotificationAction.reconnect.identifier:
                if let mountPoint = userInfo["mountPoint"] as? String {
                    delegate?.notificationManagerDidRequestReconnect(mountPoint: mountPoint)
                }
                
            case NotificationAction.viewConflict.identifier:
                if let conflictIdString = userInfo["conflictId"] as? String,
                   let conflictId = UUID(uuidString: conflictIdString) {
                    delegate?.notificationManagerDidRequestViewConflict(conflictId: conflictId)
                }
                
            case UNNotificationDefaultActionIdentifier:
                // User tapped on the notification itself
                await handleDefaultAction(userInfo: userInfo)
                
            case UNNotificationDismissActionIdentifier:
                // User dismissed the notification
                break
                
            default:
                break
            }
        }
        
        completionHandler()
    }
    
    /// Handles the default action when user taps on the notification
    @MainActor
    private func handleDefaultAction(userInfo: [AnyHashable: Any]) async {
        guard let typeString = userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString) else {
            return
        }
        
        switch type {
        case .mountSuccess, .syncComplete:
            // Open in Finder
            if let mountPoint = userInfo["mountPoint"] as? String {
                delegate?.notificationManagerDidRequestOpenInFinder(mountPoint: mountPoint)
            }
            
        case .disconnection:
            // Attempt reconnect
            if let mountPoint = userInfo["mountPoint"] as? String {
                delegate?.notificationManagerDidRequestReconnect(mountPoint: mountPoint)
            }
            
        case .syncConflict:
            // View conflict details
            if let conflictIdString = userInfo["conflictId"] as? String,
               let conflictId = UUID(uuidString: conflictIdString) {
                delegate?.notificationManagerDidRequestViewConflict(conflictId: conflictId)
            }
            
        case .mountFailure:
            // No default action for mount failure
            break
        }
    }
}

// MARK: - NotificationManager Extension for Testing

extension NotificationManager {
    /// Returns the number of registered notification categories
    func getRegisteredCategoriesCount() async -> Int {
        let categories = await notificationCenter.notificationCategories()
        return categories.count
    }
    
    /// Returns the pending notification requests
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
    
    /// Returns the delivered notifications
    func getDeliveredNotifications() async -> [UNNotification] {
        return await notificationCenter.deliveredNotifications()
    }
}
