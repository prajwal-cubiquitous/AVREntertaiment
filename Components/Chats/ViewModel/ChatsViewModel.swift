//
//  ChatsViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 9/29/25.
//

import Foundation
import FirebaseFirestore
import SwiftUI

struct ChatParticipant: Identifiable, Hashable {
    let id: String
    let name: String
    let phoneNumber: String
    let role: UserRole
    let isOnline: Bool
    let lastSeen: Date?
    let unreadCount: Int
    let lastMessage: String?
    let lastMessageTime: Date?
    
    var displayName: String {
        if role == .ADMIN {
            return "\(name) (Admin)"
        } else {
            return name
        }
    }
    
    var roleColor: Color {
        switch role {
        case .ADMIN:
            return .red
        case .APPROVER:
            return .orange
        case .USER:
            return .blue
        }
    }
    
    var roleIcon: String {
        switch role {
        case .ADMIN:
            return "crown.fill"
        case .APPROVER:
            return "person.badge.clock.fill"
        case .USER:
            return "person.fill"
        }
    }
    
    init(id: String, name: String, phoneNumber: String, role: UserRole, isOnline: Bool, lastSeen: Date?, unreadCount: Int = 0, lastMessage: String? = nil, lastMessageTime: Date? = nil) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.role = role
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.unreadCount = unreadCount
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
    }
}

@MainActor
class ChatsViewModel: ObservableObject {
    @Published var participants: [ChatParticipant] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let currentUserPhone: String?
    private let currentUserRole: UserRole
    private let project: Project
    
    // Caching for better performance
    private var cachedParticipants: [ChatParticipant] = []
    private var lastLoadTime: Date?
    private let cacheValidityDuration: TimeInterval = 30 // 30 seconds cache
    
    init(project: Project, currentUserPhone: String?, currentUserRole: UserRole) {
        self.project = project
        self.currentUserPhone = currentUserPhone
        self.currentUserRole = currentUserRole
        print("DEBUG 1: \(self.currentUserPhone) and \(self.currentUserRole)")
    }
    
    func loadChatParticipants() async {
        // Check if we have valid cached data
        if let lastLoad = lastLoadTime,
           Date().timeIntervalSince(lastLoad) < cacheValidityDuration,
           !cachedParticipants.isEmpty {
            self.participants = cachedParticipants
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Show basic participants immediately for faster UI
        var basicParticipants: [ChatParticipant] = []
        
        // Add admin for non-admin users immediately
        if currentUserRole != .ADMIN {
            basicParticipants.append(ChatParticipant(
                id: "Admin", 
                name: "Admin", 
                phoneNumber: "123", 
                role: .ADMIN, 
                isOnline: true, 
                lastSeen: nil,
                unreadCount: 0,
                lastMessage: nil,
                lastMessageTime: nil
            ))
        }
        
        // Show basic UI first
        self.participants = basicParticipants
        isLoading = false
        
        // Load detailed data in background
        await loadDetailedParticipants()
    }
    
    private func loadDetailedParticipants() async {
        do {
            var participantIds: Set<String> = []
            
            // Add team members
            participantIds.formUnion(project.teamMembers)
            
            // Add manager
            participantIds.insert(project.managerId)
            
            if let approverId = project.tempApproverID, 
               let validApproverId = try await fetchValidTempApprover(for: approverId) {
                participantIds.insert(validApproverId)
            }
            
            // Remove current user from participants
            if let currentUserPhone = currentUserPhone {
                participantIds.remove(currentUserPhone)
            }
            
            // Fetch participant details in parallel for better performance
            let detailedParticipants = await withTaskGroup(of: ChatParticipant?.self) { group in
                var participants: [ChatParticipant] = []
                
                for participantId in participantIds {
                    group.addTask {
                        await self.fetchParticipantDetails(for: participantId)
                    }
                }
                
                for await participant in group {
                    if let participant = participant {
                        participants.append(participant)
                    }
                }
                
                return participants
            }
            
            // Add admin with chat data if not admin user
            var finalParticipants = detailedParticipants
            if currentUserRole != .ADMIN {
                let adminChatData = await fetchChatData(for: "Admin")
                finalParticipants.append(ChatParticipant(
                    id: "Admin", 
                    name: "Admin", 
                    phoneNumber: "123", 
                    role: .ADMIN, 
                    isOnline: true, 
                    lastSeen: nil,
                    unreadCount: adminChatData.unreadCount,
                    lastMessage: adminChatData.lastMessage,
                    lastMessageTime: adminChatData.lastMessageTime
                ))
            }
            
            // Sort participants: Admin first, then by role, then by name
            let sortedParticipants = finalParticipants.sorted { first, second in
                if first.role != second.role {
                    let roleOrder: [UserRole] = [.ADMIN, .APPROVER, .USER]
                    let firstIndex = roleOrder.firstIndex(of: first.role) ?? 3
                    let secondIndex = roleOrder.firstIndex(of: second.role) ?? 3
                    return firstIndex < secondIndex
                }
                return first.name < second.name
            }
            
            // Update UI with detailed data and cache it
            self.participants = sortedParticipants
            self.cachedParticipants = sortedParticipants
            self.lastLoadTime = Date()
            
        } catch {
            self.errorMessage = "Failed to load chat participants: \(error.localizedDescription)"
            print("❌ Error loading chat participants: \(error)")
        }
    }
    
    private func fetchParticipantDetails(for participantId: String) async -> ChatParticipant? {
        do {
            let userSnapshot = try await db
                .collection(FirebaseCollections.users)
                .whereField("phoneNumber", isEqualTo: participantId)
                .limit(to: 1)
                .getDocuments()
            
            if let document = userSnapshot.documents.first,
               let user = try? document.data(as: User.self) {
                
                print("✅ Found user: \(user.name) (\(user.phoneNumber))")
                
                // Fetch chat data for this participant
                let chatData = await fetchChatData(for: participantId)
                
                return ChatParticipant(
                    id: user.phoneNumber,
                    name: user.name,
                    phoneNumber: user.phoneNumber,
                    role: user.role,
                    isOnline: Bool.random(), // TODO: Implement real online status
                    lastSeen: Date().addingTimeInterval(-Double.random(in: 0...3600)), // TODO: Implement real last seen
                    unreadCount: chatData.unreadCount,
                    lastMessage: chatData.lastMessage,
                    lastMessageTime: chatData.lastMessageTime
                )
            } else {
                print("❌ User not found for phone: \(participantId)")
                return nil
            }
        } catch {
            print("❌ Error fetching user \(participantId): \(error)")
            return nil
        }
    }
    
    func startChat(with participant: ChatParticipant) {
        // TODO: Implement chat functionality
        print("Starting chat with \(participant.name)")
    }
    
    // MARK: - Chat Data Fetching
    
    private func fetchChatData(for participantId: String) async -> (unreadCount: Int, lastMessage: String?, lastMessageTime: Date?) {
        guard let projectId = project.id else {
            return (0, nil, nil)
        }
        
        do {
            // Create chat ID based on participants
            let currentUserPhone = currentUserPhone ?? "Admin"
            let participants = [currentUserPhone, participantId].sorted()
            let chatId = participants.joined(separator: "_")
            
            // Get chat document
            let chatDoc = try await db
                .collection("projects_ios")
                .document(projectId)
                .collection("chats")
                .document(chatId)
                .getDocument()
            
            if chatDoc.exists {
                let chatData = chatDoc.data()
                let lastMessage = chatData?["lastMessage"] as? String
                let lastMessageTime = (chatData?["lastTimestamp"] as? Timestamp)?.dateValue()
                
                // Count unread messages in background to avoid blocking UI
                let unreadCount = await Task.detached(priority: .background) {
                    do {
                        return try await self.countUnreadMessages(projectId: projectId, chatId: chatId, currentUserPhone: currentUserPhone)
                    } catch {
                        print("❌ Error counting unread messages: \(error)")
                        return 0
                    }
                }.value
                
                return (unreadCount, lastMessage, lastMessageTime)
            }
        } catch {
            print("❌ Error fetching chat data for \(participantId): \(error)")
        }
        
        return (0, nil, nil)
    }
    
    private func countUnreadMessages(projectId: String, chatId: String, currentUserPhone: String) async throws -> Int {
        let messagesSnapshot = try await db
            .collection("projects_ios")
            .document(projectId)
            .collection("chats")
            .document(chatId)
            .collection("messages")
            .whereField("senderId", isNotEqualTo: currentUserPhone)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()
        
        return messagesSnapshot.documents.count
    }
    
    func markMessagesAsRead(for participantId: String) async {
        guard let projectId = project.id else { return }
        
        let currentUserPhone = currentUserPhone ?? "Admin"
        let participants = [currentUserPhone, participantId].sorted()
        let chatId = participants.joined(separator: "_")
        
        do {
            // Update all unread messages from this participant
            let messagesSnapshot = try await db
                .collection("projects_ios")
                .document(projectId)
                .collection("chats")
                .document(chatId)
                .collection("messages")
                .whereField("senderId", isNotEqualTo: currentUserPhone)
                .whereField("isRead", isEqualTo: false)
                .getDocuments()
            
            for document in messagesSnapshot.documents {
                try await document.reference.updateData(["isRead": true])
            }
            
            // Update cached participant data
            if let index = cachedParticipants.firstIndex(where: { $0.phoneNumber == participantId }) {
                cachedParticipants[index] = ChatParticipant(
                    id: cachedParticipants[index].id,
                    name: cachedParticipants[index].name,
                    phoneNumber: cachedParticipants[index].phoneNumber,
                    role: cachedParticipants[index].role,
                    isOnline: cachedParticipants[index].isOnline,
                    lastSeen: cachedParticipants[index].lastSeen,
                    unreadCount: 0,
                    lastMessage: cachedParticipants[index].lastMessage,
                    lastMessageTime: cachedParticipants[index].lastMessageTime
                )
            }
        } catch {
            print("❌ Error marking messages as read: \(error)")
        }
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        cachedParticipants.removeAll()
        lastLoadTime = nil
    }
    
    func refreshData() async {
        clearCache()
        await loadChatParticipants()
    }
    
    
    func fetchValidTempApprover(for approverId: String) async throws -> String? {
        let db = Firestore.firestore()
        let currentDate = Date()
        guard let projectId = project.id else {
            print("error fetching project id")
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            db.collection("projects_ios").document(projectId).collection("tempApprover")
                .whereField("approverId", isEqualTo: approverId)
                .whereField("status", isEqualTo: "active")
                .whereField("endDate", isGreaterThanOrEqualTo: Timestamp(date: currentDate))
                .getDocuments { snapshot, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        continuation.resume(returning: nil)
                        return
                    }

                    for doc in documents {
                        let data = doc.data()
                        if let approverID = data["approverId"] as? String,
                           let startTime = data["startDate"] as? Timestamp,
                           let endTime = data["endDate"] as? Timestamp {

                            // Compare using Date objects
                            if startTime.dateValue() <= currentDate && endTime.dateValue() >= currentDate {
                                continuation.resume(returning: approverID)
                                return
                            }
                        }
                    }

                    continuation.resume(returning: nil)
                }
        }
    }
}
