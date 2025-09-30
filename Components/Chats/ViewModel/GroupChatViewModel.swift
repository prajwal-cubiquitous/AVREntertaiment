//
//  GroupChatViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 9/29/25.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

@MainActor
class GroupChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var projectMembers: [ProjectMember] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSendingMessage = false
    
    private let db = Firestore.firestore()
    private let currentUserPhone: String?
    private let role: UserRole
    private let project: Project
    private var messageListener: ListenerRegistration?
    
    init(project: Project, currentUserPhone: String?, role: UserRole) {
        self.project = project
        self.currentUserPhone = currentUserPhone
        self.role = role
    }
    
    deinit {
        messageListener?.remove()
    }
    
    func loadGroupMessages() async {
        isLoading = true
        errorMessage = nil
        
        guard let projectId = project.id else {
            errorMessage = "Project ID not found"
            isLoading = false
            return
        }
        
        do {
            // Load project members
            await loadProjectMembers()
            
            // Create or get group chat
            let chatId = "group_\(projectId)"
            let chat = try await createOrGetGroupChat(projectId: projectId, chatId: chatId)
            
            // Load existing messages
            let existingMessages = try await loadMessagesAsync(projectId: projectId, chatId: chatId)
            self.messages = existingMessages
            
            // Start listening for new messages
            startListeningToMessages(projectId: projectId, chatId: chatId)
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load group messages: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func sendMessage(_ message: Message) {
        guard let projectId = project.id else {
            errorMessage = "Project not found"
            return
        }
        
        isSendingMessage = true
        
        Task {
            do {
                let chatId = "group_\(projectId)"
                try await sendMessageAsync(
                    projectId: projectId,
                    chatId: chatId,
                    senderId: message.senderId,
                    text: message.text,
                    media: message.media,
                    replyTo: message.replyTo,
                    mentions: message.mentions,
                    isGroupMessage: message.isGroupMessage
                )
                
                await MainActor.run {
                    isSendingMessage = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to send message: \(error.localizedDescription)"
                    isSendingMessage = false
                }
            }
        }
    }
    
    func uploadMediaAsync(_ data: Data, path: String) async throws -> String {
        let storageRef = Storage.storage().reference().child(path)
        _ = try await storageRef.putDataAsync(data)
        let url = try await storageRef.downloadURL()
        return url.absoluteString
    }
    
    // MARK: - Private Methods
    
    private func loadProjectMembers() async {
        var members: [ProjectMember] = []
        
        // Add team members
        for memberId in project.teamMembers {
            if let member = await fetchUser(phoneNumber: memberId) {
                members.append(ProjectMember(
                    id: member.phoneNumber,
                    name: member.name,
                    phoneNumber: member.phoneNumber,
                    role: member.role
                ))
            }
        }
        
        // Add manager
        if let manager = await fetchUser(phoneNumber: project.managerId) {
            members.append(ProjectMember(
                id: manager.phoneNumber,
                name: manager.name,
                phoneNumber: manager.phoneNumber,
                role: manager.role
            ))
        }
        
        // Add temp approver if active
        if let tempApproverID = project.tempApproverID {
            if let approver = await fetchUser(phoneNumber: tempApproverID) {
                members.append(ProjectMember(
                    id: approver.phoneNumber,
                    name: approver.name,
                    phoneNumber: approver.phoneNumber,
                    role: approver.role
                ))
            }
        }
        
        // Add admin if current user is not admin
        if role != .ADMIN {
            members.append(ProjectMember(
                id: "Admin",
                name: "Admin",
                phoneNumber: "Admin",
                role: .ADMIN
            ))
        }
        
        self.projectMembers = members
    }
    
    private func fetchUser(phoneNumber: String) async -> User? {
        do {
            let userSnapshot = try await db
                .collection(FirebaseCollections.users)
                .whereField("phoneNumber", isEqualTo: phoneNumber)
                .limit(to: 1)
                .getDocuments()
            
            if let document = userSnapshot.documents.first {
                return try document.data(as: User.self)
            }
        } catch {
            print("Error fetching user \(phoneNumber): \(error)")
        }
        
        return nil
    }
    
    private func createOrGetGroupChat(projectId: String, chatId: String) async throws -> Chat {
        let chatRef = db.collection("projects_ios")
            .document(projectId)
            .collection("chats")
            .document(chatId)
        
        let snapshot = try await chatRef.getDocument()
        
        if let existingChat = try? snapshot.data(as: Chat.self) {
            return existingChat
        }
        
        // Create new group chat
        let newChat = Chat(
            id: chatId,
            type: .group,
            participants: projectMembers.map { $0.phoneNumber },
            lastMessage: nil,
            lastTimestamp: nil
        )
        
        try await chatRef.setData([
            "id": newChat.id ?? "",
            "type": newChat.type.rawValue,
            "participants": newChat.participants,
            "lastMessage": newChat.lastMessage ?? "",
            "lastTimestamp": newChat.lastTimestamp ?? NSNull()
        ])
        
        return newChat
    }
    
    private func sendMessageAsync(
        projectId: String,
        chatId: String,
        senderId: String,
        text: String? = nil,
        media: [String]? = nil,
        replyTo: String? = nil,
        mentions: [String]? = nil,
        isGroupMessage: Bool = true
    ) async throws {
        let messageRef = db.collection("projects_ios")
            .document(projectId)
            .collection("chats")
            .document(chatId)
            .collection("messages")
            .document()
        
        let message = Message(
            id: messageRef.documentID,
            senderId: senderId,
            text: text,
            media: media,
            timestamp: Date(),
            isRead: false,
            type: text != nil ? .text : .file,
            replyTo: replyTo,
            mentions: mentions,
            isGroupMessage: isGroupMessage
        )
        
        try messageRef.setData(from: message)
        
        // Update last message in chat
        try await db.collection("projects_ios")
            .document(projectId)
            .collection("chats")
            .document(chatId)
            .updateData([
                "lastMessage": text ?? "Attachment",
                "lastTimestamp": Date()
            ])
    }
    
    private func loadMessagesAsync(projectId: String, chatId: String) async throws -> [Message] {
        let snapshot = try await db.collection("projects_ios")
            .document(projectId)
            .collection("chats")
            .document(chatId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .getDocuments()
        
        let messages: [Message] = snapshot.documents.compactMap { doc in
            try? doc.data(as: Message.self)
        }
        
        return messages
    }
    
    private func startListeningToMessages(projectId: String, chatId: String) {
        messageListener?.remove()
        
        messageListener = db.collection("projects_ios")
            .document(projectId)
            .collection("chats")
            .document(chatId)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening to group messages: \(error)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                let messages = snapshot.documents.compactMap { doc in
                    try? doc.data(as: Message.self)
                }
                
                Task { @MainActor in
                    self.messages = messages
                }
            }
    }
}
