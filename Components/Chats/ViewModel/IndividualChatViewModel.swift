//
//  IndividualChatViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 9/29/25.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

import SwiftUI

@MainActor
class IndividualChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var chat: Chat?
    @Published var isSendingMessage = false
    
    private let db = Firestore.firestore()
    private let currentUserPhone: String?
    @Published var role: UserRole
    private var messageListener: ListenerRegistration?
    private var project: Project?
    private var authService: FirebaseAuthService?
    
    init(currentUserPhone: String?, role: UserRole, authService: FirebaseAuthService? = nil) {
        self.currentUserPhone = currentUserPhone
        self.role = role
        self.authService = authService
    }
    
    func setAuthService(_ authService: FirebaseAuthService) {
        self.authService = authService
    }
    
    deinit {
        messageListener?.remove()
    }
    
//    func sendMessage(_ message: Message) {
//        messages.append(message)
//        // TODO: Send to Firebase and update chat
//    }
//    
//    private func createOrGetChat(participant: ChatParticipant, project: Project) async {
//        // Create chat ID based on participants
//        let participants = [currentUserPhone ?? "Admin", participant.phoneNumber].sorted()
//        let chatId = "\(participants[0])_\(participants[1])_\(project.id ?? "")"
//        
//        do {
//            // Try to get existing chat
//            let chatDoc = try await db.collection("chats").document(chatId).getDocument()
//            
//            if chatDoc.exists {
//                self.chat = try chatDoc.data(as: Chat.self)
//            } else {
//                // Create new chat
//                let newChat = Chat(
//                    type: .individual,
//                    participants: participants,
//                    lastMessage: nil,
//                    lastTimestamp: nil
//                )
//                
//                try db.collection("chats").document(chatId).setData(from: newChat)
//                self.chat = newChat
//            }
//        } catch {
//            print("Error creating/getting chat: \(error)")
//            errorMessage = "Failed to load chat"
//        }
//    }

    func startOrFetchChatAsync(
        with phoneNumber: String,
        currentUserPhone: String?,   // current user's phone
        currentUserId: String?,      // optional UID
        project: Project,
        role: UserRole
    ) async throws -> Chat? {
        let db = Firestore.firestore()
        
        guard let projectId = project.id else { return nil }
        
        // 1️⃣ Handle special case for "Admin" participant
        let otherUserId: String
        if phoneNumber == "Admin" || phoneNumber == "123" {
            otherUserId = "Admin"
        } else {
            // Lookup other user's phone number by phone number (it's already the phone number)
            // The phoneNumber parameter is already the phone number we need
            otherUserId = phoneNumber
        }
        
        // 2️⃣ Build participants deterministically using phone numbers
        // Use "Admin" string when role is ADMIN, otherwise use the actual phone number
        let myPhoneIdentifier: String = {
            if role == .ADMIN { return "Admin" }
            return currentUserPhone?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }()

        var participantPhones: [String] = [myPhoneIdentifier, otherUserId]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()

        // If after filtering we don't have exactly two valid identifiers, bail out safely
        guard participantPhones.count == 2 else {
            print("Invalid participants for chat: role=\(role) my=\(myPhoneIdentifier) other=\(otherUserId)")
            return nil
        }

        // For participants meta, mirror phone identifiers for now (consistent identity)
        let participants: [String] = participantPhones
        
        // 3️⃣ Deterministic Chat Document ID using phone identifiers
        let chatId = participantPhones.joined(separator: "_")
        let chatRef = db.collection("projects_ios")
            .document(projectId)
            .collection("chats")
            .document(chatId)
        
        // 4️⃣ Check if chat exists
        let snapshot = try await chatRef.getDocument()
        if let existingChat = try? snapshot.data(as: Chat.self) {
            return existingChat
        }
        
        // 5️⃣ Create new chat
        let newChat = Chat(
            id: chatId,
            type: .individual,
            participants: participants,
            lastMessage: nil,
            lastTimestamp: nil
        )
        
        try await chatRef.setData([
            "id": chatId,
            "type": newChat.type.rawValue,
            "participants": newChat.participants,
            "lastMessage": newChat.lastMessage ?? "",
            "lastTimestamp": newChat.lastTimestamp ?? NSNull()
        ])
        
        return newChat
    }
    
    func sendMessageAsync(
        projectId: String,
        chatId: String,
        senderId: String,
        text: String? = nil,
        media: [String]? = nil,
        replyTo: String? = nil,
        mentions: [String]? = nil,
        isGroupMessage: Bool = false
    ) async throws {
        let db = Firestore.firestore()
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
                "lastMessage": text ?? "Attachment" as Any,
                "lastTimestamp": Date()
            ])
    }
    
    func loadMessagesAsync(projectId: String, chatId: String) async throws -> [Message] {
        let db = Firestore.firestore()
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
    
    func listenToMessages(projectId: String, chatId: String) -> AsyncStream<[Message]> {
        let db = Firestore.firestore()
        
        return AsyncStream { continuation in
            let listener = db.collection("projects_ios")
                .document(projectId)
                .collection("chats")
                .document(chatId)
                .collection("messages")
                .order(by: "timestamp")
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("Error listening to messages: \(error)")
                        return
                    }
                    
                    guard let snapshot = snapshot else { return }
                    let messages = snapshot.documents.compactMap { doc in
                        try? doc.data(as: Message.self)
                    }
                    continuation.yield(messages)
                }
            
            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
    
    func uploadMediaAsync(_ data: Data, path: String) async throws -> String {
        print("🔐 Checking authentication before upload...")
        
        // Check if user is authenticated via Firebase Auth
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No authenticated user found in Firebase Auth")
            
            // Check auth service state
            if let authService = authService {
                print("🔍 Auth service state: isAuthenticated=\(authService.isAuthenticated)")
                if authService.isAuthenticated {
                    print("⚠️ Auth service says user is authenticated but Firebase Auth says no user")
                    print("🔄 This might be a timing issue. Retrying in 2 seconds...")
                    
                    // Wait and try again
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    
                    if let retryUser = Auth.auth().currentUser {
                        print("✅ Retry successful: \(retryUser.uid)")
                        return try await performUpload(data: data, path: path)
                    }
                }
            }
            
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated. Please log in again."])
        }
        
        print("✅ User authenticated: \(currentUser.uid)")
        return try await performUpload(data: data, path: path)
    }
    
    private func performUpload(data: Data, path: String) async throws -> String {
        let storageRef = Storage.storage().reference().child(path)
        
        // Add metadata for better organization
        let metadata = StorageMetadata()
        metadata.contentType = getContentType(for: path)
        
        print("📤 Uploading to path: \(path)")
        _ = try await storageRef.putDataAsync(data, metadata: metadata)
        let url = try await storageRef.downloadURL()
        print("✅ Upload successful: \(url.absoluteString)")
        return url.absoluteString
    }
    
    private func getContentType(for path: String) -> String {
        let fileExtension = path.lowercased()
        if fileExtension.contains(".jpg") || fileExtension.contains(".jpeg") {
            return "image/jpeg"
        } else if fileExtension.contains(".png") {
            return "image/png"
        } else if fileExtension.contains(".mp4") {
            return "video/mp4"
        } else if fileExtension.contains(".pdf") {
            return "application/pdf"
        } else {
            return "application/octet-stream"
        }
    }
    
    // MARK: - Main Chat Functions
    
    func loadMessages(for participant: ChatParticipant, project: Project) async {
        // Set project immediately for UI
        self.project = project
        errorMessage = nil
        
        guard let projectId = project.id else {
            errorMessage = "Project ID not found"
            return
        }
        
        // Show loading state only briefly
        isLoading = true
        
        do {
            // Start or fetch chat
            let chat = try await startOrFetchChatAsync(
                with: participant.phoneNumber,
                currentUserPhone: currentUserPhone,
                currentUserId: nil, // We'll use phone numbers for now
                project: project,
                role: role
            )
            
            guard let chat = chat, let chatId = chat.id else {
                errorMessage = "Failed to create or find chat"
                isLoading = false
                return
            }
            
            self.chat = chat
            
            // Load existing messages in background
            Task {
                do {
                    let existingMessages = try await loadMessagesAsync(projectId: projectId, chatId: chatId)
                    await MainActor.run {
                        self.messages = existingMessages
                        self.isLoading = false
                    }
                    
                    // Start listening for new messages after loading existing ones
                    startListeningToMessages(projectId: projectId, chatId: chatId)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to load messages: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
            
        } catch {
            errorMessage = "Failed to create chat: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func sendMessage(_ message: Message) {
        guard let projectId = project?.id, let chatId = chat?.id else {
            errorMessage = "Chat not initialized"
            return
        }
        
        isSendingMessage = true
        
        Task {
            do {
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
                    print("Error listening to messages: \(error)")
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

    
    private var sampleMessages: [Message] {
        [
            Message(
                senderId: "9876543210",
                text: "Hey! How's the project going?",
                media: nil,
                timestamp: Date().addingTimeInterval(-3600),
                isRead: true,
                type: .text,
                replyTo: nil,
                mentions: nil,
                isGroupMessage: false
            ),
            Message(
                senderId: currentUserPhone ?? "Admin",
                text: "Great! We're making good progress on the budget allocation.",
                media: nil,
                timestamp: Date().addingTimeInterval(-3500),
                isRead: true,
                type: .text,
                replyTo: nil,
                mentions: nil,
                isGroupMessage: false
            ),
            Message(
                senderId: "9876543210",
                text: "That's awesome! Let me know if you need any help with the approvals.",
                media: nil,
                timestamp: Date().addingTimeInterval(-3400),
                isRead: true,
                type: .text,
                replyTo: nil,
                mentions: nil,
                isGroupMessage: false
            ),
            Message(
                senderId: currentUserPhone ?? "Admin",
                text: "Thanks! I'll keep you updated.",
                media: nil,
                timestamp: Date().addingTimeInterval(-3300),
                isRead: true,
                type: .text,
                replyTo: nil,
                mentions: nil,
                isGroupMessage: false
            )
        ]
    }
}
