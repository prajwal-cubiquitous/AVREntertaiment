//
//  ProjectListViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//

import SwiftUI
import FirebaseFirestore
import Combine

@MainActor
class ProjectListViewModel: ObservableObject {
    @Published var phoneNumber: String
    @Published var projects: [Project] = []
    @Published var pendingExpenses: [Expense] = []
    @Published var isLoading = false
    @Published var showingFullNotifications = false
    @StateObject private var userPhone = UserServices.shared
    @Published var role: UserRole
    @Published var selectedStatusFilter: ProjectStatus? = nil
    
    // Temporary Approver Status
    @Published var tempApproverStatus: TempApproverStatus? = nil
    @Published var showingTempApproverAction = false
    @Published var rejectionReason = ""
    @Published var showingRejectionSheet = false
    
    private let db = Firestore.firestore()
    private var projectListener: ListenerRegistration?
    
    init(phoneNumber: String = "", role: UserRole) {
        self.phoneNumber = phoneNumber
        self.role = role
        Task {
            await setupProjectListener()
        }
        setupNotificationObservers()
        print("Initialized with phone: \(self.phoneNumber), role: \(self.role)")
    }
    
    deinit {
        // Remove listener when view model is deallocated
        projectListener?.remove()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotificationObservers() {
        // Listen for project updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ProjectUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 Project updated notification received, refreshing project list...")
            self?.fetchProjects()
        }
    }
    
    func setupProjectListener() async {
        // Remove existing listener if any
        projectListener?.remove()
        
        isLoading = true
        
        // Clean phone number - remove +91 prefix if it exists
        let cleanPhone = phoneNumber.hasPrefix("+91") ? String(phoneNumber.dropFirst(3)) : phoneNumber
        print("🔍 Setting up listener for user: \(cleanPhone) with role: \(role)")
        
        // Start with the base collection reference
        let projectsRef = db.collection(FirebaseCollections.projects)
        
        // Create the appropriate query based on role and user
        let query: Query
        
        if phoneNumber == "admin@avr.com" {
            print("👑 Admin user - listening to all projects")
            query = projectsRef
        } else {
            switch role {
            case .USER:
                print("🔍 Querying as USER - Looking for teamMember: \(cleanPhone)")
                query = projectsRef
                    .whereField("teamMembers", arrayContains: cleanPhone)
                    .whereField("status", isEqualTo: ProjectStatus.ACTIVE.rawValue)
                
            case .APPROVER:
                print("🔍 Querying as APPROVER - Looking for managerId: \(cleanPhone)")
                
                query = projectsRef
                    .whereFilter(
                        Filter.orFilter([
                            Filter.whereField("managerId", isEqualTo: cleanPhone),
                            Filter.whereField("tempApproverID", isEqualTo: cleanPhone)
                        ])
                    )
                    .whereField("status", isEqualTo: ProjectStatus.ACTIVE.rawValue)
                
            default:
                print("🔍 Default role - fetching all projects")
                query = projectsRef
            }
        }
        
        // Set up real-time listener
        projectListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error listening to projects: \(error)")
                self.isLoading = false
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No documents found")
                self.isLoading = false
                return
            }
            
            print("📊 Found \(documents.count) projects")
            
            var loadedProjects: [Project] = []
            for document in documents {
                if var project = try? document.data(as: Project.self) {
                    project.id = document.documentID
                    loadedProjects.append(project)
                }
            }
            
            self.projects = loadedProjects.sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
            self.isLoading = false
            
            // Update TempApprover statuses for all projects
            Task {
                await self.updateTempApproverStatusesForAllProjects()
            }
            
            // Fetch pending expenses for notifications
            Task {
                await self.fetchPendingExpenses()
            }
        }
    }

    
    // Keep the existing fetchProjects method for manual refresh
    func fetchProjects() {
            Task {
                projects = []
                await setupProjectListener()
            }
        }
    
    
    // Function to update status filter
    func updateStatusFilter(_ status: ProjectStatus?) {
        selectedStatusFilter = status
    }
    
    // Computed property for filtered projects
    var filteredProjects: [Project] {
        guard phoneNumber == "admin@avr.com" else {
            return projects
        }
        if let filter = selectedStatusFilter {
            return projects.filter { $0.statusType == filter }
        }
        return projects
    }
    
    func fetchPendingExpenses() async {
        do {
            var allPendingExpenses: [Expense] = []
            
            for project in projects {
                guard let projectId = project.id else { continue }
                
                let expensesSnapshot = try await db
                    .collection(FirebaseCollections.projects)
                    .document(projectId)
                    .collection(FirebaseCollections.expenses)
                    .whereField("status", isEqualTo: ExpenseStatus.pending.rawValue)
                    .order(by: "createdAt", descending: true)
                    .getDocuments()
                
                for document in expensesSnapshot.documents {
                    if var expense = try? document.data(as: Expense.self) {
                        expense.id = document.documentID
                        allPendingExpenses.append(expense)
                    }
                }
            }
            
            // Sort by creation date and update the published property
            pendingExpenses = allPendingExpenses.sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
            
        } catch {
            print("❌ Error fetching pending expenses: \(error)")
        }
    }
    
    func updateExpenseStatus(projectId: String, expense: Expense, status: ExpenseStatus, remark: String?) async {
        guard let expenseId = expense.id else { return }
        
        do {
            let expenseRef = db
                .collection(FirebaseCollections.projects)
                .document(projectId)
                .collection(FirebaseCollections.expenses)
                .document(expenseId)
            
            // Clean phone number - remove +91 prefix if it exists
            let cleanPhone = phoneNumber.hasPrefix("+91") ? String(phoneNumber.dropFirst(3)) : phoneNumber
            
            var updateData: [String: Any] = [
                "status": status.rawValue,
                "approvedAt": Timestamp(),
                "approvedBy": cleanPhone
            ]
            
            if let remark = remark {
                updateData["remark"] = remark
            }
            
            try await expenseRef.updateData(updateData)
            
            // Refresh pending expenses
            await fetchPendingExpenses()
            
            // Show success feedback
            HapticManager.notification(.success)
            
        } catch {
            print("❌ Error updating expense status: \(error)")
            HapticManager.notification(.error)
        }
    }
    
    // MARK: - Temporary Approver Status Management
    
    func checkTempApproverStatusForProject(_ project: Project) async -> Bool {
        // Only check for APPROVER role users
        guard role == .APPROVER else { return false }
        
        let cleanPhone = phoneNumber.hasPrefix("+91") ? String(phoneNumber.dropFirst(3)) : phoneNumber
        
        // Check if user is temp approver for this specific project
        guard project.tempApproverID == cleanPhone else {
            tempApproverStatus = nil
            return false
        }
        
        guard let projectId = project.id else { return false }
        
        do {
            // Check tempApprover subcollection
            let tempApproverSnapshot = try await db
                .collection(FirebaseCollections.projects)
                .document(projectId)
                .collection("tempApprover")
                .whereField("approverId", isEqualTo: cleanPhone)
                .limit(to: 1)
                .getDocuments()
            
            if let tempApproverDoc = tempApproverSnapshot.documents.first,
               var tempApprover = try? tempApproverDoc.data(as: TempApprover.self) {
                
                // Check if status needs to be updated based on dates
                if tempApprover.needsStatusUpdate {
                    let newStatus = tempApprover.currentStatus
                    print("🔄 TempApprover status needs update from \(tempApprover.status.rawValue) to \(newStatus.rawValue)")
                    
                    // Update the status in Firebase
                    try await tempApproverDoc.reference.updateData([
                        "status": newStatus.rawValue,
                        "updatedAt": Date()
                    ])
                    
                    // Update local tempApprover object
                    tempApprover = TempApprover(
                        approverId: tempApprover.approverId,
                        startDate: tempApprover.startDate,
                        endDate: tempApprover.endDate,
                        status: newStatus,
                        approvedExpense: tempApprover.approvedExpense
                    )
                }
                
                tempApproverStatus = tempApprover.status
                
                // Return true if status is pending (needs user action)
                if tempApprover.status == .pending {
                    showingTempApproverAction = true
                    return true
                }
                return false
            } else {
                tempApproverStatus = nil
                return false
            }
        } catch {
            print("❌ Error checking temp approver status: \(error)")
            tempApproverStatus = nil
            return false
        }
    }
    
    func acceptTempApproverRole() async {
        guard let project = projects.first(where: { $0.tempApproverID == phoneNumber }) else { return }
        guard let projectId = project.id else { return }
        
        let cleanPhone = phoneNumber.hasPrefix("+91") ? String(phoneNumber.dropFirst(3)) : phoneNumber
        
        do {
            // Get current tempApprover data to determine the correct status
            let tempApproverSnapshot = try await db
                .collection(FirebaseCollections.projects)
                .document(projectId)
                .collection("tempApprover")
                .whereField("approverId", isEqualTo: cleanPhone)
                .limit(to: 1)
                .getDocuments()
            
            if let tempApproverDoc = tempApproverSnapshot.documents.first,
               let tempApprover = try? tempApproverDoc.data(as: TempApprover.self) {
                
                // Create updated tempApprover with accepted status
                let updatedTempApprover = TempApprover(
                    approverId: tempApprover.approverId,
                    startDate: tempApprover.startDate,
                    endDate: tempApprover.endDate,
                    status: .accepted,
                    approvedExpense: tempApprover.approvedExpense
                )
                
                // Determine the actual status based on dates
                let actualStatus = updatedTempApprover.currentStatus
                
                try await tempApproverDoc.reference.updateData([
                    "status": actualStatus.rawValue,
                    "updatedAt": Date()
                ])
                
                tempApproverStatus = actualStatus
                showingTempApproverAction = false
                
                print("✅ TempApprover role accepted with status: \(actualStatus.rawValue)")
                HapticManager.notification(.success)
            }
        } catch {
            print("❌ Error accepting temp approver role: \(error)")
            HapticManager.notification(.error)
        }
    }
    
    func rejectTempApproverRole() {
        showingRejectionSheet = true
    }
    
    // MARK: - TempApprover Status Update Methods
    
    func updateTempApproverStatusesForAllProjects() async {
        for project in projects {
            if let tempApproverID = project.tempApproverID {
                await updateTempApproverStatusForProject(projectId: project.id ?? "", tempApproverID: tempApproverID)
            }
        }
    }
    
    func updateTempApproverStatusForProject(projectId: String, tempApproverID: String) async {
        do {
            // Get the tempApprover document
            let tempApproverSnapshot = try await db
                .collection(FirebaseCollections.projects)
                .document(projectId)
                .collection("tempApprover")
                .whereField("approverId", isEqualTo: tempApproverID)
                .limit(to: 1)
                .getDocuments()
            
            guard let tempApproverDoc = tempApproverSnapshot.documents.first,
                  var tempApprover = try? tempApproverDoc.data(as: TempApprover.self) else {
                print("ℹ️ No tempApprover found for project: \(projectId)")
                return
            }
            
            // Check if status needs to be updated
            if tempApprover.needsStatusUpdate {
                let newStatus = tempApprover.currentStatus
                print("🔄 Updating tempApprover status from \(tempApprover.status.rawValue) to \(newStatus.rawValue) for project: \(projectId)")
                
                // Update the status in Firebase
                try await tempApproverDoc.reference.updateData([
                    "status": newStatus.rawValue,
                    "updatedAt": Date()
                ])
                
                print("✅ Successfully updated tempApprover status to \(newStatus.rawValue)")
            }
        } catch {
            print("❌ Error updating tempApprover status for project \(projectId): \(error)")
        }
    }
    
    func confirmRejection() async {
        guard let project = projects.first(where: { $0.tempApproverID == phoneNumber }) else { return }
        guard let projectId = project.id else { return }
        
        let cleanPhone = phoneNumber.hasPrefix("+91") ? String(phoneNumber.dropFirst(3)) : phoneNumber
        
        do {
            // Update tempApprover status to rejected with reason
            let tempApproverSnapshot = try await db
                .collection(FirebaseCollections.projects)
                .document(projectId)
                .collection("tempApprover")
                .whereField("approverId", isEqualTo: cleanPhone)
                .limit(to: 1)
                .getDocuments()
            
            if let tempApproverDoc = tempApproverSnapshot.documents.first {
                try await tempApproverDoc.reference.updateData([
                    "status": TempApproverStatus.rejected.rawValue,
                    "updatedAt": Date(),
                    "rejectionReason": rejectionReason
                ])
            }
            
            // Remove tempApproverID from project
            try await db
                .collection(FirebaseCollections.projects)
                .document(projectId)
                .updateData([
                    "tempApproverID": FieldValue.delete()
                ])
            
            tempApproverStatus = .rejected
            showingTempApproverAction = false
            showingRejectionSheet = false
            rejectionReason = ""
            
            // Refresh projects to remove the rejected project
            await fetchProjects()
            
            HapticManager.notification(.success)
        } catch {
            print("❌ Error rejecting temp approver role: \(error)")
            HapticManager.notification(.error)
        }
    }
    
    // Computed property for filtered projects based on temp approver status
    var filteredProjectsForTempApprover: [Project] {
        if role == .APPROVER && tempApproverStatus == .rejected {
            // Remove projects where user is temp approver if rejected
            return projects.filter { $0.tempApproverID != phoneNumber }
        }
        return filteredProjects
    }
}

