//
//  ExpenseChat.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/26/25.
//

import Foundation

struct ExpenseChat: Identifiable, Codable, Equatable {
    let id: String // Document ID
    let textMessage: String
    let mediaURL: [String]
    let timeStamp: Date
    let mention: [String]
    let senderId: String
    let senderRole: UserRole
    
    init(id: String = UUID().uuidString, textMessage: String, mediaURL: [String] = [], timeStamp: Date = Date(), mention: [String] = [], senderId: String = "", senderRole: UserRole) {
        self.id = id
        self.textMessage = textMessage
        self.mediaURL = mediaURL
        self.timeStamp = timeStamp
        self.mention = mention
        self.senderId = senderId
        self.senderRole = senderRole
    }
    
    // Equatable conformance - compare by ID since that's unique
    static func == (lhs: ExpenseChat, rhs: ExpenseChat) -> Bool {
        return lhs.id == rhs.id
    }
}
