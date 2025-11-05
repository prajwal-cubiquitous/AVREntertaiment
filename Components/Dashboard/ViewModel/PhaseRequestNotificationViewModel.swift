//
//  PhaseRequestNotificationViewModel.swift
//  AVREntertainment
//
//  Created by Auto on 1/2/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// Simple struct to represent phase request as stored in Firebase
struct PhaseRequestItem: Identifiable {
    let id: String
    let phaseId: String
    let phaseName: String
    let reason: String
    let extendedDate: String // Format: "dd/MM/yyyy"
    let userID: String
    let createdAt: Timestamp
}

@MainActor
class PhaseRequestNotificationViewModel: ObservableObject {
    @Published var pendingRequests: [PhaseRequestItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var pendingRequestsCount: Int {
        pendingRequests.count
    }
    
    func loadPendingRequests(projectId: String, customerId: String?) async {
        guard let customerId = customerId else {
            print("❌ Customer ID not found in loadPendingRequests")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Get all phases for this project
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .getDocuments()
            
            var allRequests: [PhaseRequestItem] = []
            
            // For each phase, fetch pending requests from its requests subcollection
            for phaseDoc in phasesSnapshot.documents {
                let phaseId = phaseDoc.documentID
                guard let phase = try? phaseDoc.data(as: Phase.self) else { continue }
                
                // Fetch pending requests from phases/{phaseId}/requests
                let requestsSnapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .document(phaseId)
                    .collection("requests")
                    .whereField("status", isEqualTo: "PENDING")
                    .order(by: "createdAt", descending: true)
                    .getDocuments()
                
                for requestDoc in requestsSnapshot.documents {
                    let requestData = requestDoc.data()
                    let requestId = requestDoc.documentID
                    
                    // Extract request fields (matching Firebase structure)
                    if let reason = requestData["reason"] as? String,
                       let extendedDate = requestData["extendedDate"] as? String,
                       let userID = requestData["userID"] as? String,
                       let createdAt = requestData["createdAt"] as? Timestamp {
                        
                        let requestItem = PhaseRequestItem(
                            id: requestId,
                            phaseId: phaseId,
                            phaseName: phase.phaseName,
                            reason: reason,
                            extendedDate: extendedDate,
                            userID: userID,
                            createdAt: createdAt
                        )
                        allRequests.append(requestItem)
                    }
                }
            }
            
            // Sort by creation date (most recent first)
            allRequests.sort { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
            
            self.pendingRequests = allRequests
            self.isLoading = false
            
        } catch {
            self.errorMessage = "Failed to load phase requests: \(error.localizedDescription)"
            self.isLoading = false
            print("Error loading phase requests: \(error)")
        }
    }
}

