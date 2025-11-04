//
//  PhaseRequest.swift
//  AVREntertainment
//
//  Created by Auto on 11/4/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore

struct PhaseRequest: Identifiable, Codable {
    @DocumentID var id: String?
    
    let projectId: String
    let phaseId: String
    let phaseName: String
    let requestedBy: String // User phone number
    let description: String
    let requestedExtensionDate: String // Format: "dd/MM/yyyy"
    let status: RequestStatus
    let remark: String? // Optional remark for approval/rejection
    
    // Firestore Timestamps
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    enum RequestStatus: String, Codable, CaseIterable {
        case pending = "PENDING"
        case approved = "APPROVED"
        case rejected = "REJECTED"
        
        var color: Color {
            switch self {
            case .pending: return .orange
            case .approved: return .green
            case .rejected: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .pending: return "clock"
            case .approved: return "checkmark.circle"
            case .rejected: return "xmark.circle"
            }
        }
    }
}

