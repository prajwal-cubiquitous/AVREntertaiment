//
//  IndividualChatViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 9/29/25.
//

import Foundation
import FirebaseFirestore
import SwiftUI

@MainActor
class IndividualChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var chat: Chat?
    
    private let db = Firestore.firestore()
    private let currentUserPhone: String
    
    init() {
        self.currentUserPhone = UserDefaults.standard.string(forKey: "currentUserPhone") ?? ""
    }
    
    func loadMessages(for participant: ChatParticipant, project: Project) async {
        isLoading = true
        errorMessage = nil
        
        // Create or get chat
        await createOrGetChat(participant: participant, project: project)
        
        // For now, load sample messages
        // TODO: Implement Firebase real-time messaging
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.messages = self.sampleMessages
            self.isLoading = false
        }
    }
    
    func sendMessage(_ message: Message) {
        messages.append(message)
        // TODO: Send to Firebase and update chat
    }
    
    private func createOrGetChat(participant: ChatParticipant, project: Project) async {
        // Create chat ID based on participants
        let participants = [currentUserPhone, participant.phoneNumber].sorted()
        let chatId = "\(participants[0])_\(participants[1])_\(project.id ?? "")"
        
        do {
            // Try to get existing chat
            let chatDoc = try await db.collection("chats").document(chatId).getDocument()
            
            if chatDoc.exists {
                self.chat = try chatDoc.data(as: Chat.self)
            } else {
                // Create new chat
                let newChat = Chat(
                    type: .individual,
                    participants: participants,
                    lastMessage: nil,
                    lastTimestamp: nil
                )
                
                try await db.collection("chats").document(chatId).setData(from: newChat)
                self.chat = newChat
            }
        } catch {
            print("Error creating/getting chat: \(error)")
            errorMessage = "Failed to load chat"
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
                replyTo: nil
            ),
            Message(
                senderId: currentUserPhone,
                text: "Great! We're making good progress on the budget allocation.",
                media: nil,
                timestamp: Date().addingTimeInterval(-3500),
                isRead: true,
                type: .text,
                replyTo: nil
            ),
            Message(
                senderId: "9876543210",
                text: "That's awesome! Let me know if you need any help with the approvals.",
                media: nil,
                timestamp: Date().addingTimeInterval(-3400),
                isRead: true,
                type: .text,
                replyTo: nil
            ),
            Message(
                senderId: currentUserPhone,
                text: "Thanks! I'll keep you updated.",
                media: nil,
                timestamp: Date().addingTimeInterval(-3300),
                isRead: true,
                type: .text,
                replyTo: nil
            )
        ]
    }
}
