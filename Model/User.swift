//
//  User.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/26/25.
//

import Foundation
import FirebaseFirestore

enum UserRole: String, CaseIterable, Codable {
    case ADMIN = "ADMIN"
    case APPROVER = "APPROVER" 
    case USER = "USER"
    
    var displayName: String {
        switch self {
        case .ADMIN: return "Admin"
        case .APPROVER: return "Approver"
        case .USER: return "User"
        }
    }
}

struct User: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var phoneNumber: String
    var name: String
    var role: UserRole
    var createdAt: Date
    var isActive: Bool
    
    // Only for ADMIN users (email-based login)
    var email: String?
    
    init(phoneNumber: String, name: String, role: UserRole, email: String? = nil) {
        self.phoneNumber = phoneNumber
        self.name = name
        self.role = role
        self.email = email
        self.createdAt = Date()
        self.isActive = true
    }
    
    // Admin initializer (no Firebase document needed)
    static func adminUser(email: String, name: String = "Admin") -> User {
        return User(phoneNumber: "", name: name, role: .ADMIN, email: email)
    }
    
    func hash(into hasher: inout Hasher) {
        if role == .ADMIN, let email = email {
            hasher.combine(email)
        } else {
            hasher.combine(phoneNumber)
        }
        hasher.combine(role)
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        if lhs.role == .ADMIN && rhs.role == .ADMIN {
            return lhs.email == rhs.email
        } else {
            return lhs.phoneNumber == rhs.phoneNumber && lhs.role == rhs.role
        }
    }
    
    // Sample data for preview
    static let sampleData: [User] = [
        User(phoneNumber: "9876543210", name: "John Doe", role: .APPROVER),
        User(phoneNumber: "9876543211", name: "Jane Smith", role: .APPROVER),
        User(phoneNumber: "9876543212", name: "Mike Johnson", role: .USER)
    ]
}
