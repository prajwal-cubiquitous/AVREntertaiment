//
//  FirebasePathHelper.swift
//  AVREntertainment
//
//  Created by Auto on 11/4/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Helper class to build customer-specific Firebase collection paths
class FirebasePathHelper {
    static let shared = FirebasePathHelper()
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Get the projects collection reference for a specific customer
    /// - Parameter customerId: The customer ID (Firebase Auth UID for admin users)
    /// - Returns: CollectionReference for customers/{customerId}/projects
    func projectsCollection(customerId: String) -> CollectionReference {
        return db.collection("customers").document(customerId).collection("projects")
    }
    
    /// Get the users collection reference for a specific customer
    /// - Parameter customerId: The customer ID (Firebase Auth UID for admin users)
    /// - Returns: CollectionReference for customers/{customerId}/users
    func usersCollection(customerId: String) -> CollectionReference {
        return db.collection("users")
    }
    
    /// Get a project document reference
    /// - Parameters:
    ///   - customerId: The customer ID
    ///   - projectId: The project ID
    /// - Returns: DocumentReference for customers/{customerId}/projects/{projectId}
    func projectDocument(customerId: String, projectId: String) -> DocumentReference {
        return db.collection("customers").document(customerId).collection("projects").document(projectId)
    }
    
    /// Get an expenses subcollection reference for a project
    /// - Parameters:
    ///   - customerId: The customer ID
    ///   - projectId: The project ID
    /// - Returns: CollectionReference for customers/{customerId}/projects/{projectId}/expenses
    func expensesCollection(customerId: String, projectId: String) -> CollectionReference {
        return db.collection("customers").document(customerId).collection("projects").document(projectId).collection("expenses")
    }
    
    /// Get a phases subcollection reference for a project
    /// - Parameters:
    ///   - customerId: The customer ID
    ///   - projectId: The project ID
    /// - Returns: CollectionReference for customers/{customerId}/projects/{projectId}/phases
    func phasesCollection(customerId: String, projectId: String) -> CollectionReference {
        return db.collection("customers").document(customerId).collection("projects").document(projectId).collection("phases")
    }
    
    /// Get a requests subcollection reference for a project
    /// - Parameters:
    ///   - customerId: The customer ID
    ///   - projectId: The project ID
    /// - Returns: CollectionReference for customers/{customerId}/projects/{projectId}/requests
    func requestsCollection(customerId: String, projectId: String) -> CollectionReference {
        return db.collection("customers").document(customerId).collection("projects").document(projectId).collection("requests")
    }
    
    /// Get a chats subcollection reference for a project
    /// - Parameters:
    ///   - customerId: The customer ID
    ///   - projectId: The project ID
    /// - Returns: CollectionReference for customers/{customerId}/projects/{projectId}/chats
    func chatsCollection(customerId: String, projectId: String) -> CollectionReference {
        return db.collection("customers").document(customerId).collection("projects").document(projectId).collection("chats")
    }
    
    /// Get a departments subcollection reference for a phase
    /// - Parameters:
    ///   - customerId: The customer ID
    ///   - projectId: The project ID
    ///   - phaseId: The phase ID
    /// - Returns: CollectionReference for customers/{customerId}/projects/{projectId}/phases/{phaseId}/departments
    func departmentsCollection(customerId: String, projectId: String, phaseId: String) -> CollectionReference {
        return db.collection("customers")
            .document(customerId)
            .collection("projects")
            .document(projectId)
            .collection("phases")
            .document(phaseId)
            .collection("departments")
    }
    func fetchEffectiveUserID() async throws -> String {
            guard let currentUser = Auth.auth().currentUser else {
                throw NSError(domain: "AuthHelper", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
            }
            
            // If the user logged in via phone number
            if let phoneNumber = currentUser.phoneNumber {
                let formattedPhone = phoneNumber.replacingOccurrences(of: "+91", with: "")
                
                let docRef = Firestore.firestore()
                    .collection("users")
                    .document(formattedPhone)
                
                let document = try await docRef.getDocument()
                
                if let data = document.data(),
                   let ownerID = data["ownerID"] as? String {
                    return ownerID
                } else {
                    throw NSError(domain: "AuthHelper", code: 404, userInfo: [NSLocalizedDescriptionKey: "OwnerID not found for phone user"])
                }
            }
            
            // If email/password or other provider → return UID directly
            return currentUser.uid
        }
}
