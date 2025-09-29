//
//  CreateProjectViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//

// CreateProjectViewModel.swift

import Foundation
import FirebaseFirestore
import Combine


struct DepartmentItem: Identifiable {
    let id = UUID()
    var name: String = ""
    var amount: String = "" // Use String for TextField, convert to Double later
}


@MainActor // Ensures all UI updates happen on the main thread
class CreateProjectViewModel: ObservableObject {
    
    // MARK: - Form Inputs
    @Published var projectName: String = ""
    @Published var projectDescription: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(86400 * 30) // Default to 30 days
    @Published var departments: [DepartmentItem] = [DepartmentItem()]
    
    // MARK: - Date Toggle States
    @Published var hasStartDate: Bool = false
    @Published var hasEndDate: Bool = false
    
    // MARK: - User Selection State
    @Published var managerSearchText: String = ""
    @Published var teamMemberSearchText: String = ""
    
    @Published var selectedManager: User?
    @Published var selectedTeamMembers: Set<User> = []
    
    // MARK: - Data Source for Dropdowns (private)
    @Published private var allApprovers: [User] = []
    @Published private var allUsers: [User] = []

    // MARK: - UI State
    @Published var isLoading: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var errorMessage: String? = nil
    @Published var showSuccessMessage: Bool = false
    
    private var db = Firestore.firestore()
    private var authService: FirebaseAuthService?
    
    // MARK: - Computed Properties for Filtering
    
    var filteredApprovers: [User] {
        if managerSearchText.isEmpty { return [] }
        return allApprovers.filter {
            $0.isActive && // Only show active approvers
            ($0.name.localizedCaseInsensitiveContains(managerSearchText) ||
            $0.phoneNumber.localizedCaseInsensitiveContains(managerSearchText))
        }
    }
    
    var filteredTeamMembers: [User] {
        if teamMemberSearchText.isEmpty { return [] }
        // Filter by search text AND ensure the user is not already selected AND is active
        return allUsers.filter { user in
            let isNotSelected = !selectedTeamMembers.contains(user)
            let isActive = user.isActive // Only show active users
            let matchesSearch = user.name.localizedCaseInsensitiveContains(teamMemberSearchText) ||
                                user.phoneNumber.localizedCaseInsensitiveContains(teamMemberSearchText)
            return isNotSelected && isActive && matchesSearch
        }
    }
    
    // MARK: - Computed Properties for Validation & Display
    
    var totalBudget: Double {
        departments.compactMap { Double($0.amount) }.reduce(0, +)
    }
    
    var totalBudgetFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: totalBudget)) ?? "₹0.00"
    }
    
    var isFormValid: Bool {
        let basicFieldsValid = !projectName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !projectDescription.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedManager != nil && // A manager must be selected
        !departments.contains { $0.name.isEmpty || (Double($0.amount) ?? 0) <= 0 }
        
        // Date validation: if both dates are set, end date must be after start date
        let dateValidation = !(hasStartDate && hasEndDate && endDate <= startDate)
        
        return basicFieldsValid && dateValidation
    }
    
    // MARK: - Initialization
    init(authService: FirebaseAuthService? = nil) {
        self.authService = authService
        Task {
            await fetchUsers()
        }
    }
    
    // MARK: - Data Fetching using AuthService
    func fetchUsers() async {
        isLoading = true
        errorMessage = nil
        
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
                    } else if user.role == .APPROVER {
                        loadedApprovers.append(user)
                    }
                }
            }
            
            // Sort users by name
            allUsers = loadedUsers.sorted { $0.name < $1.name }
            allApprovers = loadedApprovers.sorted { $0.name < $1.name }
            
            // If there's only one approver, select them by default
            if allApprovers.count == 1 {
                selectedManager = allApprovers[0]
            }
            
            isLoading = false
        } catch {
            print("Error fetching users: \(error)")
            errorMessage = "Failed to load users: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - User Selection Methods
    func selectManager(_ manager: User) {
        selectedManager = manager
        managerSearchText = ""
    }
    
    func selectTeamMember(_ member: User) {
        selectedTeamMembers.insert(member)
        teamMemberSearchText = ""
    }
    
    func removeTeamMember(_ member: User) {
        selectedTeamMembers.remove(member)
    }

    // MARK: - Department Management
    func addDepartment() {
        departments.append(DepartmentItem())
    }
    
    func removeDepartment(at offsets: IndexSet) {
        departments.remove(atOffsets: offsets)
    }

    // MARK: - Firestore Saving Logic
    func saveProject() {
        Task {
            guard isFormValid else {
                errorMessage = "Please fill in all required fields"
                return
            }
            
            isLoading = true
            errorMessage = nil
            
            do {
                let docRef = db.collection(FirebaseCollections.projects).document()
                
                // Get selected team members' phone numbers
                let teamMemberPhones = selectedTeamMembers.map { $0.phoneNumber }
                
                // Format dates to strings
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                let startDateStr = hasStartDate ? dateFormatter.string(from: startDate) : nil
                let endDateStr = hasEndDate ? dateFormatter.string(from: endDate) : nil
                
                // Create project data
                let projectData = Project(
                    id: docRef.documentID,
                    name: projectName,
                    description: projectDescription,
                    budget: totalBudget,
                    status: ProjectStatus.ACTIVE.rawValue,
                    startDate: startDateStr,
                    endDate: endDateStr,
                    teamMembers: teamMemberPhones,
                    managerId: selectedManager?.phoneNumber ?? "",
                    tempApproverID: nil,
                    departments: Dictionary(uniqueKeysWithValues: departments.map { ($0.name, Double($0.amount) ?? 0) }),
                    createdAt: Timestamp(),
                    updatedAt: Timestamp()
                )
                
                try await docRef.setData(from: projectData)
                
                // Show success message and reset form
                isLoading = false
                showSuccessMessage = true
                resetForm()
                
            } catch {
                isLoading = false
                errorMessage = "Failed to create project: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Helper Methods
    private func resetForm() {
        projectName = ""
        projectDescription = ""
        startDate = Date()
        endDate = Date().addingTimeInterval(86400 * 30)
        hasStartDate = false
        hasEndDate = false
        departments = [DepartmentItem()]
        selectedManager = nil
        selectedTeamMembers.removeAll()
        managerSearchText = ""
        teamMemberSearchText = ""
        showSuccessMessage = false
        errorMessage = nil
    }
    
    // MARK: - Set AuthService
    func setAuthService(_ authService: FirebaseAuthService) {
        self.authService = authService
        Task {
            await fetchUsers() // Refresh users with new auth service
        }
    }
}
