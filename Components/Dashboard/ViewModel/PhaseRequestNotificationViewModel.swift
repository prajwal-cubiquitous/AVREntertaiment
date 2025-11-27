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
    let userName: String?
    let userPhoneNumber: String?
    let createdAt: Timestamp
}

enum RequestAction {
    case accept
    case reject
}

@MainActor
class PhaseRequestNotificationViewModel: ObservableObject {
    @Published var pendingRequests: [PhaseRequestItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var reasonToReact: String = ""
    
    var pendingRequestsCount: Int {
        pendingRequests.count
    }
    
    func handleRequestAction(
        request: PhaseRequestItem,
        projectId: String,
        customerId: String?,
        action: RequestAction,
        reason: String
    ) async {
        // Debug logging
        print("🔄 handleRequestAction called with action: \(action == .accept ? "ACCEPT" : "REJECT")")
        print("📋 Request ID: \(request.id), Phase ID: \(request.phaseId), Project ID: \(projectId)")
        
        guard let customerId = customerId else {
            print("❌ Customer ID not found in handleRequestAction")
            return
        }
        
        guard let currentUserUID = Auth.auth().currentUser?.uid else {
            print("❌ Current user UID not found")
            return
        }
        
        do {
            let db = Firestore.firestore()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            
            // Update request status
            let requestRef = FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .document(request.phaseId)
                .collection("requests")
                .document(request.id)
            
            // Determine status based on action - explicitly check both cases
            let status: String
            if action == .accept {
                status = "ACCEPTED"
                print("✅ Setting status to ACCEPTED")
            } else {
                status = "REJECTED"
                print("❌ Setting status to REJECTED")
            }
            
            // Update request document (reason is optional)
            var updateData: [String: Any] = [
                "status": status,
                "updatedAt": Timestamp()
            ]
            
            // Only add reasonToReact if it's not empty
            if !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updateData["reasonToReact"] = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            print("💾 Updating request with data: status=\(status), hasReason=\(!reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)")
            try await requestRef.updateData(updateData)
            print("✅ Request updated successfully with status: \(status)")
            
            // If accepted, update phase end date and log to changes collection
            if action == .accept {
                // Use the extendedDate directly from request (already in "dd/MM/yyyy" format)
                // Don't parse and reformat to avoid any date conversion issues
                let extendedDateStr = request.extendedDate
                
                // Get current phase to get previous end date
                let phaseRef = FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .document(request.phaseId)
                
                let phaseDoc = try await phaseRef.getDocument()
                
                if let phaseData = phaseDoc.data(),
                   let previousEndDate = phaseData["endDate"] as? String {
                    
                    // Update phase end date
                    try await phaseRef.updateData([
                        "endDate": extendedDateStr,
                        "updatedAt": Timestamp()
                    ])
                    
                    // Log to changes collection with requestID
                    let changeLog = PhaseTimelineChange(
                        phaseId: request.phaseId,
                        projectId: projectId,
                        previousStartDate: phaseData["startDate"] as? String,
                        previousEndDate: previousEndDate,
                        newStartDate: phaseData["startDate"] as? String,
                        newEndDate: extendedDateStr,
                        changedBy: currentUserUID,
                        requestID: request.id
                    )
                    
                    let changesRef = phaseRef.collection("changes").document()
                    try await changesRef.setData(from: changeLog)
                } else {
                    // If phase doesn't exist, create it with the new end date
                    try await phaseRef.setData([
                        "endDate": extendedDateStr,
                        "updatedAt": Timestamp()
                    ], merge: true)
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to \(action == .accept ? "accept" : "reject") request: \(error.localizedDescription)"
            }
        }
    }
    
    func loadPendingRequests(projectId: String, customerId: String?) async {
        guard let customerId = customerId else {
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
                        
                        // Fetch user details from users collection
                        var userName: String? = nil
                        var userPhoneNumber: String? = nil
                        
                        do {
                            let db = Firestore.firestore()
                            var userDoc: DocumentSnapshot? = nil
                            
                            // Clean phone number if needed
                            var cleanUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
                            if cleanUserID.hasPrefix("+91") {
                                cleanUserID = String(cleanUserID.dropFirst(3))
                            }
                            cleanUserID = cleanUserID.trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Try multiple approaches to find the user
                            // 1. Try document ID with cleaned phone number
                            userDoc = try await db.collection("users")
                                .document(cleanUserID)
                                .getDocument()
                            
                            // 2. If not found, try original userID as document ID
                            if userDoc == nil || !userDoc!.exists {
                                userDoc = try await db.collection("users")
                                    .document(userID)
                                    .getDocument()
                            }
                            
                            // 3. If still not found, query by phoneNumber field
                            if userDoc == nil || !userDoc!.exists {
                                let userQuery = try await db.collection("users")
                                    .whereField("phoneNumber", isEqualTo: cleanUserID)
                                    .limit(to: 1)
                                    .getDocuments()
                                
                                if let firstDoc = userQuery.documents.first {
                                    userDoc = try await db.collection("users")
                                        .document(firstDoc.documentID)
                                        .getDocument()
                                }
                            }
                            
                            // 4. Try querying by phoneNumber field with original userID
                            if userDoc == nil || !userDoc!.exists {
                                let userQuery = try await db.collection("users")
                                    .whereField("phoneNumber", isEqualTo: userID)
                                    .limit(to: 1)
                                    .getDocuments()
                                
                                if let firstDoc = userQuery.documents.first {
                                    userDoc = try await db.collection("users")
                                        .document(firstDoc.documentID)
                                        .getDocument()
                                }
                            }
                            
                            if let userDoc = userDoc, userDoc.exists {
                                // Try to decode as User model first
                                if let user = try? userDoc.data(as: User.self) {
                                    userName = user.name
                                    userPhoneNumber = user.phoneNumber
                                } else if let userData = userDoc.data() {
                                    // Fallback to manual field extraction
                                    userName = userData["name"] as? String
                                    userPhoneNumber = userData["phoneNumber"] as? String ?? cleanUserID
                                }
                                
                            }
                        } catch {
                            // Continue without user details
                        }
                        
                        let requestItem = PhaseRequestItem(
                            id: requestId,
                            phaseId: phaseId,
                            phaseName: phase.phaseName,
                            reason: reason,
                            extendedDate: extendedDate,
                            userID: userID,
                            userName: userName,
                            userPhoneNumber: userPhoneNumber,
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
    
    /// Load a specific request by ID from phase's requests subcollection
    /// Searches through all phases in the project to find the request
    /// Returns the request and its projectId
    func loadRequestFromPhaseSubcollection(requestId: String, projectId: String, customerId: String) async -> (PhaseRequestItem, String)? {
        do {
            // Get all phases for this project
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .getDocuments()
            
            // Search through all phases to find the request
            for phaseDoc in phasesSnapshot.documents {
                let phaseId = phaseDoc.documentID
                guard let phase = try? phaseDoc.data(as: Phase.self) else { continue }
                
                // Try to get the request from this phase's requests subcollection
                let requestDoc = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .document(phaseId)
                    .collection("requests")
                    .document(requestId)
                    .getDocument()
                
                if requestDoc.exists, let requestData = requestDoc.data() {
                    // Found the request!
                    if let reason = requestData["reason"] as? String,
                       let extendedDate = requestData["extendedDate"] as? String,
                       let userID = requestData["userID"] as? String,
                       let createdAt = requestData["createdAt"] as? Timestamp {
                        
                        // Fetch user details
                        var userName: String? = nil
                        var userPhoneNumber: String? = nil
                        
                        do {
                            var cleanUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
                            if cleanUserID.hasPrefix("+91") {
                                cleanUserID = String(cleanUserID.dropFirst(3))
                            }
                            cleanUserID = cleanUserID.trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            let db = Firestore.firestore()
                            let userDoc = try await db.collection("users")
                                .document(cleanUserID)
                                .getDocument()
                            
                            if userDoc.exists {
                                if let user = try? userDoc.data(as: User.self) {
                                    userName = user.name
                                    userPhoneNumber = user.phoneNumber
                                } else if let userData = userDoc.data() {
                                    userName = userData["name"] as? String
                                    userPhoneNumber = userData["phoneNumber"] as? String ?? cleanUserID
                                }
                            }
                        } catch {
                            // Continue without user details
                        }
                        
                        let request = PhaseRequestItem(
                            id: requestId,
                            phaseId: phaseId,
                            phaseName: phase.phaseName,
                            reason: reason,
                            extendedDate: extendedDate,
                            userID: userID,
                            userName: userName,
                            userPhoneNumber: userPhoneNumber,
                            createdAt: createdAt
                        )
                        
                        return (request, projectId)
                    }
                }
            }
            
            return nil
        } catch {
            print("Error loading request from phase subcollection: \(error)")
            return nil
        }
    }
    
    /// Load a specific request by ID from customer's requests collection
    /// Returns the request and its projectId
    func loadRequestByIdWithProject(requestId: String, customerId: String) async -> (PhaseRequestItem, String)? {
        do {
            let db = Firestore.firestore()
            let requestDoc = try await db
                .collection("customers")
                .document(customerId)
                .collection("requests")
                .document(requestId)
                .getDocument()
            
            guard requestDoc.exists,
                  let requestData = requestDoc.data(),
                  let reason = requestData["reason"] as? String,
                  let extendedDate = requestData["extendedDate"] as? String,
                  let userID = requestData["userID"] as? String,
                  let phaseId = requestData["phaseId"] as? String,
                  let projectId = requestData["projectId"] as? String,
                  let createdAt = requestData["createdAt"] as? Timestamp else {
                return nil
            }
            
            // Get phase name
            var phaseName = "Unknown Phase"
            let phaseDoc = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .document(phaseId)
                .getDocument()
            
            if let phase = try? phaseDoc.data(as: Phase.self) {
                phaseName = phase.phaseName
            }
            
            // Fetch user details
            var userName: String? = nil
            var userPhoneNumber: String? = nil
            
            do {
                var cleanUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanUserID.hasPrefix("+91") {
                    cleanUserID = String(cleanUserID.dropFirst(3))
                }
                cleanUserID = cleanUserID.trimmingCharacters(in: .whitespacesAndNewlines)
                
                let userDoc = try await db.collection("users")
                    .document(cleanUserID)
                    .getDocument()
                
                if userDoc.exists {
                    if let user = try? userDoc.data(as: User.self) {
                        userName = user.name
                        userPhoneNumber = user.phoneNumber
                    } else if let userData = userDoc.data() {
                        userName = userData["name"] as? String
                        userPhoneNumber = userData["phoneNumber"] as? String ?? cleanUserID
                    }
                }
            } catch {
                // Continue without user details
            }
            
            let request = PhaseRequestItem(
                id: requestId,
                phaseId: phaseId,
                phaseName: phaseName,
                reason: reason,
                extendedDate: extendedDate,
                userID: userID,
                userName: userName,
                userPhoneNumber: userPhoneNumber,
                createdAt: createdAt
            )
            
            return (request, projectId)
        } catch {
            print("Error loading request by ID: \(error)")
            return nil
        }
    }
}

