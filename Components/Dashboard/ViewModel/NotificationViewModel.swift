//
//  NotificationViewModel.swift
//  AVREntertainment
//
//  Created by Auto on 10/29/25.
//

import Foundation
import FirebaseFirestore
import SwiftUI

@MainActor
class NotificationViewModel: ObservableObject {
    @Published var pendingApprovalsCount: Int = 0
    @Published var unreadMessagesCount: Int = 0
    @Published var expenseChatUpdatesCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var savedNotifications: [AppNotification] = [] // Saved FCM notifications
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var notificationObserver: NSObjectProtocol?
    
    init() {
        // Observe NotificationManager for updates
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NotificationManagerUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadSavedNotifications()
        }
        
        // Load saved notifications on init
        loadSavedNotifications()
    }
    
    deinit {
        listeners.forEach { $0.remove() }
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    var customerID: String {
        get async throws {
            try await FirebasePathHelper.shared.fetchEffectiveUserID()
        }
    }
    
    // MARK: - Load Saved Notifications
    
    /// Loads saved notifications from NotificationManager for a specific project
    /// This is synchronous and instant since it reads from UserDefaults
    func loadSavedNotifications(for projectId: String? = nil) {
        // Load directly from NotificationManager (already sorted and cached)
        if let projectId = projectId {
            savedNotifications = NotificationManager.shared.getNotifications(for: projectId)
        } else {
            savedNotifications = NotificationManager.shared.getAllNotifications()
        }
        // Ensure sorted by date (newest first) - though NotificationManager already does this
        savedNotifications.sort { $0.date > $1.date }
    }
    
    // MARK: - Fetch Notifications for Dashboard
    
    func fetchDashboardNotifications(projects: [Project], currentUserPhone: String, currentUserRole: UserRole) async {
        isLoading = true
        errorMessage = nil
        
        do {
            var totalPending = 0
            var totalUnread = 0
            var totalExpenseChats = 0
            
            for project in projects {
                guard let projectId = project.id else { continue }
                
                // Fetch pending approvals
                let pendingCount = await fetchPendingApprovalsCount(projectId: projectId, currentUserRole: currentUserRole)
                totalPending += pendingCount
                
                // Fetch unread messages
                let unreadCount = await fetchUnreadMessagesCount(projectId: projectId, currentUserPhone: currentUserPhone)
                totalUnread += unreadCount
                
                // Fetch expense chat updates
                let expenseChatCount = await fetchExpenseChatUpdatesCount(projectId: projectId, currentUserPhone: currentUserPhone)
                totalExpenseChats += expenseChatCount
            }
            
            pendingApprovalsCount = totalPending
            unreadMessagesCount = totalUnread
            expenseChatUpdatesCount = totalExpenseChats
            
        } catch {
            errorMessage = "Failed to load notifications: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Fetch Notifications for Single Project
    
    func fetchProjectNotifications(projectId: String, currentUserPhone: String, currentUserRole: UserRole) async {
        isLoading = true
        errorMessage = nil
        
        do {
            pendingApprovalsCount = await fetchPendingApprovalsCount(projectId: projectId, currentUserRole: currentUserRole)
            unreadMessagesCount = await fetchUnreadMessagesCount(projectId: projectId, currentUserPhone: currentUserPhone)
            expenseChatUpdatesCount = await fetchExpenseChatUpdatesCount(projectId: projectId, currentUserPhone: currentUserPhone)
            
            // Load saved notifications for this project
            loadSavedNotifications(for: projectId)
        } catch {
            errorMessage = "Failed to load notifications: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Private Fetch Methods
    
    private func fetchPendingApprovalsCount(projectId: String, currentUserRole: UserRole) async -> Int {
        // Only fetch for approvers
        guard currentUserRole == .APPROVER else { return 0 }
        
        do {
            let expensesSnapshot = try await db
                .collection("customers")
                .document(customerID)
                .collection("projects")
                .document(projectId)
                .collection("expenses")
                .whereField("status", isEqualTo: ExpenseStatus.pending.rawValue)
                .getDocuments()
            
            return expensesSnapshot.documents.count
        } catch {
            print("Error fetching pending approvals: \(error)")
            return 0
        }
    }
    
    private func fetchUnreadMessagesCount(projectId: String, currentUserPhone: String) async -> Int {
        do {
            // Fetch all chats for this project
            let chatsSnapshot = try await db
                .collection("customers")
                .document(customerID)
                .collection("projects")
                .document(projectId)
                .collection("chats")
                .getDocuments()
            
            var totalUnread = 0
            
            for chatDoc in chatsSnapshot.documents {
                guard let chatData = try? chatDoc.data(as: Chat.self) else { continue }
                let chatId = chatDoc.documentID
                
                // Check if current user is a participant
                if chatData.participants.contains(currentUserPhone) {
                    // Count unread messages in this chat
                    let messagesSnapshot = try await db
                        .collection("customers")
                        .document(customerID)
                        .collection("projects")
                        .document(projectId)
                        .collection("chats")
                        .document(chatId)
                        .collection("messages")
                        .whereField("isRead", isEqualTo: false)
                        .whereField("senderId", isNotEqualTo: currentUserPhone)
                        .getDocuments()
                    
                    totalUnread += messagesSnapshot.documents.count
                }
            }
            
            return totalUnread
        } catch {
            print("Error fetching unread messages: \(error)")
            return 0
        }
    }
    
    private func fetchExpenseChatUpdatesCount(projectId: String, currentUserPhone: String) async -> Int {
        do {
            // Fetch all expenses for this project
            let expensesSnapshot = try await db
                .collection("customers")
                .document(customerID)
                .collection("projects")
                .document(projectId)
                .collection("expenses")
                .getDocuments()
            
            var totalUpdates = 0
            
            for expenseDoc in expensesSnapshot.documents {
                guard let expenseData = try? expenseDoc.data(as: Expense.self) else { continue }
                
                // Check if user is the submitter and expense is not approved
                if expenseData.submittedBy == currentUserPhone && expenseData.status != .approved {
                    // Check for expense chat messages
                    let expenseChatSnapshot = try await db
                        .collection("customers")
                        .document(customerID)
                        .collection("projects")
                        .document(projectId)
                        .collection("expenses")
                        .document(expenseDoc.documentID)
                        .collection("expenseChats")
                        .order(by: "timeStamp", descending: true)
                        .limit(to: 1)
                        .getDocuments()
                    
                    if let lastMessage = expenseChatSnapshot.documents.first,
                       let messageData = try? lastMessage.data(as: ExpenseChat.self) {
                        // Check if message is recent (within last 24 hours)
                        let last24Hours = Date().addingTimeInterval(-24 * 60 * 60)
                        if let timeStamp = messageData.timeStamp as? Date, timeStamp > last24Hours {
                            totalUpdates += 1
                        }
                    }
                }
            }
            
            return totalUpdates
        } catch {
            print("Error fetching expense chat updates: \(error)")
            return 0
        }
    }
    
    // MARK: - Computed Properties
    
    /// Total count of all notification types (for internal use)
    var totalNotifications: Int {
        pendingApprovalsCount + unreadMessagesCount + expenseChatUpdatesCount + savedNotifications.count
    }
    
    /// Unread notification count for badge display (only FCM notifications)
    /// This should be used for the notification badge to avoid double-counting
    var unreadNotificationCount: Int {
        savedNotifications.count
    }
    
    var hasNotifications: Bool {
        totalNotifications > 0
    }
    
    /// Returns all notifications (saved + counts) for display
    var allNotifications: [AppNotification] {
        return savedNotifications
    }
}

