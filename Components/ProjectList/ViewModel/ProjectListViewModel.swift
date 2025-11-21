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
    @Published var customerId: String? // Customer ID for multi-tenant support
    
    // Temporary Approver Status
    @Published var tempApproverStatus: TempApproverStatus? = nil
    @Published var showingTempApproverAction = false
    @Published var rejectionReason = ""
    @Published var showingRejectionSheet = false
    
    private let db = Firestore.firestore()
    private var projectListener: ListenerRegistration?
    private let tempApproverService = TempApproverService()
    
    init(phoneNumber: String = "", role: UserRole, customerId: String? = nil) {
        self.phoneNumber = phoneNumber
        self.role = role
        self.customerId = customerId
        Task {
            await setupProjectListener()
        }
        setupNotificationObservers()
        print("Initialized with phone: \(self.phoneNumber), role: \(self.role), customerId: \(customerId ?? "nil")")
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
    
    func project(for id: String) -> Project? {
            return projects.first { $0.id == id }
        }
    
    func setupProjectListener() async {
        // Remove existing listener if any
        projectListener?.remove()
        
        isLoading = true
        
        // Get customer ID - required for customer-specific queries
        guard let customerId = customerId else {
            isLoading = false
            return
        }
        
        // Clean phone number - remove +91 prefix if it exists
        let cleanPhone = phoneNumber.hasPrefix("+91") ? String(phoneNumber.dropFirst(3)) : phoneNumber
        
        // Start with the customer-specific projects collection
        let projectsRef = FirebasePathHelper.shared.projectsCollection(customerId: customerId)
        
        // Create the appropriate query based on role and user
        let query: Query
        
        if phoneNumber == "admin@avr.com" || role == .ADMIN {
            query = projectsRef
        } else {
            switch role {
            case .USER:
                query = projectsRef
                    .whereField("teamMembers", arrayContains: cleanPhone)
//                    .whereField("status", isEqualTo: ProjectStatus.ACTIVE.rawValue)
                
            case .APPROVER:
                query = projectsRef
                    .whereFilter(
                        Filter.orFilter([
                            Filter.whereField("managerIds", arrayContains: cleanPhone),
                            Filter.whereField("tempApproverID", isEqualTo: cleanPhone)
                        ])
                    )
//                    .whereField("status", isEqualTo: ProjectStatus.ACTIVE.rawValue)
                
            default:
                query = projectsRef
            }
        }
        
        // Set up real-time listener
        projectListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.isLoading = false
                return
            }
            
            guard let documents = snapshot?.documents else {
                self.isLoading = false
                return
            }
            
            var loadedProjects: [Project] = []
            for document in documents {
                if var project = try? document.data(as: Project.self) {
                    project.id = document.documentID
                    loadedProjects.append(project)
                }
            }
            
            self.projects = loadedProjects.sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
            self.isLoading = false
            
            // Check and update project statuses based on active phases
            // Run this in background to avoid blocking UI updates
            Task.detached(priority: .background) {
                await self.checkAndUpdateProjectStatusesBasedOnPhases()
            }
            
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
    
    // MARK: - Project Status Update Based on Active Phases
    
    /// Checks and updates project statuses based on active phases:
    /// - If ACTIVE but no active phases -> set to STANDBY
    /// - If STANDBY and has active phases -> set to ACTIVE if handoverDate >= today, else set to MAINTENANCE
    func checkAndUpdateProjectStatusesBasedOnPhases() async {
        guard let customerId = customerId else {
            print("❌ Customer ID not found in checkAndUpdateProjectStatusesBasedOnPhases")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for project in projects {
            guard let projectId = project.id else { continue }
            
            // Skip if project is not ACTIVE or STANDBY
            guard project.statusType == .ACTIVE || project.statusType == .STANDBY else { continue }
            
            // Skip if project is suspended (isSuspended = true)
            if project.isSuspended == true { continue }
            
            do {
                // Check if project has active phases
                let phasesSnapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .getDocuments()
                
                var hasActivePhase = false
                var activePhaseEndDates: [Date] = []
                
                for phaseDoc in phasesSnapshot.documents {
                    if let phase = try? phaseDoc.data(as: Phase.self) {
                        // Check if phase is enabled
                        guard phase.isEnabledValue else { continue }
                        
                        // Parse phase dates
                        let startDate = phase.startDate.flatMap { dateFormatter.date(from: $0) }
                        let endDate = phase.endDate.flatMap { dateFormatter.date(from: $0) }
                        
                        // Check if phase is active (in progress)
                        let isActive: Bool
                        if let start = startDate, let end = endDate {
                            let phaseStart = calendar.startOfDay(for: start)
                            let phaseEnd = calendar.startOfDay(for: end)
                            isActive = phaseStart <= today && today <= phaseEnd
                        } else if let start = startDate {
                            let phaseStart = calendar.startOfDay(for: start)
                            isActive = phaseStart <= today
                        } else if let end = endDate {
                            let phaseEnd = calendar.startOfDay(for: end)
                            isActive = today <= phaseEnd
                        } else {
                            isActive = true // No dates means always active
                        }
                        
                        if isActive {
                            hasActivePhase = true
                            if let end = endDate {
                                activePhaseEndDates.append(end)
                            }
                        }
                    }
                }
                
                // Update status based on active phases
                var updateData: [String: Any] = [:]
                var needsUpdate = false
                
                if project.statusType == .ACTIVE && !hasActivePhase {
                    // ACTIVE but no active phases -> set to STANDBY
                    updateData["status"] = ProjectStatus.STANDBY.rawValue
                    needsUpdate = true
                    print("📊 Project \(projectId): ACTIVE but no active phases -> updating to STANDBY")
                } else if project.statusType == .STANDBY && hasActivePhase {
                    // STANDBY but has active phases -> check handover date
                    if let handoverDateStr = project.handoverDate,
                       let handoverDate = dateFormatter.date(from: handoverDateStr) {
                        let handover = calendar.startOfDay(for: handoverDate)
                        
                        if handover >= today {
                            // handoverDate >= today -> set to ACTIVE
                            updateData["status"] = ProjectStatus.ACTIVE.rawValue
                            needsUpdate = true
                            print("📊 Project \(projectId): STANDBY with active phases, handoverDate >= today -> updating to ACTIVE")
                        } else {
                            // handoverDate < today -> set to MAINTENANCE
                            updateData["status"] = ProjectStatus.MAINTENANCE.rawValue
                            needsUpdate = true
                            print("📊 Project \(projectId): STANDBY with active phases, handoverDate < today -> updating to MAINTENANCE")
                        }
                    } else {
                        // No handover date, but has active phases -> set to ACTIVE
                        updateData["status"] = ProjectStatus.ACTIVE.rawValue
                        needsUpdate = true
                        print("📊 Project \(projectId): STANDBY with active phases, no handover date -> updating to ACTIVE")
                    }
                }
                
                if needsUpdate {
                    updateData["updatedAt"] = Timestamp()
                    try await FirebasePathHelper.shared
                        .projectDocument(customerId: customerId, projectId: projectId)
                        .updateData(updateData)
                    
                    // Post notification to refresh project list
                    NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
                }
            } catch {
                print("❌ Error checking/updating project status for \(projectId): \(error)")
            }
        }
    }
    
    // MARK: - Project Status Update Based on Planned Date
    
    /// Checks all suspended projects and automatically unsuspends them if suspendedDate is yesterday or earlier
    func checkAndUnsuspendExpiredProjects() async {
        guard let customerId = customerId else {
            print("❌ Customer ID not found in checkAndUnsuspendExpiredProjects")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        
        for project in projects {
            // Only check projects that are currently suspended
            guard let projectId = project.id,
                  project.isSuspended == true,
                  let suspendedDateStr = project.suspendedDate else {
                continue
            }
            
            // Parse the suspended date
            guard let suspendedDate = dateFormatter.date(from: suspendedDateStr) else {
                print("⚠️ Could not parse suspendedDate: \(suspendedDateStr) for project: \(projectId)")
                continue
            }
            
            let suspended = calendar.startOfDay(for: suspendedDate)
            
            // Check if suspended date is yesterday or earlier
            if suspended <= yesterday {
                do {
                    // Get the project's planned date to determine the new status
                    let projectDoc = try await FirebasePathHelper.shared
                        .projectDocument(customerId: customerId, projectId: projectId)
                        .getDocument()
                    
                    guard let projectData = projectDoc.data(),
                          let plannedDateStr = projectData["plannedDate"] as? String else {
                        // If no planned date, default to LOCKED
                        try await FirebasePathHelper.shared
                            .projectDocument(customerId: customerId, projectId: projectId)
                            .updateData([
                                "isSuspended": false,
                                "suspendedDate": NSNull(),
                                "suspensionReason": NSNull(),
                                "status": ProjectStatus.LOCKED.rawValue,
                                "updatedAt": Timestamp()
                            ])
                        
                        NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
                        continue
                    }
                    
                    // Determine new status based on planned date (same logic as updateProjectSuspension)
                    let plannedDate = dateFormatter.date(from: plannedDateStr) ?? Date()
                    let planned = calendar.startOfDay(for: plannedDate)
                    
                    let newStatus: String
                    if planned <= today {
                        // If planned date is today or in the past, set to ACTIVE
                        newStatus = ProjectStatus.ACTIVE.rawValue
                    } else {
                        // If planned date is in the future, set to LOCKED
                        newStatus = ProjectStatus.LOCKED.rawValue
                    }
                    
                    // Update project to unsuspend it
                    try await FirebasePathHelper.shared
                        .projectDocument(customerId: customerId, projectId: projectId)
                        .updateData([
                            "isSuspended": false,
                            "suspendedDate": NSNull(),
                            "suspensionReason": NSNull(),
                            "status": newStatus,
                            "updatedAt": Timestamp()
                        ])
                    
                    print("✅ Automatically unsuspended project: \(projectId) - suspension date (\(suspendedDateStr)) has passed")
                    
                    // Post notification to refresh project list
                    NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
                } catch {
                    print("❌ Error unsuspending project \(projectId): \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Checks all projects and updates status from LOCKED to ACTIVE/SUSPENDED based on planned date and phase timelines
    // MARK: - Removed Automatic Status Validation
    // This function has been removed as per user request.
    // Project status updates are now manual only and should be done through the Admin interface.
    // 
    // Previously, this function automatically updated project statuses based on dates:
    // - LOCKED -> ACTIVE/SUSPENDED when planned date arrived
    // - SUSPENDED -> ACTIVE when phases become active
    // - ACTIVE -> SUSPENDED when no active phases
    // - ACTIVE -> MAINTENANCE when handover date passed
    // - MAINTENANCE -> COMPLETED when maintenance date passed
    // - COMPLETED -> ARCHIVE 40 days after maintenance date
    //
    // func checkAndUpdateProjectStatuses() async { ... }

    
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
        guard phoneNumber == "admin@avr.com" || role == .ADMIN else {
            return projects
        }
        
        // Filter by status if a filter is selected
        let filtered: [Project]
        if let filter = selectedStatusFilter {
            filtered = projects.filter { $0.statusType == filter }
        } else {
            filtered = projects
        }
        
        // Sort projects by status order when showing all projects (no filter)
        // Order: IN_REVIEW, ACTIVE, MAINTENANCE, COMPLETED, DECLINED, ARCHIVE
        if selectedStatusFilter == nil {
            let statusOrder: [ProjectStatus] = [.IN_REVIEW, .ACTIVE, .MAINTENANCE, .COMPLETED, .DECLINED, .ARCHIVE]
            
            return filtered.sorted { project1, project2 in
                let status1 = project1.statusType
                let status2 = project2.statusType
                
                // Get index of status in the order array, or use a high number if not found
                let index1 = statusOrder.firstIndex(of: status1) ?? Int.max
                let index2 = statusOrder.firstIndex(of: status2) ?? Int.max
                
                // If same status, sort by creation date (newest first)
                if index1 == index2 {
                    return project1.createdAt.dateValue() > project2.createdAt.dateValue()
                }
                
                return index1 < index2
            }
        }
        
        // When filtered, sort by creation date (newest first)
        return filtered.sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
    }
    
    func fetchPendingExpenses() async {
        do {
            var allPendingExpenses: [Expense] = []
            
            guard let customerId = customerId else { return }
            
            // Clean phone number - remove +91 prefix if it exists
            let cleanPhone = phoneNumber.hasPrefix("+91") ? String(phoneNumber.dropFirst(3)) : phoneNumber
            
            // Filter projects based on role
            let projectsToCheck: [Project]
            
            switch role {
            case .ADMIN:
                // ADMIN sees all pending expenses from all projects
                projectsToCheck = projects
                
            case .APPROVER:
                // APPROVER only sees expenses from projects where they are a manager or temp approver
                projectsToCheck = projects.filter { project in
                    let isManager = project.managerIds.contains(cleanPhone)
                    let isTempApprover = project.tempApproverID == cleanPhone
                    return isManager || isTempApprover
                }
                
            case .USER:
                // USER doesn't see pending expense notifications (they can't approve)
                projectsToCheck = []
            case .HEAD:
                return
            }
            
            // Fetch pending expenses only from relevant projects
            for project in projectsToCheck {
                guard let projectId = project.id else { continue }
                
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
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
        guard let expenseId = expense.id,
              let customerId = customerId else {
            print("❌ Missing expense ID or customer ID")
            return
        }
        
        do {
            // Use the correct customer-specific path
            let expenseRef = FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: projectId)
                .document(expenseId)
            
            // Clean phone number - remove +91 prefix if it exists
            let cleanPhone = phoneNumber.hasPrefix("+91") ? String(phoneNumber.dropFirst(3)) : phoneNumber
            
            var updateData: [String: Any] = [
                "status": status.rawValue,
                "updatedAt": Timestamp()
            ]
            
            // Set appropriate fields based on status
            if status == .approved {
                updateData["approvedAt"] = Timestamp()
                updateData["approvedBy"] = cleanPhone
            } else if status == .rejected {
                updateData["rejectedAt"] = Timestamp()
                updateData["rejectedBy"] = cleanPhone
            }
            
            // Add remark if provided
            if let remark = remark, !remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updateData["remark"] = remark.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            try await expenseRef.updateData(updateData)
            
            // Post notification for other listeners
            NotificationCenter.default.post(
                name: NSNotification.Name("ExpenseStatusUpdated"),
                object: nil,
                userInfo: [
                    "expenseId": expenseId,
                    "phaseId": expense.phaseId as Any,
                    "department": expense.department,
                    "oldStatus": expense.status.rawValue,
                    "newStatus": status.rawValue,
                    "amount": expense.amount
                ]
            )
            
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
                .whereField("status", in: ["pending", "active"])
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
                
                // Return true if status is pending (needs user action) and not expired
                if tempApprover.status == .pending && !tempApprover.hasExpired {
                    return true
                }
                
                // If expired, automatically remove tempApproverID from project
                if tempApprover.hasExpired {
                    try await db
                        .collection(FirebaseCollections.projects)
                        .document(projectId)
                        .updateData([
                            "tempApproverID": FieldValue.delete()
                        ])
                    print("🗑️ Removed expired tempApproverID from project: \(projectId)")
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
        
        // Get current tempApprover to determine the correct status
        if let tempApprover = await tempApproverService.getTempApproverForProject(
            projectId: projectId,
            approverId: cleanPhone
        ) {
            
            // Determine the actual status based on dates
            let updatedTempApprover = TempApprover(
                approverId: tempApprover.approverId,
                startDate: tempApprover.startDate,
                endDate: tempApprover.endDate,
                status: .accepted,
                approvedExpense: tempApprover.approvedExpense
            )
            
            let actualStatus = updatedTempApprover.currentStatus
            
            let success = await tempApproverService.updateTempApproverStatus(
                projectId: projectId,
                approverId: cleanPhone,
                status: actualStatus
            )
            
            if success {
                tempApproverStatus = actualStatus
                print("✅ TempApprover role accepted with status: \(actualStatus.rawValue)")
                HapticManager.notification(.success)
            } else {
                HapticManager.notification(.error)
            }
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
                .whereField("status", isEqualTo: "active")
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
                
            }
        } catch {
            // Error updating tempApprover status
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
    
    func confirmRejectionWithReason(_ reason: String) async {
        guard let project = projects.first(where: { $0.tempApproverID == phoneNumber }) else { return }
        guard let projectId = project.id else { return }
        
        let cleanPhone = phoneNumber.hasPrefix("+91") ? String(phoneNumber.dropFirst(3)) : phoneNumber
        
        let success = await tempApproverService.updateTempApproverStatus(
            projectId: projectId,
            approverId: cleanPhone,
            status: .rejected,
            rejectionReason: reason
        )
        
        if success {
            tempApproverStatus = .rejected
            showingRejectionSheet = false
            rejectionReason = ""
            
            // Refresh projects to remove the rejected project
            await fetchProjects()
            
            HapticManager.notification(.success)
        } else {
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
    
    // MARK: - Temp Approver Data Retrieval
    
    func getTempApproverForProject(_ project: Project) async -> TempApprover? {
        guard let projectId = project.id else { return nil }
        
        let cleanPhone = phoneNumber.hasPrefix("+91") ? String(phoneNumber.dropFirst(3)) : phoneNumber
        
        return await tempApproverService.getTempApproverForProject(
            projectId: projectId,
            approverId: cleanPhone
        )
    }
}

