//
//  Customer.swift
//  AVREntertainment
//
//  Created by AI on 10/30/25.
//

import Foundation
import FirebaseFirestore

/// Represents a customer entity stored in Firestore
struct Customer: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var email: String?
    var createdAt: Date

    init(name: String, email: String? = nil, createdAt: Date = Date()) {
        self.name = name
        self.email = email
        self.createdAt = createdAt
    }
}


