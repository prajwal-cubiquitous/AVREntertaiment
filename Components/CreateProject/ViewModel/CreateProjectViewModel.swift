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

struct PhaseItem: Identifiable {
    let id = UUID()
    var phaseNumber: Int
    var phaseName: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(86400 * 30)
    var hasStartDate: Bool = false
    var hasEndDate: Bool = false
    var managerSearchText: String = ""
    var teamMemberSearchText: String = ""
    var selectedManager: User?
    var selectedTeamMembers: Set<User> = []
    var departments: [DepartmentItem] = [DepartmentItem()]
    var categories: [String] = []
}

@MainActor // Ensures all UI updates happen on the main thread
class CreateProjectViewModel: ObservableObject {
    
    // MARK: - Form Inputs
    @Published var projectName: String = ""
    @Published var projectDescription: String = ""
    @Published var client: String = ""
    @Published var location: String = ""
    @Published var currency: String = "INR" // Only INR exposed in UI for now
    @Published var phases: [PhaseItem] = [PhaseItem(phaseNumber: 1)]
    @Published var allowTemplateOverrides: Bool = false
    
    // MARK: - Data Source for Dropdowns (private)
    @Published private var allApprovers: [User] = []
    @Published private var allUsers: [User] = []

    // Project-level selections (same for all phases)
    @Published var selectedProjectManagers: [User] = []
    @Published var selectedProjectTeamMembers: Set<User> = []
    @Published var projectManagerSearchText: String = ""
    @Published var projectTeamMemberSearchText: String = ""

    // MARK: - UI State
    @Published var isLoading: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var errorMessage: String? = nil
    @Published var showSuccessMessage: Bool = false
    
    private var db = Firestore.firestore()
    private var authService: FirebaseAuthService?
    
    // MARK: - Computed Properties for Filtering
    
    func filteredApprovers(for phase: PhaseItem) -> [User] {
        if phase.managerSearchText.isEmpty { return [] }
        return allApprovers.filter {
            $0.isActive && // Only show active approvers
            ($0.name.localizedCaseInsensitiveContains(phase.managerSearchText) ||
            $0.phoneNumber.localizedCaseInsensitiveContains(phase.managerSearchText))
        }
    }
    
    func filteredTeamMembers(for phase: PhaseItem) -> [User] {
        if phase.teamMemberSearchText.isEmpty { return [] }
        // Filter by search text AND ensure the user is not already selected AND is active
        return allUsers.filter { user in
            let isNotSelected = !phase.selectedTeamMembers.contains(user)
            let isActive = user.isActive // Only show active users
            let matchesSearch = user.name.localizedCaseInsensitiveContains(phase.teamMemberSearchText) ||
                                user.phoneNumber.localizedCaseInsensitiveContains(phase.teamMemberSearchText)
            return isNotSelected && isActive && matchesSearch
        }
    }

    // Project-level filters
    func filteredProjectManagers() -> [User] {
        if projectManagerSearchText.isEmpty { return [] }
        return allApprovers.filter {
            $0.isActive && ($0.name.localizedCaseInsensitiveContains(projectManagerSearchText) ||
                            $0.phoneNumber.localizedCaseInsensitiveContains(projectManagerSearchText) ||
                            ($0.email ?? "").localizedCaseInsensitiveContains(projectManagerSearchText))
        }
    }
    
    func filteredProjectTeamMembers() -> [User] {
        if projectTeamMemberSearchText.isEmpty { return [] }
        return allUsers.filter { user in
            let isNotSelected = !selectedProjectTeamMembers.contains(user)
            let matches = user.name.localizedCaseInsensitiveContains(projectTeamMemberSearchText) ||
                          user.phoneNumber.localizedCaseInsensitiveContains(projectTeamMemberSearchText)
            return user.isActive && isNotSelected && matches
        }
    }
    
    // MARK: - Computed Properties for Validation & Display
    
    var totalBudget: Double {
        phases.reduce(0) { total, phase in
            total + phase.departments.compactMap { Double($0.amount) }.reduce(0, +)
        }
    }
    
    var totalBudgetFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: totalBudget)) ?? "₹0.00"
    }
    
    var isFormValid: Bool {
        // Basic fields validation
        guard !projectName.trimmingCharacters(in: .whitespaces).isEmpty,
              !projectDescription.trimmingCharacters(in: .whitespaces).isEmpty,
              !client.trimmingCharacters(in: .whitespaces).isEmpty,
              !location.trimmingCharacters(in: .whitespaces).isEmpty,
              !phases.isEmpty else {
            return false
        }
        
        // Validate project-level selections
        if selectedProjectManagers.isEmpty { return false }
        if selectedProjectTeamMembers.isEmpty { return false }

        // Validate each phase
        for phase in phases {
            // Phase name required
            if phase.phaseName.trimmingCharacters(in: .whitespaces).isEmpty {
                return false
            }
            
            // At least one department required
            if phase.departments.isEmpty || phase.departments.allSatisfy({ $0.name.isEmpty || (Double($0.amount) ?? 0) <= 0 }) {
                return false
            }
            
            // Date validation: if both dates are set, end date must be after start date
            if phase.hasStartDate && phase.hasEndDate && phase.endDate <= phase.startDate {
                return false
            }
        }
        
        // Validate phase timeline: next phase must start after previous phase ends
        for i in 0..<phases.count - 1 {
            let currentPhase = phases[i]
            let nextPhase = phases[i + 1]
            
            if currentPhase.hasEndDate && nextPhase.hasStartDate {
                if nextPhase.startDate <= currentPhase.endDate {
                    return false
                }
            }
        }
        
        return true
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
            
            isLoading = false
        } catch {
            print("Error fetching users: \(error)")
            errorMessage = "Failed to load users: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Phase Management
    func addPhase() {
        let nextPhaseNumber = phases.count + 1
        var newPhase = PhaseItem(phaseNumber: nextPhaseNumber)
        
        // If previous phase has end date, set start date to day after
        if let lastPhase = phases.last, lastPhase.hasEndDate {
            newPhase.startDate = Calendar.current.date(byAdding: .day, value: 1, to: lastPhase.endDate) ?? Date()
            newPhase.hasStartDate = true
        }
        
        phases.append(newPhase)
    }
    
    func removePhase(at offsets: IndexSet) {
        phases.remove(atOffsets: offsets)
        // Renumber phases
        for (index, _) in phases.enumerated() {
            phases[index].phaseNumber = index + 1
        }
    }
    
    // MARK: - Phase Management Helpers
    func updatePhaseManager(_ phaseId: UUID, manager: User) {
        if let index = phases.firstIndex(where: { $0.id == phaseId }) {
            phases[index].selectedManager = manager
            phases[index].managerSearchText = ""
        }
    }
    
    func selectTeamMember(for phaseId: UUID, member: User) {
        if let index = phases.firstIndex(where: { $0.id == phaseId }) {
            phases[index].selectedTeamMembers.insert(member)
            phases[index].teamMemberSearchText = ""
        }
    }
    
    func removeTeamMember(for phaseId: UUID, member: User) {
        if let index = phases.firstIndex(where: { $0.id == phaseId }) {
            phases[index].selectedTeamMembers.remove(member)
        }
    }
    
    func addDepartment(to phaseId: UUID) {
        if let index = phases.firstIndex(where: { $0.id == phaseId }) {
            phases[index].departments.append(DepartmentItem())
        }
    }
    
    func removeDepartment(from phaseId: UUID, at offsets: IndexSet) {
        if let index = phases.firstIndex(where: { $0.id == phaseId }) {
            phases[index].departments.remove(atOffsets: offsets)
        }
    }

    // MARK: - Firestore Saving Logic
    func saveProject() {
        Task {
            guard isFormValid else {
                errorMessage = "Please fill in all required fields and ensure phase timelines are valid"
                return
            }
            
            isLoading = true
            errorMessage = nil
            
            do {
                // Calculate total budget from all phases
                let totalBudget = phases.reduce(0) { total, phase in
                    total + phase.departments.compactMap { Double($0.amount) }.reduce(0, +)
                }
                
                // Project-level team members and managers
                let allTeamMembers = Set(selectedProjectTeamMembers.map { $0.phoneNumber })
                let managerIds = selectedProjectManagers.map { $0.email ?? $0.phoneNumber }.filter { !$0.isEmpty }
                
                // Create project data (without departments, they're in phases now)
                let docRef = db.collection(FirebaseCollections.projects).document()
                
                let projectData = Project(
                    id: docRef.documentID,
                    name: projectName,
                    description: projectDescription,
                    client: client,
                    location: location,
                    currency: currency,
                    budget: totalBudget,
                    status: ProjectStatus.ACTIVE.rawValue,
                    startDate: nil, // Removed from main project
                    endDate: nil, // Removed from main project
                    teamMembers: Array(allTeamMembers),
                    managerIds: managerIds,
                    tempApproverID: nil,
                    Allow_Template_Overrides: allowTemplateOverrides,
                    createdAt: Timestamp(),
                    updatedAt: Timestamp()
                )
                
                // Save project
                try await docRef.setData(from: projectData)
                
                // Save phases in subcollection
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                
                for phase in phases {
                    let phaseRef = docRef.collection("phases").document()
                    
                    // Format dates
                    let startDateStr = phase.hasStartDate ? dateFormatter.string(from: phase.startDate) : nil
                    let endDateStr = phase.hasEndDate ? dateFormatter.string(from: phase.endDate) : nil
                    
                    // Create departments dictionary
                    let departmentsDict = Dictionary(uniqueKeysWithValues: phase.departments.map { ($0.name, Double($0.amount) ?? 0) })
                    
                    let phaseData = Phase(
                        id: phaseRef.documentID,
                        phaseName: phase.phaseName,
                        phaseNumber: phase.phaseNumber,
                        startDate: startDateStr,
                        endDate: endDateStr,
                        departments: departmentsDict,
                        categories: phase.categories,
                        createdAt: Timestamp(),
                        updatedAt: Timestamp()
                    )
                    
                    try await phaseRef.setData(from: phaseData)
                }
                
                // Show success message and reset form
                isLoading = false
                showSuccessMessage = true
                alertMessage = "Project created successfully!"
                showAlert = true
                resetForm()
                
                // Notify that a new project was created
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
                
            } catch {
                isLoading = false
                errorMessage = "Failed to create project: \(error.localizedDescription)"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
    
    // MARK: - Helper Methods
    private func resetForm() {
        projectName = ""
        projectDescription = ""
        client = ""
        location = ""
        currency = "INR"
        selectedProjectManagers = []
        selectedProjectTeamMembers = []
        projectManagerSearchText = ""
        projectTeamMemberSearchText = ""
        phases = [PhaseItem(phaseNumber: 1)]
        allowTemplateOverrides = false
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
