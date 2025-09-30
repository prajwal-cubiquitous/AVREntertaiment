//
//  chat.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 9/29/25.
//

import Foundation
import FirebaseFirestore

// MARK: - Message Model
struct Message: Identifiable, Codable {
    @DocumentID var id: String?               // Firestore document ID
    var senderId: String
    var text: String?
    var media: [String]?
    var timestamp: Date?
    var isRead: Bool
    var type: MessageType
    var replyTo: String?                      // optional messageId

    enum MessageType: String, Codable {
        case text
        case image
        case video
        case file
    }
}

// MARK: - Chat Model
struct Chat: Identifiable, Codable {
    @DocumentID var id: String?
    var type: ChatType
    var participants: [String]               // userIds
    var lastMessage: String?
    var lastTimestamp: Date?
    
    enum ChatType: String, Codable {
        case individual
        case group
    }
}
