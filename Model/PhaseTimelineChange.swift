//
//  PhaseTimelineChange.swift
//  AVREntertainment
//
//  Created by Auto on 1/2/25.
//

import Foundation
import FirebaseFirestore

/// Represents a timeline change log for a phase
struct PhaseTimelineChange: Identifiable, Codable {
    @DocumentID var id: String?
    
    let phaseId: String
    let projectId: String
    
    // Previous timeline values
    let previousStartDate: String? // Format: "dd/MM/yyyy"
    let previousEndDate: String?   // Format: "dd/MM/yyyy"
    
    // New timeline values
    let newStartDate: String?      // Format: "dd/MM/yyyy"
    let newEndDate: String?        // Format: "dd/MM/yyyy"
    
    // User who made the change
    let changedBy: String          // User UID
    
    // Request ID (if change was made via an accepted request)
    let requestID: String?          // Optional request ID
    
    // Timestamp
    let updatedAt: Timestamp
    
    init(
        phaseId: String,
        projectId: String,
        previousStartDate: String?,
        previousEndDate: String?,
        newStartDate: String?,
        newEndDate: String?,
        changedBy: String,
        requestID: String? = nil
    ) {
        self.phaseId = phaseId
        self.projectId = projectId
        self.previousStartDate = previousStartDate
        self.previousEndDate = previousEndDate
        self.newStartDate = newStartDate
        self.newEndDate = newEndDate
        self.changedBy = changedBy
        self.requestID = requestID
        self.updatedAt = Timestamp()
    }
}

