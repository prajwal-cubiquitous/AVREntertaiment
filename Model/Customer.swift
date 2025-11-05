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
    var email: String
    var phoneNumber: String?
    var businessName: String
    var location: String?
    var createdAt: Timestamp
    var updatedAt: Timestamp

    init(name: String, email: String, phoneNumber: String? = nil, businessName: String, location: String? = nil) {
        self.name = name
        self.email = email
        self.phoneNumber = phoneNumber
        self.businessName = businessName
        self.location = location
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
    }
}