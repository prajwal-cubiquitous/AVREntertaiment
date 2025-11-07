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
    @Published var isEditingTeam = false
    
    // Team Selection
    @Published var approverSearchText = ""
    @Published var teamMemberSearchText = ""
    @Published var selectedTeamMembers: Set<User> = []
    @Published var selectedManager: User? = nil // Single manager only
    @Published var allApprovers: [User] = []
    @Published private var allUsers: [User] = []
    
    // UI State
    @Published var showError = false
    @Published var showSuccess = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var expensesCount: Int = 0
    @Published var showDeleteConfirmation = false
    @Published var isDeleting = false
    
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
        
        self.teamMembers = project.teamMembers
        self.tempApproverID = project.tempApproverID
        
        Task {
            await fetchUsers()
            await fetchTempApprover()
            await checkExpensesCount()
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
        Task {
            guard let customerId = customerId, let projectId = project.id else {
                errorMessage = "Customer ID or Project ID not found."
                showError = true
                return
            }
            
            do {
                try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .updateData(["status": newStatus.rawValue])
                
                projectStatus = newStatus.rawValue
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update project status: \(error.localizedDescription)"
                showError = true
            }
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
    
    // MARK: - Delete Project
    
    var canDeleteProject: Bool {
        project.statusType == .DRAFT && expensesCount == 0
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
