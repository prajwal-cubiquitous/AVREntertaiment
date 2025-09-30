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
    
    init(project: Project, currentUserPhone: String?, currentUserRole: UserRole) {
        self.project = project
        self.currentUserPhone = currentUserPhone
        self.currentUserRole = currentUserRole
    }
    
    func loadChatParticipants() async {
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
        Task {
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
                
                // Fetch participant details
                var detailedParticipants: [ChatParticipant] = []
                
                print("🔍 Loading participants for project: \(project.name)")
                print("🔍 Team members: \(project.teamMembers)")
                print("🔍 Manager ID: \(project.managerId)")
                print("🔍 Participant IDs to fetch: \(participantIds)")
                
                for participantId in participantIds {
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
                            
                            let participant = ChatParticipant(
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
                            detailedParticipants.append(participant)
                        } else {
                            print("❌ User not found for phone: \(participantId)")
                        }
                    } catch {
                        print("❌ Error fetching user \(participantId): \(error)")
                    }
                }
                
                // Add admin with chat data if not admin user
                if currentUserRole != .ADMIN {
                    let adminChatData = await fetchChatData(for: "Admin")
                    detailedParticipants.append(ChatParticipant(
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
                let sortedParticipants = detailedParticipants.sorted { first, second in
                    if first.role != second.role {
                        let roleOrder: [UserRole] = [.ADMIN, .APPROVER, .USER]
                        let firstIndex = roleOrder.firstIndex(of: first.role) ?? 3
                        let secondIndex = roleOrder.firstIndex(of: second.role) ?? 3
                        return firstIndex < secondIndex
                    }
                    return first.name < second.name
                }
                
                // Update UI with detailed data
                await MainActor.run {
                    self.participants = sortedParticipants
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load chat participants: \(error.localizedDescription)"
                    print("❌ Error loading chat participants: \(error)")
                }
            }
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
                
                // Count unread messages
                let unreadCount = try await countUnreadMessages(projectId: projectId, chatId: chatId, currentUserPhone: currentUserPhone ?? "Admin")
                
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
        } catch {
            print("❌ Error marking messages as read: \(error)")
        }
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
