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
        
        do {
            var participantIds: Set<String> = []
            
            // Add team members
            participantIds.formUnion(project.teamMembers)
            
            // Add manager
            
            participantIds.insert(project.managerId)
            
            
            if let approverId  = project.tempApproverID, let approverId  = try await fetchValidTempApprover(for: approverId){
                participantIds.insert(approverId)
            }
            
//            // Add admin users (accessible to all projects)
//            if currentUserRole == .ADMIN {
//                let adminSnapshot = try await db
//                    .collection(FirebaseCollections.users)
//                    .whereField("role", isEqualTo: UserRole.ADMIN.rawValue)
//                    .getDocuments()
//                
//                for document in adminSnapshot.documents {
//                    if let user = try? document.data(as: User.self) {
//                        participantIds.insert(user.phoneNumber)
//                    }
//                }
//            }
            
            // Remove current user from participants
            if let currentUserPhone = currentUserPhone{
                participantIds.remove(currentUserPhone)
            }
            
            
            // Fetch participant details
            var participants: [ChatParticipant] = []
            
            for participantId in participantIds {
                do {
                    let userSnapshot = try await db
                        .collection(FirebaseCollections.users)
                        .whereField("phoneNumber", isEqualTo: participantId)
                        .limit(to: 1)
                        .getDocuments()
                    
                    if let document = userSnapshot.documents.first,
                       let user = try? document.data(as: User.self) {
                        let participant = ChatParticipant(
                            id: user.phoneNumber,
                            name: user.name,
                            phoneNumber: user.phoneNumber,
                            role: user.role,
                            isOnline: Bool.random(), // TODO: Implement real online status
                            lastSeen: Date().addingTimeInterval(-Double.random(in: 0...3600)) // TODO: Implement real last seen
                        )
                        participants.append(participant)
                    }
                } catch {
                    print("❌ Error fetching user \(participantId): \(error)")
                }
            }
            
            if currentUserRole != .ADMIN {
                participants.append(ChatParticipant(id: "Admin", name: "Admin", phoneNumber: "123", role: .ADMIN, isOnline: true, lastSeen: nil))
            }
            
            // Sort participants: Admin first, then by role, then by name
            self.participants = participants.sorted { first, second in
                if first.role != second.role {
                    let roleOrder: [UserRole] = [.ADMIN, .APPROVER, .USER]
                    let firstIndex = roleOrder.firstIndex(of: first.role) ?? 3
                    let secondIndex = roleOrder.firstIndex(of: second.role) ?? 3
                    return firstIndex < secondIndex
                }
                return first.name < second.name
            }
            
        } catch {
            errorMessage = "Failed to load chat participants: \(error.localizedDescription)"
            print("❌ Error loading chat participants: \(error)")
        }
        
        isLoading = false
    }
    
    func startChat(with participant: ChatParticipant) {
        // TODO: Implement chat functionality
        print("Starting chat with \(participant.name)")
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
