import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
class AdminProjectDetailViewModel: ObservableObject {
    // Project Data
    @Published var projectName: String
    @Published var projectDescription: String
    @Published var projectStatus: String
    @Published var client: String
    @Published var location: String
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var plannedDate: Date
    @Published var handoverDate: Date
    @Published var initialHandOverDate: Date
    @Published var maintenanceDate: Date
    @Published var isSuspended: Bool
    @Published var suspendedDate: Date?
    @Published var suspensionReason: String
    @Published var teamMembers: [String]
    @Published var managerName: String? = nil // Single manager only
    @Published var tempApproverID: String?
    
    // Temporary Approver Properties
    @Published var tempApprover: TempApprover?
    @Published var tempApproverName: String?
    @Published var showingTempApproverSheet = false
    
    // Edit States
    @Published var isEditingName = false
    @Published var isEditingDescription = false
    @Published var isEditingClient = false
    @Published var isEditingLocation = false
    @Published var isEditingDates = false
    @Published var isEditingPlannedDate = false
    @Published var isEditingHandoverDate = false
    @Published var isEditingMaintenanceDate = false
    @Published var isEditingSuspension = false
    @Published var isEditingTeam = false
    
    // Phase end date for handover date validation
    @Published var highestPhaseEndDate: Date? = nil
    
    // Team Selection
    @Published var approverSearchText = ""
    @Published var teamMemberSearchText = ""
    @Published var selectedTeamMembers: Set<User> = []
    @Published var selectedManager: User? = nil // Single manager only
    @Published var allApprovers: [User] = []
    @Published private var allUsers: [User] = []
    @Published var loadedTeamMembers: [User] = [] // Actual User objects for team members
    
    // UI State
    @Published var showError = false
    @Published var showSuccess = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var expensesCount: Int = 0
    @Published var showDeleteConfirmation = false
    @Published var isDeleting = false
    @Published var showStatusChangeConfirmation = false
    @Published var pendingStatusChange: ProjectStatus?
    @Published var statusChangeMessage: String = ""
    
    let project: Project
    private let db = Firestore.firestore()
    
    // Customer ID for multi-tenant support
    var customerId: String? {
        Auth.auth().currentUser?.uid
    }
    
    init(project: Project) {
        self.project = project
        self.projectName = project.name
        self.projectDescription = project.description
        self.projectStatus = project.status
        self.client = project.client
        self.location = project.location
        
        // Convert string dates to Date objects
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        if let startDateStr = project.startDate,
           let startDate = dateFormatter.date(from: startDateStr) {
            self.startDate = startDate
        } else {
            self.startDate = Date()
        }
        
        if let endDateStr = project.endDate,
           let endDate = dateFormatter.date(from: endDateStr) {
            self.endDate = endDate
        } else {
            self.endDate = Date().addingTimeInterval(86400 * 30)
        }
        
        if let plannedDateStr = project.plannedDate,
           let plannedDate = dateFormatter.date(from: plannedDateStr) {
            self.plannedDate = plannedDate
        } else {
            self.plannedDate = Date()
        }
        
        // Initialize handover date
        let handoverDateValue: Date
        if let handoverDateStr = project.handoverDate,
           let handoverDate = dateFormatter.date(from: handoverDateStr) {
            handoverDateValue = handoverDate
        } else {
            handoverDateValue = Date().addingTimeInterval(86400 * 30)
        }
        self.handoverDate = handoverDateValue
        
        // Initialize initial handover date
        let initialHandOverDateValue: Date
        if let initialHandOverDateStr = project.initialHandOverDate,
           let initialHandOverDate = dateFormatter.date(from: initialHandOverDateStr) {
            initialHandOverDateValue = initialHandOverDate
        } else {
            // If not set, use handoverDate as fallback
            initialHandOverDateValue = handoverDateValue
        }
        self.initialHandOverDate = initialHandOverDateValue
        
        // Maintenance date defaults to 1 month from handover date
        if let maintenanceDateStr = project.maintenanceDate,
           let maintenanceDate = dateFormatter.date(from: maintenanceDateStr) {
            self.maintenanceDate = maintenanceDate
        } else {
            // Default to 1 month from handover date
            let defaultMaintenanceDate = Calendar.current.date(byAdding: .month, value: 1, to: handoverDateValue) ?? Date().addingTimeInterval(86400 * 60)
            self.maintenanceDate = defaultMaintenanceDate
        }
        
        // Initialize suspension properties
        self.isSuspended = project.isSuspended ?? false
        if let suspendedDateStr = project.suspendedDate,
           let suspendedDate = dateFormatter.date(from: suspendedDateStr) {
            self.suspendedDate = suspendedDate
        } else {
            self.suspendedDate = nil
        }
        self.suspensionReason = project.suspensionReason ?? ""
        
        self.teamMembers = project.teamMembers
        self.tempApproverID = project.tempApproverID
        
        Task {
            await fetchUsers()
            await fetchTeamMembers()
            await fetchTempApprover()
            await checkExpensesCount()
            await fetchHighestPhaseEndDate()
        }
    }
    
    var dateRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    var filteredApprovers: [User] {
        if approverSearchText.isEmpty { return [] }
        return allApprovers.filter { approver in
            let isNotSelected = selectedManager?.phoneNumber != approver.phoneNumber
            let isActive = approver.isActive
            let matchesSearch = approver.name.localizedCaseInsensitiveContains(approverSearchText) ||
                              approver.phoneNumber.localizedCaseInsensitiveContains(approverSearchText)
            return isNotSelected && isActive && matchesSearch
        }
    }
    
    var filteredTeamMembers: [User] {
        if teamMemberSearchText.isEmpty { return [] }
        return allUsers.filter { user in
            let isNotSelected = !selectedTeamMembers.contains(user)
            let isActive = user.isActive
            let matchesSearch = user.name.localizedCaseInsensitiveContains(teamMemberSearchText) ||
                              user.phoneNumber.localizedCaseInsensitiveContains(teamMemberSearchText)
            return isNotSelected && isActive && matchesSearch
        }
    }
    
    func fetchUsers() async {
        guard let customerId = customerId else {
            errorMessage = "Customer ID not found. Please log in again."
            showError = true
            return
        }
        
        do {
            // Filter users by ownerID to match the current customer/admin's UID
            // This ensures each customer only sees their own users/approvers
            let querySnapshot = try await db.collection("users")
                .whereField("role", in: [UserRole.USER.rawValue, UserRole.APPROVER.rawValue])
                .whereField("isActive", isEqualTo: true)
                .whereField("ownerID", isEqualTo: customerId)
                .getDocuments()
            
            var loadedUsers: [User] = []
            var loadedApprovers: [User] = []
            
            for document in querySnapshot.documents {
                if let user = try? document.data(as: User.self) {
                    if user.role == .USER {
                        loadedUsers.append(user)
                        if teamMembers.contains(user.phoneNumber) {
                            selectedTeamMembers.insert(user)
                        }
                    } else if user.role == .APPROVER {
                        loadedApprovers.append(user)
                        // Single manager only - take the first one found from managerIds array
                        // Check both phoneNumber and email to match the stored managerId
                        if selectedManager == nil {
                            let matchesPhone = project.managerIds.contains(user.phoneNumber)
                            let matchesEmail = user.email != nil && project.managerIds.contains(user.email!)
                            if matchesPhone || matchesEmail {
                                selectedManager = user
                            }
                        }
                    }
                }
            }
            
            allUsers = loadedUsers.sorted { $0.name < $1.name }
            allApprovers = loadedApprovers.sorted { $0.name < $1.name }
            
            // Update manager name
            managerName = selectedManager?.name
            
        } catch {
            errorMessage = "Failed to load users: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func fetchTeamMembers() async {
        var loadedMembers: [User] = []
        
        // Load team members in parallel
        await withTaskGroup(of: User?.self) { group in
            for memberId in teamMembers {
                group.addTask {
                    do {
                        let document = try await self.db
                            .collection("users")
                            .document(memberId)
                            .getDocument()
                        
                        if document.exists {
                            return try document.data(as: User.self)
                        }
                        return nil
                    } catch {
                        print("Error fetching team member \(memberId): \(error)")
                        return nil
                    }
                }
            }
            
            for await member in group {
                if let member = member {
                    loadedMembers.append(member)
                }
            }
        }
        
        // Sort by name
        loadedMembers.sort { $0.name < $1.name }
        
        await MainActor.run {
            self.loadedTeamMembers = loadedMembers
        }
    }
    
    func fetchTempApprover() async {
        guard let tempApproverID = project.tempApproverID,
              let customerId = customerId else {
            self.tempApprover = nil
            return
        }
        
        do {
            // Fetch the user from customer-specific users collection using tempApproverID as document ID
            let userDocument = try await FirebasePathHelper.shared
                .usersCollection(customerId: customerId)
                .document(tempApproverID)
                .getDocument()
            
            if userDocument.exists, let user = try? userDocument.data(as: User.self) {
                // Create a TempApprover object with the user's information
                let tempApprover = TempApprover(
                    approverId: user.phoneNumber,
                    startDate: Date(), // Default dates since we don't have them in the project
                    endDate: Date().addingTimeInterval(86400 * 30), // Default 30 days
                    status: .pending
                )
                self.tempApprover = tempApprover
                self.tempApproverName = user.name
                print("✅ Fetched temp approver: \(user.name) (\(user.phoneNumber))")
            } else {
                // User not found, set to nil
                self.tempApprover = nil
                self.tempApproverName = nil
                print("ℹ️ Temp approver user not found with ID: \(tempApproverID)")
            }
        } catch {
            print("❌ Error fetching temp approver user: \(error)")
            self.tempApprover = nil
            self.tempApproverName = nil
        }
    }
    
    // MARK: - Update Methods
    
    func updateProjectName(_ newName: String) {
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            do {
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData(["name": newName])
                
                projectName = newName
                isEditingName = false
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update project name: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func updateProjectDescription(_ newDescription: String) {
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            do {
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData(["description": newDescription])
                
                projectDescription = newDescription
                isEditingDescription = false
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update project description: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func updateProjectClient(_ newClient: String) {
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            do {
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData(["client": newClient])
                
                client = newClient
                isEditingClient = false
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update project client: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func updateProjectLocation(_ newLocation: String) {
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            do {
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData(["location": newLocation])
                
                location = newLocation
                isEditingLocation = false
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update project location: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func updateProjectStatus(_ newStatus: ProjectStatus) {
        // Check if dates will change and prepare confirmation message
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentStatus = ProjectStatus(rawValue: projectStatus) ?? .LOCKED
        
        var dateChanges: [String] = []
        
        // Check which dates will change based on new status
        switch newStatus {
        case .ACTIVE:
            // Only check for planned date change if changing from LOCKED to ACTIVE
            if currentStatus == .LOCKED {
                let planned = calendar.startOfDay(for: plannedDate)
                if planned > today {
                    dateChanges.append("Planned Date")
                }
            }
            
        case .MAINTENANCE:
            // If changing from COMPLETED to MAINTENANCE, maintenance date will be set to 1 month from now
            if currentStatus == .COMPLETED {
                dateChanges.append("Maintenance Date")
            } else {
                let handover = calendar.startOfDay(for: handoverDate)
                if handover > today {
                    dateChanges.append("Handover Date")
                }
            }
            
        case .COMPLETED:
            let handover = calendar.startOfDay(for: handoverDate)
            if handover > today {
                dateChanges.append("Handover Date")
            }
            let maintenance = calendar.startOfDay(for: maintenanceDate)
            if maintenance > today {
                dateChanges.append("Maintenance Date")
            }
            
        default:
            break
        }
        
        // If dates will change, show confirmation alert
        if !dateChanges.isEmpty {
            let dateList = dateChanges.joined(separator: " and ")
            
            // Customize message based on the status change
            if newStatus == .MAINTENANCE && currentStatus == .COMPLETED {
                statusChangeMessage = "Changing status to \(newStatus.rawValue) will automatically update the \(dateList) to 1 month from now. Do you want to continue?"
            } else {
                statusChangeMessage = "Changing status to \(newStatus.rawValue) will automatically update the \(dateList) to yesterday's date (to reflect immediately in UI). Do you want to continue?"
            }
            
            pendingStatusChange = newStatus
            showStatusChangeConfirmation = true
        } else {
            // No date changes, proceed directly
            performStatusUpdate(newStatus)
        }
    }
    
    func confirmStatusChange() {
        guard let newStatus = pendingStatusChange else { return }
        performStatusUpdate(newStatus)
        pendingStatusChange = nil
        showStatusChangeConfirmation = false
    }
    
    func cancelStatusChange() {
        pendingStatusChange = nil
        showStatusChangeConfirmation = false
        statusChangeMessage = ""
    }
    
    private func performStatusUpdate(_ newStatus: ProjectStatus) {
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                
                var updateData: [String: Any] = [
                    "status": newStatus.rawValue,
                    "updatedAt": Timestamp()
                ]
                
                var updatedPlannedDate = plannedDate
                var updatedHandoverDate = handoverDate
                var updatedMaintenanceDate = maintenanceDate
                
                // Get current status before update
                let currentStatus = ProjectStatus(rawValue: projectStatus) ?? .LOCKED
                
                // Adjust dates based on new status
                switch newStatus {
                case .ACTIVE:
                    // If changing from LOCKED to ACTIVE and plannedDate > current date, set plannedDate = yesterday (to reflect immediately)
                    if currentStatus == .LOCKED {
                        let planned = calendar.startOfDay(for: plannedDate)
                        if planned > today {
                            updatedPlannedDate = yesterday
                            updateData["plannedDate"] = dateFormatter.string(from: yesterday)
                        }
                    }
                    
                case .MAINTENANCE:
                    // If changing from COMPLETED to MAINTENANCE, set maintenance date to 1 month from now
                    if currentStatus == .COMPLETED {
                        let oneMonthFromNow = calendar.date(byAdding: .month, value: 1, to: today) ?? today
                        updatedMaintenanceDate = oneMonthFromNow
                        updateData["maintenanceDate"] = dateFormatter.string(from: oneMonthFromNow)
                    } else {
                        // If handoverDate > current date, set handoverDate = yesterday (to reflect immediately)
                        let handover = calendar.startOfDay(for: handoverDate)
                        if handover > today {
                            updatedHandoverDate = yesterday
                            updateData["handoverDate"] = dateFormatter.string(from: yesterday)
                        }
                    }
                    
                case .COMPLETED:
                    // If handoverDate > current date, set handoverDate = yesterday (to reflect immediately)
                    let handover = calendar.startOfDay(for: handoverDate)
                    if handover > today {
                        updatedHandoverDate = yesterday
                        updateData["handoverDate"] = dateFormatter.string(from: yesterday)
                    }
                    
                    // If maintenanceDate > current date, set maintenanceDate = yesterday (to reflect immediately)
                    let maintenance = calendar.startOfDay(for: maintenanceDate)
                    if maintenance > today {
                        updatedMaintenanceDate = yesterday
                        updateData["maintenanceDate"] = dateFormatter.string(from: yesterday)
                    }
                    
                    // Update all phase end dates that are in future to yesterday
                    // Update phase start dates that are in future to 2 days back
                    // This applies to ALL status changes to COMPLETED (not just from ACTIVE)
                    await updatePhasesForCompletedStatus(projectId: projectId, customerId: customerId, yesterday: yesterday, twoDaysBack: calendar.date(byAdding: .day, value: -2, to: today) ?? yesterday)
                    
                default:
                    break
                }
                
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData(updateData)
                
                // Update local state
                projectStatus = newStatus.rawValue
                if updatedPlannedDate != plannedDate {
                    plannedDate = updatedPlannedDate
                }
                if updatedHandoverDate != handoverDate {
                    handoverDate = updatedHandoverDate
                }
                if updatedMaintenanceDate != maintenanceDate {
                    maintenanceDate = updatedMaintenanceDate
                }
                
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update project status: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Update Phases for Completed Status
    private func updatePhasesForCompletedStatus(projectId: String, customerId: String, yesterday: Date, twoDaysBack: Date) async {
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            
            // Get all phases for this project
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .getDocuments()
            
            // Update each phase
            for doc in phasesSnapshot.documents {
                guard let phase = try? doc.data(as: Phase.self) else { continue }
                
                var phaseUpdateData: [String: Any] = [:]
                var needsUpdate = false
                
                // Check and update end date if in future
                if let endDateStr = phase.endDate,
                   let endDate = dateFormatter.date(from: endDateStr) {
                    let phaseEnd = calendar.startOfDay(for: endDate)
                    if phaseEnd > today {
                        phaseUpdateData["endDate"] = dateFormatter.string(from: yesterday)
                        needsUpdate = true
                    }
                }
                
                // Check and update start date if in future
                if let startDateStr = phase.startDate,
                   let startDate = dateFormatter.date(from: startDateStr) {
                    let phaseStart = calendar.startOfDay(for: startDate)
                    if phaseStart > today {
                        phaseUpdateData["startDate"] = dateFormatter.string(from: twoDaysBack)
                        needsUpdate = true
                    }
                }
                
                // Update phase if needed
                if needsUpdate {
                    phaseUpdateData["updatedAt"] = Timestamp()
                    try await FirebasePathHelper.shared
                        .phasesCollection(customerId: customerId, projectId: projectId)
                        .document(doc.documentID)
                        .updateData(phaseUpdateData)
                    
                    print("✅ Updated phase \(doc.documentID): endDate and/or startDate adjusted for COMPLETED status")
                }
            }
        } catch {
            print("⚠️ Error updating phases for completed status: \(error.localizedDescription)")
        }
    }
    
    func updateProjectDates() {
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                
                let data: [String: Any] = [
                    "startDate": dateFormatter.string(from: startDate),
                    "endDate": dateFormatter.string(from: endDate)
                ]
                
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData(data)
                
                isEditingDates = false
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update project dates: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func updateProjectPlannedDate(_ newPlannedDate: Date) {
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                
                let plannedDateStr = dateFormatter.string(from: newPlannedDate)
                
                // Determine the new status based on planned date
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let planned = calendar.startOfDay(for: newPlannedDate)
                
                let newStatus: String
                if planned <= today {
                    // If planned date is today or in the past, set to ACTIVE
                    newStatus = ProjectStatus.ACTIVE.rawValue
                } else {
                    // If planned date is in the future, set to LOCKED
                    newStatus = ProjectStatus.LOCKED.rawValue
                }
                
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData([
                        "plannedDate": plannedDateStr,
//                        "status": newStatus
                    ])
                
                plannedDate = newPlannedDate
//                projectStatus = newStatus
                isEditingPlannedDate = false
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update planned date: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func updateProjectHandoverDate(_ newHandoverDate: Date) {
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                
                let handoverDateStr = dateFormatter.string(from: newHandoverDate)
                
                var updateData: [String: Any] = [
                    "handoverDate": handoverDateStr,
                    "updatedAt": Timestamp()
                ]
                
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let handover = calendar.startOfDay(for: newHandoverDate)
                let maintenance = calendar.startOfDay(for: maintenanceDate)
                
                // Check project status - if LOCKED or IN_REVIEW, update both fields
                let currentStatus = ProjectStatus(rawValue: projectStatus) ?? .LOCKED
                if currentStatus == .LOCKED || currentStatus == .IN_REVIEW {
                    updateData["initialHandOverDate"] = handoverDateStr
                }
                
                // Logic for status changes (only if status is not IN_REVIEW or LOCKED)
                if currentStatus != .IN_REVIEW && currentStatus != .LOCKED {
                    // If changed date >= today's date, change project status to ACTIVE
                    if handover >= today {
                        updateData["status"] = ProjectStatus.ACTIVE.rawValue
                        projectStatus = ProjectStatus.ACTIVE.rawValue
                    }
                    
                    // If changed date > maintenance date, change maintenance date to changed date + 1 month
                    if handover > maintenance {
                        let newMaintenanceDate = calendar.date(byAdding: .month, value: 1, to: newHandoverDate) ?? newHandoverDate
                        let newMaintenanceDateStr = dateFormatter.string(from: newMaintenanceDate)
                        updateData["maintenanceDate"] = newMaintenanceDateStr
                        maintenanceDate = newMaintenanceDate
                    }
                } else {
                    // If status is IN_REVIEW or LOCKED, only update maintenance date if handover > maintenance
                    if handover > maintenance {
                        let newMaintenanceDate = calendar.date(byAdding: .month, value: 1, to: newHandoverDate) ?? newHandoverDate
                        let newMaintenanceDateStr = dateFormatter.string(from: newMaintenanceDate)
                        updateData["maintenanceDate"] = newMaintenanceDateStr
                        maintenanceDate = newMaintenanceDate
                    }
                }
                
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData(updateData)
                
                handoverDate = newHandoverDate
                
                // Update initialHandOverDate if status is LOCKED or IN_REVIEW
                if currentStatus == .LOCKED || currentStatus == .IN_REVIEW {
                    initialHandOverDate = newHandoverDate
                }
                
                isEditingHandoverDate = false
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update handover date: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func updateProjectMaintenanceDate(_ newMaintenanceDate: Date) {
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                
                let maintenanceDateStr = dateFormatter.string(from: newMaintenanceDate)
                
                var updateData: [String: Any] = [
                    "maintenanceDate": maintenanceDateStr,
                    "updatedAt": Timestamp()
                ]
                
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let maintenance = calendar.startOfDay(for: newMaintenanceDate)
                let handover = calendar.startOfDay(for: handoverDate)
                
                // Check project status - only apply status changes if not IN_REVIEW or LOCKED
                let currentStatus = ProjectStatus(rawValue: projectStatus) ?? .LOCKED
                
                // Logic for status changes (only if status is not IN_REVIEW or LOCKED)
                if currentStatus != .IN_REVIEW && currentStatus != .LOCKED {
                    // If maintenance date >= today's date
                    if maintenance >= today {
                        // If handover date < today's date: change status to MAINTENANCE
                        // Else: change status to ACTIVE
                        if handover < today {
                            updateData["status"] = ProjectStatus.MAINTENANCE.rawValue
                            projectStatus = ProjectStatus.MAINTENANCE.rawValue
                        } else {
                            updateData["status"] = ProjectStatus.ACTIVE.rawValue
                            projectStatus = ProjectStatus.ACTIVE.rawValue
                        }
                    }
                }
                
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData(updateData)
                
                maintenanceDate = newMaintenanceDate
                isEditingMaintenanceDate = false
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update maintenance date: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func setMaintenancePeriod(_ months: Int) {
        let calendar = Calendar.current
        let newMaintenanceDate = calendar.date(byAdding: .month, value: months, to: handoverDate) ?? handoverDate
        updateProjectMaintenanceDate(newMaintenanceDate)
    }
    
    func updateProjectSuspension(isSuspended: Bool, suspendedDate: Date?, suspensionReason: String) {
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            // Validate: if suspending, reason is mandatory
            if isSuspended {
                let trimmedReason = suspensionReason.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedReason.isEmpty {
                    errorMessage = "Suspension reason is required."
                    showError = true
                    return
                }
            }
            
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                
                var updateData: [String: Any] = [
                    "isSuspended": isSuspended,
                    "updatedAt": Timestamp()
                ]
                
                if isSuspended {
                    // Suspending the project
                    // Always update status to SUSPENDED when suspending
                    updateData["status"] = ProjectStatus.SUSPENDED.rawValue
                    self.projectStatus = ProjectStatus.SUSPENDED.rawValue
                    
                    // Update suspended date if provided
                    if let suspendedDate = suspendedDate {
                        let suspendedDateStr = dateFormatter.string(from: suspendedDate)
                        updateData["suspendedDate"] = suspendedDateStr
                    }
                    
                    // Update suspension reason (mandatory when suspending)
                    let reasonToStore = suspensionReason.trimmingCharacters(in: .whitespacesAndNewlines)
                    updateData["suspensionReason"] = reasonToStore
                } else {
                    // Unsuspending the project - determine status using existing logic
                    updateData["suspendedDate"] = NSNull()
                    updateData["suspensionReason"] = NSNull()
                    
                    // Determine status based on planned date (same logic as updateProjectPlannedDate)
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    let planned = calendar.startOfDay(for: plannedDate)
                    
                    let newStatus: String
                    if planned <= today {
                        // If planned date is today or in the past, set to ACTIVE
                        newStatus = ProjectStatus.ACTIVE.rawValue
                    } else {
                        // If planned date is in the future, set to LOCKED
                        newStatus = ProjectStatus.LOCKED.rawValue
                    }
                    
                    updateData["status"] = newStatus
                    self.projectStatus = newStatus
                }
                
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData(updateData)
                
                self.isSuspended = isSuspended
                self.suspendedDate = suspendedDate
                self.suspensionReason = suspensionReason.trimmingCharacters(in: .whitespacesAndNewlines)
                self.isEditingSuspension = false
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update project suspension: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func updateProjectManager(_ manager: User) {
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            do {
                // Single manager only - store as array (backend expects list)
                let managerId = manager.email ?? manager.phoneNumber
                let managerIds = [managerId]
                
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData(["managerIds": managerIds])
                
                managerName = manager.name
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update project manager: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func removeProjectManager() {
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            do {
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData(["managerIds": []])
                
                managerName = nil
                selectedManager = nil
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to remove project manager: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func updateProjectTeam() {
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            do {
                if tempApprover != nil {
                    saveTempApprover()
                }
                
                // Single manager only - store as array (backend expects list)
                let managerId = selectedManager?.email ?? selectedManager?.phoneNumber ?? ""
                let managerIds = managerId.isEmpty ? [] : [managerId]
                let data: [String: Any] = [
                    "managerIds": managerIds,
                    "teamMembers": Array(selectedTeamMembers).map { $0.phoneNumber }
                ]
                
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData(data)
                
                teamMembers = Array(selectedTeamMembers).map { $0.phoneNumber }
                managerName = selectedManager?.name
                isEditingTeam = false
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update project team: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func updateTempApproverID(_ newTempApproverID: String?) {
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            do {
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData(["tempApproverID": newTempApproverID as Any])
                
                tempApproverID = newTempApproverID
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update temporary approver: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Team Management
    
    func selectManager(_ user: User) {
        selectedManager = user
        approverSearchText = ""
        managerName = user.name
    }
    
    func removeManager(_ user: User) {
        selectedManager = nil
        managerName = nil
    }
    
    func selectTeamMember(_ user: User) {
        selectedTeamMembers.insert(user)
        teamMemberSearchText = ""
    }
    
    func removeTeamMember(_ user: User) {
        selectedTeamMembers.remove(user)
    }
    
    // MARK: - Temporary Approver Methods
    
    func setTempApprover(_ tempApprover: TempApprover) {
        self.tempApprover = nil
        self.tempApprover = tempApprover
    }
    
    func removeTempApprover() {
        // Only update local state - keep documents in Firebase for audit/history
        tempApprover = nil
        tempApproverName = nil
        updateTempApproverID(nil)
        
        // Notify that project was updated
        NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
        
        print("ℹ️ Temp approver removed from UI (kept in Firebase for audit)")
    }
    
    func saveTempApprover() {
        Task {
            guard let customerId = customerId, let projectId = project.id, let tempApprover = tempApprover else {
                errorMessage = "Customer ID, Project ID, or Temp Approver not found."
                showError = true
                return
            }
            
            do {
                let newApproverID = UUID().uuidString
                // Save to customer-specific project's tempApprover subcollection
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .collection("tempApprover")
                    .document(newApproverID)
                    .setData(from: tempApprover)
                
                // Update the local state
                updateTempApproverID(tempApprover.approverId)
                
                // Fetch the updated temp approver from Firebase
                await fetchTempApprover()
                
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to save temporary approver: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Expenses Count Check
    
    func checkExpensesCount() async {
        guard let customerId = customerId, let projectId = project.id else { return }
        
        do {
            let expensesSnapshot = try await FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: projectId)
                .getDocuments()
            
            await MainActor.run {
                self.expensesCount = expensesSnapshot.documents.count
            }
        } catch {
            print("Error checking expenses count: \(error)")
        }
    }
    
    // MARK: - Fetch Highest Phase End Date
    
    func fetchHighestPhaseEndDate() async {
        guard let customerId = customerId, let projectId = project.id else { return }
        
        do {
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .getDocuments()
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            
            var highestEndDate: Date? = nil
            
            for doc in phasesSnapshot.documents {
                if let phase = try? doc.data(as: Phase.self),
                   let endDateStr = phase.endDate,
                   let endDate = dateFormatter.date(from: endDateStr) {
                    if highestEndDate == nil || endDate > highestEndDate! {
                        highestEndDate = endDate
                    }
                }
            }
            
            await MainActor.run {
                self.highestPhaseEndDate = highestEndDate
            }
        } catch {
            print("Error fetching highest phase end date: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Refresh All Data
    
    /// Refreshes all data from Firestore, following Apple's best practices for data synchronization
    func refreshAllData() async {
        guard let customerId = customerId, let projectId = project.id else {
            return
        }
        
        isLoading = true
        
        // Use structured concurrency to load all data in parallel for optimal performance
        async let usersTask = fetchUsers()
        async let teamMembersTask = fetchTeamMembers()
        async let tempApproverTask = fetchTempApprover()
        async let expensesCountTask = checkExpensesCount()
        async let phaseEndDateTask = fetchHighestPhaseEndDate()
        
        // Wait for all tasks to complete
        await usersTask
        await teamMembersTask
        await tempApproverTask
        await expensesCountTask
        await phaseEndDateTask
        
        // Reload project data from Firestore to get latest changes
        do {
            let projectDoc = try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .getDocument()
            
            if projectDoc.exists, let updatedProject = try? projectDoc.data(as: Project.self) {
                // Update local properties with latest project data
                await MainActor.run {
                    self.projectName = updatedProject.name
                    self.projectDescription = updatedProject.description
                    self.projectStatus = updatedProject.status
                    self.client = updatedProject.client
                    self.location = updatedProject.location
                    self.teamMembers = updatedProject.teamMembers
                    self.tempApproverID = updatedProject.tempApproverID
                    
                    // Update dates
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "dd/MM/yyyy"
                    
                    if let startDateStr = updatedProject.startDate,
                       let startDate = dateFormatter.date(from: startDateStr) {
                        self.startDate = startDate
                    }
                    
                    if let endDateStr = updatedProject.endDate,
                       let endDate = dateFormatter.date(from: endDateStr) {
                        self.endDate = endDate
                    }
                    
                    if let plannedDateStr = updatedProject.plannedDate,
                       let plannedDate = dateFormatter.date(from: plannedDateStr) {
                        self.plannedDate = plannedDate
                    }
                    
                    if let handoverDateStr = updatedProject.handoverDate,
                       let handoverDate = dateFormatter.date(from: handoverDateStr) {
                        self.handoverDate = handoverDate
                    }
                    
                    if let initialHandOverDateStr = updatedProject.initialHandOverDate,
                       let initialHandOverDate = dateFormatter.date(from: initialHandOverDateStr) {
                        self.initialHandOverDate = initialHandOverDate
                    } else if let handoverDateStr = updatedProject.handoverDate,
                              let handoverDate = dateFormatter.date(from: handoverDateStr) {
                        // Fallback to handoverDate if initialHandOverDate is not set
                        self.initialHandOverDate = handoverDate
                    }
                    
                    if let maintenanceDateStr = updatedProject.maintenanceDate,
                       let maintenanceDate = dateFormatter.date(from: maintenanceDateStr) {
                        self.maintenanceDate = maintenanceDate
                    }
                    
                    // Update suspension properties
                    self.isSuspended = updatedProject.isSuspended ?? false
                    if let suspendedDateStr = updatedProject.suspendedDate,
                       let suspendedDate = dateFormatter.date(from: suspendedDateStr) {
                        self.suspendedDate = suspendedDate
                    } else {
                        self.suspendedDate = nil
                    }
                    self.suspensionReason = updatedProject.suspensionReason ?? ""
                    
                    // Update manager selection if managerIds changed
                    if let firstManagerId = updatedProject.managerIds.first {
                        // Find matching approver
                        if let manager = allApprovers.first(where: { approver in
                            approver.phoneNumber == firstManagerId || approver.email == firstManagerId
                        }) {
                            self.selectedManager = manager
                            self.managerName = manager.name
                        }
                    } else {
                        self.selectedManager = nil
                        self.managerName = nil
                    }
                    
                    // Update team members selection
                    selectedTeamMembers = Set(allUsers.filter { user in
                        updatedProject.teamMembers.contains(user.phoneNumber)
                    })
                    
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to refresh project data: \(error.localizedDescription)"
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Delete Project
    
    var canDeleteProject: Bool {
        (project.statusType == .LOCKED || project.statusType == .DECLINED || project.statusType == .IN_REVIEW || project.statusType == .ACTIVE) && expensesCount == 0
    }
    
    func deleteProject() {
        guard let customerId = customerId, let projectId = project.id else {
            errorMessage = "Customer ID or Project ID not found."
            showError = true
            return
        }
        
        isDeleting = true
        
        Task {
            do {
                // Delete the project document from customer-specific projects collection
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .delete()
                
                // Also delete all subcollections (phases, expenses, etc.) if they exist
                // Firestore doesn't automatically delete subcollections, but for now we'll just delete the main document
                // The subcollections will remain but won't be accessible without the parent document
                
                await MainActor.run {
                    self.isDeleting = false
                    self.showDeleteConfirmation = false
                    
                    // Notify that project was deleted
                    NotificationCenter.default.post(name: NSNotification.Name("ProjectDeleted"), object: projectId)
                }
            } catch {
                await MainActor.run {
                    self.isDeleting = false
                    self.errorMessage = "Failed to delete project: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
} 
