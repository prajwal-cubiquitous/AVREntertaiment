import Foundation
import FirebaseFirestore
import SwiftUI

@MainActor
class TempApproverService: ObservableObject {
    private let db = Firestore.firestore()
    
    // MARK: - Public Methods
    
    /// Check if a temp approver period has expired
    func isTempApproverExpired(_ tempApprover: TempApprover) -> Bool {
        return Date() > tempApprover.endDate
    }
    
    /// Check if a temp approver period is currently active
    func isTempApproverActive(_ tempApprover: TempApprover) -> Bool {
        let now = Date()
        return now >= tempApprover.startDate && now <= tempApprover.endDate && (tempApprover.status == .accepted || tempApprover.status == .active)
    }
    
    /// Get temp approver data for a specific project
    func getTempApproverForProject(projectId: String, approverId: String) async -> TempApprover? {
        do {
            let tempApproverSnapshot = try await db
                .collection(FirebaseCollections.projects)
                .document(projectId)
                .collection("tempApprover")
                .whereField("approverId", isEqualTo: approverId)
                .whereField("status", isEqualTo: "pending")
                .limit(to: 1)
                .getDocuments()
            
            if let tempApproverDoc = tempApproverSnapshot.documents.first,
               let tempApprover = try? tempApproverDoc.data(as: TempApprover.self) {
                return tempApprover
            }
        } catch {
            print("❌ Error fetching temp approver data: \(error)")
        }
        
        return nil
    }
    
    /// Update temp approver status
    func updateTempApproverStatus(projectId: String, approverId: String, status: TempApproverStatus, rejectionReason: String? = nil) async -> Bool {
        do {
            
            print("Entering into the update tempapprover collection")
            let tempApproverSnapshot = try await db
                .collection(FirebaseCollections.projects)
                .document(projectId)
                .collection("tempApprover")
                .whereField("approverId", isEqualTo: approverId)
                .whereField("status", isEqualTo: "pending")
                .limit(to: 1)
                .getDocuments()
            
            guard let tempApproverDoc = tempApproverSnapshot.documents.first else {
                print("❌ No temp approver document found")
                return false
            }
            
            var updateData: [String: Any] = [
                "status": status.rawValue,
                "updatedAt": Date()
            ]
            
            if let reason = rejectionReason {
                updateData["rejectionReason"] = reason
            }
            
            try await tempApproverDoc.reference.updateData(updateData)
            
            // If rejected or expired, remove tempApproverID from project
            if status == .rejected || status == .expired {
                try await db
                    .collection(FirebaseCollections.projects)
                    .document(projectId)
                    .updateData([
                        "tempApproverID": FieldValue.delete()
                    ])
            }
            
            return true
        } catch {
            print("❌ Error updating temp approver status: \(error)")
            return false
        }
    }
    
    /// Create a new temp approver assignment
    func createTempApprover(projectId: String, approverId: String, startDate: Date, endDate: Date) async -> Bool {
        do {
            let tempApprover = TempApprover(
                approverId: approverId,
                startDate: startDate,
                endDate: endDate,
                status: .pending
            )
            
            try await db
                .collection(FirebaseCollections.projects)
                .document(projectId)
                .collection("tempApprover")
                .addDocument(from: tempApprover)
            
            // Update project with tempApproverID
            try await db
                .collection(FirebaseCollections.projects)
                .document(projectId)
                .updateData([
                    "tempApproverID": approverId
                ])
            
            return true
        } catch {
            print("❌ Error creating temp approver: \(error)")
            return false
        }
    }
    
    /// Get all temp approver assignments for a user
    func getTempApproverAssignments(for approverId: String) async -> [(Project, TempApprover)] {
        var assignments: [(Project, TempApprover)] = []
        
        do {
            // First get all projects where this user is temp approver
            let projectsSnapshot = try await db
                .collection(FirebaseCollections.projects)
                .whereField("tempApproverID", isEqualTo: approverId)
                .getDocuments()
            
            for projectDoc in projectsSnapshot.documents {
                if var project = try? projectDoc.data(as: Project.self) {
                    project.id = projectDoc.documentID
                    
                    // Get temp approver data
                    if let tempApprover = await getTempApproverForProject(
                        projectId: projectDoc.documentID,
                        approverId: approverId
                    ) {
                        assignments.append((project, tempApprover))
                    }
                }
            }
        } catch {
            print("❌ Error fetching temp approver assignments: \(error)")
        }
        
        return assignments
    }
    
    /// Clean up expired temp approvers
    func cleanupExpiredTempApprovers() async {
        do {
            // Get all projects with tempApproverID
            let projectsSnapshot = try await db
                .collection(FirebaseCollections.projects)
                .whereField("tempApproverID", isNotEqualTo: FieldValue.delete())
                .getDocuments()
            
            for projectDoc in projectsSnapshot.documents {
                if let project = try? projectDoc.data(as: Project.self),
                   let tempApproverID = project.tempApproverID {
                    
                    if let tempApprover = await getTempApproverForProject(
                        projectId: projectDoc.documentID,
                        approverId: tempApproverID
                    ) {
                        // Check if expired
                        if isTempApproverExpired(tempApprover) {
                            // Update status to expired
                            await updateTempApproverStatus(
                                projectId: projectDoc.documentID,
                                approverId: tempApproverID,
                                status: .expired
                            )
                            
                            db.collection(FirebaseCollections.projects).document(projectDoc.documentID).updateData([
                                    "tempApproverID": FieldValue.delete()
                                ]) { error in
                                    if let error = error {
                                        print("Error deleting field: \(error)")
                                    } else {
                                        print("Field successfully deleted!")
                                    }
                                }
                        }
                    }
                }
            }
        } catch {
            print("❌ Error cleaning up expired temp approvers: \(error)")
        }
    }
    
    /// Validate temp approver dates
    func validateTempApproverDates(startDate: Date, endDate: Date) -> (isValid: Bool, errorMessage: String?) {
        let now = Date()
        
        // Check if start date is in the past
        if startDate < now {
            return (false, "Start date cannot be in the past")
        }
        
        // Check if end date is before start date
        if endDate <= startDate {
            return (false, "End date must be after start date")
        }
        
        // Check if the period is too long (e.g., more than 30 days)
        let calendar = Calendar.current
        let daysDifference = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        
        if daysDifference > 30 {
            return (false, "Temporary approver period cannot exceed 30 days")
        }
        
        return (true, nil)
    }
}

// MARK: - Extensions

extension TempApproverService {
    /// Get formatted duration text for temp approver period
    func getDurationText(from startDate: Date, to endDate: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour], from: startDate, to: endDate)
        
        if let days = components.day, days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "Less than 1 hour"
        }
    }
    
    /// Get status color for temp approver
    func getStatusColor(for status: TempApproverStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .accepted: return .green
        case .rejected: return .red
        case .active: return .blue
        case .expired: return .gray
        }
    }
    
    /// Get status icon for temp approver
    func getStatusIcon(for status: TempApproverStatus) -> String {
        switch status {
        case .pending: return "clock.fill"
        case .accepted: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .active: return "person.badge.clock.fill"
        case .expired: return "exclamationmark.triangle.fill"
        }
    }
}
