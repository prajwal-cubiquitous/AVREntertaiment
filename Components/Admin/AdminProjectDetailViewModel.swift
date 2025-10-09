import SwiftUI
import FirebaseFirestore

@MainActor
class AdminProjectDetailViewModel: ObservableObject {
    // Project Data
    @Published var projectName: String
    @Published var projectDescription: String
    @Published var projectStatus: String
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var departments: [DepartmentItem]
    @Published var teamMembers: [String]
    @Published var managerName: String
    @Published var tempApproverID: String?
    
    // Temporary Approver Properties
    @Published var tempApprover: TempApprover?
    @Published var tempApproverName: String?
    @Published var showingTempApproverSheet = false
    
    // Temporary departments for editing
    @Published var tempDepartments: [DepartmentItem] = []
    
    // Computed total budget from departments
    var totalBudget: Double {
        departments.reduce(0) { sum, department in
            sum + (Double(department.amount) ?? 0)
        }
    }
    
    // Computed total budget from temp departments (for preview while editing)
    var tempTotalBudget: Double {
        tempDepartments.reduce(0) { sum, department in
            sum + (Double(department.amount) ?? 0)
        }
    }
    
    // Edit States
    @Published var isEditingName = false
    @Published var isEditingDescription = false
    @Published var isEditingDates = false
    @Published var isEditingTeam = false
    @Published var isEditingDepartments = false {
        didSet {
            if isEditingDepartments {
                // When starting to edit, copy departments to temp
                tempDepartments = departments
            }
        }
    }
    
    // Team Selection
    @Published var approverSearchText = ""
    @Published var teamMemberSearchText = ""
    @Published var selectedTeamMembers: Set<User> = []
    @Published var selectedApprover: User?
    @Published var allApprovers: [User] = []
    @Published private var allUsers: [User] = []
    
    // UI State
    @Published var showError = false
    @Published var showSuccess = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    private let project: Project
    private let db = Firestore.firestore()
    
    init(project: Project) {
        self.project = project
        self.projectName = project.name
        self.projectDescription = project.description
        self.projectStatus = project.status
        
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
        
        // Convert departments dictionary to array
        self.departments = project.departments.map { DepartmentItem(name: $0.key, amount: String($0.value)) }
        self.teamMembers = project.teamMembers
        self.managerName = project.managerId
        self.tempApproverID = project.tempApproverID
        
        Task {
            await fetchUsers()
            await fetchTempApprover()
        }
    }
    
    var dateRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    var filteredApprovers: [User] {
        if approverSearchText.isEmpty { return [] }
        return allApprovers.filter {
            $0.isActive &&
            ($0.name.localizedCaseInsensitiveContains(approverSearchText) ||
             $0.phoneNumber.localizedCaseInsensitiveContains(approverSearchText))
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
        do {
            let querySnapshot = try await db.collection(FirebaseCollections.users)
                .whereField("role", in: [UserRole.USER.rawValue, UserRole.APPROVER.rawValue])
                .whereField("isActive", isEqualTo: true)
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
                        if user.phoneNumber == project.managerId {
                            selectedApprover = user
                            managerName = user.name
                        }
                    }
                }
            }
            
            allUsers = loadedUsers.sorted { $0.name < $1.name }
            allApprovers = loadedApprovers.sorted { $0.name < $1.name }
            
        } catch {
            errorMessage = "Failed to load users: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func fetchTempApprover() async {
        guard let tempApproverID = project.tempApproverID else {
            self.tempApprover = nil
            return
        }
        
        do {
            // Fetch the user from users collection using tempApproverID as document ID
            let userDocument = try await db
                .collection(FirebaseCollections.users)
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
            do {
                try await db.collection(FirebaseCollections.projects).document(project.id ?? "")
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
            do {
                try await db.collection(FirebaseCollections.projects).document(project.id ?? "")
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
    
    func updateProjectStatus(_ newStatus: ProjectStatus) {
        Task {
            do {
                try await db.collection(FirebaseCollections.projects).document(project.id ?? "")
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
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                
                let data: [String: Any] = [
                    "startDate": dateFormatter.string(from: startDate),
                    "endDate": dateFormatter.string(from: endDate)
                ]
                
                try await db.collection(FirebaseCollections.projects).document(project.id ?? "")
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
            do {
                
                if tempApprover != nil {
                    saveTempApprover()
                }
                let data: [String: Any] = [
                    "managerId": selectedApprover?.phoneNumber ?? project.managerId,
                    "teamMembers": Array(selectedTeamMembers).map { $0.phoneNumber }
                ]
                
                try await db.collection(FirebaseCollections.projects).document(project.id ?? "")
                    .updateData(data)
                
                teamMembers = Array(selectedTeamMembers).map { $0.phoneNumber }
                managerName = selectedApprover?.name ?? managerName
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
            do {
                try await db.collection(FirebaseCollections.projects).document(project.id ?? "")
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
    
    func updateProjectDepartments() {
        Task {
            do {
                // Get current department names
                let currentDepartmentNames = Set(departments.map { $0.name })
                let newDepartmentNames = Set(tempDepartments.map { $0.name })
                
                // Find deleted departments
                let deletedDepartments = currentDepartmentNames.subtracting(newDepartmentNames)
                
                // Move expenses from deleted departments to anonymous
                if !deletedDepartments.isEmpty {
                    await moveExpensesToAnonymous(departments: Array(deletedDepartments))
                }
                
                let departmentsDict = Dictionary(
                    uniqueKeysWithValues: tempDepartments.map { ($0.name, Double($0.amount) ?? 0) }
                )
                
                let data: [String: Any] = [
                    "departments": departmentsDict,
                    "budget": tempTotalBudget
                ]
                
                try await db.collection(FirebaseCollections.projects).document(project.id ?? "")
                    .updateData(data)
                
                // Only update the actual departments after successful save
                departments = tempDepartments
                isEditingDepartments = false
                showSuccess = true
                
                // Notify that project was updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
            } catch {
                errorMessage = "Failed to update departments: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Anonymous Department Management
    
    private func moveExpensesToAnonymous(departments: [String]) async {
        guard let projectId = project.id else { return }
        
        for departmentName in departments {
            do {
                // Find all expenses in this department
                let expensesSnapshot = try await db.collection(FirebaseCollections.projects)
                    .document(projectId)
                    .collection("expenses")
                    .whereField("department", isEqualTo: departmentName)
                    .getDocuments()
                
                // Update each expense to be anonymous
                let batch = db.batch()
                let currentTime = Timestamp()
                
                for expenseDoc in expensesSnapshot.documents {
                    let expenseRef = db.collection(FirebaseCollections.projects)
                        .document(projectId)
                        .collection("expenses")
                        .document(expenseDoc.documentID)
                    
                    batch.updateData([
                        "department": "Anonymous Department",
                        "isAnonymous": true,
                        "originalDepartment": departmentName,
                        "departmentDeletedAt": currentTime,
                        "updatedAt": currentTime
                    ], forDocument: expenseRef)
                }
                
                try await batch.commit()
                print("✅ Moved \(expensesSnapshot.documents.count) expenses from '\(departmentName)' to Anonymous Department")
                
            } catch {
                print("❌ Error moving expenses from '\(departmentName)' to anonymous: \(error)")
                errorMessage = "Failed to move expenses from deleted department '\(departmentName)': \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Team Management
    
    func selectApprover(_ user: User) {
        selectedApprover = user
        approverSearchText = ""
    }
    
    func selectTeamMember(_ user: User) {
        selectedTeamMembers.insert(user)
        teamMemberSearchText = ""
    }
    
    func removeTeamMember(_ user: User) {
        selectedTeamMembers.remove(user)
    }
    
    // MARK: - Department Management
    
    func addDepartment() {
        tempDepartments.append(DepartmentItem())
    }
    
    func removeDepartment(_ department: DepartmentItem) {
        tempDepartments.removeAll { $0.id == department.id }
    }
    
    func updateDepartmentAmount(_ department: DepartmentItem, amount: String) {
        if let index = tempDepartments.firstIndex(where: { $0.id == department.id }) {
            tempDepartments[index].amount = amount
        }
    }
    
    func updateDepartmentName(_ department: DepartmentItem, name: String) {
        if let index = tempDepartments.firstIndex(where: { $0.id == department.id }) {
            tempDepartments[index].name = name
        }
    }
    
    func cancelDepartmentEditing() {
        tempDepartments = departments
        isEditingDepartments = false
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
            do {
                let newApproverID = UUID().uuidString
                // In a real implementation, this would save to Firestore
                try await db.collection(FirebaseCollections.projects).document(project.id ?? "").collection("tempApprover").document(newApproverID).setData(from: tempApprover)
                // Update the local state
                updateTempApproverID(tempApprover?.approverId)
                
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
} 
