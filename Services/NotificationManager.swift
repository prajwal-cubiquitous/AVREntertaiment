//
//  NotificationManager.swift
//  AVREntertainment
//
//  Created by Auto on 1/1/25.
//

import Foundation
import SwiftUI

/// Singleton manager for storing and retrieving in-app notifications
/// Stores notifications per project in UserDefaults
@MainActor
class NotificationManager: ObservableObject {
    private static var _shared: NotificationManager?
    
    static var shared: NotificationManager {
        if let existing = _shared {
            return existing
        }
        let new = NotificationManager()
        _shared = new
        return new
    }
    
    @Published var notifications: [AppNotification] = []
    
    private let userDefaults = UserDefaults.standard
    private let notificationsKey = "AppNotifications"
    private let maxNotificationsPerProject = 100 // Limit to prevent excessive storage
    
    private init() {
        loadNotifications()
    }
    
    // MARK: - Save Notification
    
    /// Saves a notification for a specific project
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body/message
    ///   - data: Additional data dictionary from FCM
    ///   - projectId: Optional project ID for filtering
    func saveNotification(title: String, body: String, data: [String: Any] = [:], projectId: String? = nil) {
        let notification = AppNotification(
            title: title,
            body: body,
            date: Date(),
            data: data,
            projectId: projectId
        )
        
        // Add to in-memory array
        notifications.append(notification)
        
        // Sort by date (newest first)
        notifications.sort { $0.date > $1.date }
        
        // Limit notifications per project if specified
        if let projectId = projectId {
            let projectNotifications = notifications.filter { $0.projectId == projectId }
            if projectNotifications.count > maxNotificationsPerProject {
                // Remove oldest notifications for this project
                let toRemove = projectNotifications.suffix(projectNotifications.count - maxNotificationsPerProject)
                notifications.removeAll { notification in
                    toRemove.contains { $0.id == notification.id }
                }
            }
        } else {
            // Limit total notifications if no project filter
            if notifications.count > maxNotificationsPerProject * 10 {
                notifications = Array(notifications.prefix(maxNotificationsPerProject * 10))
            }
        }
        
        // Persist to UserDefaults
        saveToUserDefaults()
        
        // Notify observers that notifications were updated
        NotificationCenter.default.post(name: NSNotification.Name("NotificationManagerUpdated"), object: nil)
    }
    
    // MARK: - Load Notifications
    
    /// Loads all notifications from UserDefaults
    func loadNotifications() {
        guard let data = userDefaults.data(forKey: notificationsKey) else {
            notifications = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            notifications = try decoder.decode([AppNotification].self, from: data)
            // Sort by date (newest first)
            notifications.sort { $0.date > $1.date }
        } catch {
            print("❌ Error loading notifications: \(error.localizedDescription)")
            notifications = []
        }
    }
    
    // MARK: - Get Notifications for Project
    
    /// Returns notifications filtered by project ID
    /// - Parameter projectId: Project ID to filter by
    /// - Returns: Array of notifications for the project
    func getNotifications(for projectId: String) -> [AppNotification] {
        return notifications.filter { $0.projectId == projectId }
    }
    
    // MARK: - Get All Notifications (for Dashboard)
    
    /// Returns all notifications (for APPROVER and ADMIN roles)
    /// - Returns: Array of all notifications
    func getAllNotifications() -> [AppNotification] {
        return notifications
    }
    
    // MARK: - Clear Notifications
    
    /// Clears all notifications
    func clearAllNotifications() {
        notifications = []
        saveToUserDefaults()
        NotificationCenter.default.post(name: NSNotification.Name("NotificationManagerUpdated"), object: nil)
    }
    
    /// Clears notifications for a specific project
    /// - Parameter projectId: Project ID to clear notifications for
    func clearNotifications(for projectId: String) {
        notifications.removeAll { $0.projectId == projectId }
        saveToUserDefaults()
        NotificationCenter.default.post(name: NSNotification.Name("NotificationManagerUpdated"), object: nil)
    }
    
    /// Removes a specific notification by ID
    /// - Parameter notificationId: The ID of the notification to remove (String)
    func removeNotification(byId notificationId: String) {
        notifications.removeAll { $0.id == notificationId }
        saveToUserDefaults()
        NotificationCenter.default.post(name: NSNotification.Name("NotificationManagerUpdated"), object: nil)
    }
    
    // MARK: - Handle Navigation
    
    /// Handles navigation based on notification data with role-aware flow
    /// - Parameters:
    ///   - data: Notification data dictionary
    ///   - currentRole: Current user role (ADMIN, APPROVER, or USER)
    ///   - currentProjectId: Optional current project ID if already in a project view
    func handleNavigation(data: [String: Any], currentRole: UserRole? = nil, currentProjectId: String? = nil) {
        // Extract navigation parameters from data
        guard let screen = data["screen"] as? String else {
            print("⚠️ Notification navigation: No screen specified in data")
            return
        }
        
        // Check type field to determine if expense notification should be chat
        let notificationType = data["type"] as? String
        let isExpenseChat = notificationType == "expense_chat_staff" || notificationType == "expense_chat_customer"
        
        // Determine actual screen - if type indicates expense_chat, override screen
        var actualScreen = screen
        if isExpenseChat && (screen == "expense_detail" || screen == "expense_review") {
            actualScreen = "expense_chat"
        }
        
        let projectId = data["projectId"] as? String
        let chatId = data["chatId"] as? String
        let expenseId = data["expenseId"] as? String
        let phaseId = data["phaseId"] as? String
        let requestId = data["requestId"] as? String
        let customerId = data["customerId"] as? String
        
        
        // Determine if we need to navigate to project first
        // For screens that require a project context, we always need projectId
        let requiresProject = ["project_detail", "chat_detail", "expense_detail", "expense_chat", "phase_detail", "project_creation"].contains(actualScreen)
        
        if requiresProject && projectId == nil {
            print("⚠️ Notification navigation: Screen \(actualScreen) requires projectId but none provided")
            return
        }
        
        // Update data with corrected screen value
        var updatedData = data
        updatedData["screen"] = actualScreen
        
        // Post notification for navigation (existing system)
        // The navigation will be handled by AVREntertainmentApp.swift which knows the user role
        NotificationCenter.default.post(
            name: Notification.Name("NavigateFromNotification"),
            object: nil,
            userInfo: updatedData
        )
    }
    
    // MARK: - Private Helpers
    
    private func saveToUserDefaults() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(notifications)
            userDefaults.set(data, forKey: notificationsKey)
        } catch {
            print("❌ Error saving notifications: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Computed Properties
    
    /// Returns unread notification count for a project
    func unreadCount(for projectId: String) -> Int {
        return getNotifications(for: projectId).count
    }
    
    /// Returns total unread notification count
    var totalUnreadCount: Int {
        return notifications.count
    }
}

