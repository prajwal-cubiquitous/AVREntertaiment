//
//  CreateProjectViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//

// CreateProjectViewModel.swift

import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine
import UIKit
import UniformTypeIdentifiers
import SwiftUI

struct DepartmentItem: Identifiable, Codable {
    let id: UUID
    var name: String = ""
    var amount: String = "" // Use String for TextField, convert to Double later
    var contractorMode: ContractorMode = .labourOnly
    var lineItems: [DepartmentLineItem] = [DepartmentLineItem()]
    
    init(id: UUID = UUID(), name: String = "", amount: String = "", contractorMode: ContractorMode = .labourOnly, lineItems: [DepartmentLineItem] = [DepartmentLineItem()]) {
        self.id = id
        self.name = name
        self.amount = amount
        self.contractorMode = contractorMode
        self.lineItems = lineItems.isEmpty ? [DepartmentLineItem()] : lineItems
    }
    
    var totalBudget: Double {
        lineItems.reduce(0) { $0 + $1.total }
    }
}

struct PhaseItem: Identifiable, Codable {
    let id: UUID
    var phaseNumber: Int
    var phaseName: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(86400 * 30)
    var hasStartDate: Bool = false
    var hasEndDate: Bool = false
    var managerSearchText: String = ""
    var teamMemberSearchText: String = ""
    var departments: [DepartmentItem] = [DepartmentItem()]
    var categories: [String] = []
    
    // For persistence: store manager and team member identifiers
    var selectedManagerId: String? = nil // phoneNumber or email
    var selectedTeamMemberIds: [String] = [] // phoneNumbers
    
    // Non-Codable properties (will be restored from IDs)
    var selectedManager: User? = nil
    var selectedTeamMembers: Set<User> = []
    
    init(id: UUID = UUID(), phaseNumber: Int) {
        self.id = id
        self.phaseNumber = phaseNumber
    }
    
    // Custom Codable implementation to exclude User objects
    enum CodingKeys: String, CodingKey {
        case id, phaseNumber, phaseName, startDate, endDate
        case hasStartDate, hasEndDate, managerSearchText, teamMemberSearchText
        case departments, categories, selectedManagerId, selectedTeamMemberIds
    }
}

// Form state for persistence
struct CreateProjectFormState: Codable {
    var projectName: String
    var projectDescription: String
    var client: String
    var location: String
    var plannedDate: Date
    var currency: String
    var allowTemplateOverrides: Bool
    var phases: [PhaseItem]
    var selectedProjectManagerId: String? // phoneNumber or email
    var selectedProjectTeamMemberIds: [String] // phoneNumbers
    var attachmentURL: String?
    var attachmentName: String?
    var expandedPhaseIds: [String] // UUID strings of expanded phases
}

// Draft Project Model for Firestore
struct DraftProject: Identifiable, Codable {
    @DocumentID var id: String?
    var formState: CreateProjectFormState
    var createdAt: Timestamp
    var updatedAt: Timestamp
    
    init(formState: CreateProjectFormState, id: String? = nil) {
        self.id = id
        self.formState = formState
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
    }
    
    // Custom Codable implementation to handle Date <-> Timestamp conversion
    enum CodingKeys: String, CodingKey {
        case id, formState, createdAt, updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        formState = try container.decode(CreateProjectFormState.self, forKey: .formState)
        createdAt = try container.decode(Timestamp.self, forKey: .createdAt)
        updatedAt = try container.decode(Timestamp.self, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(formState, forKey: .formState)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

@MainActor // Ensures all UI updates happen on the main thread
class CreateProjectViewModel: ObservableObject {
    
    // MARK: - Form Inputs
    @Published var projectName: String = ""
    @Published var projectDescription: String = ""
    @Published var client: String = ""
    @Published var location: String = ""
    @Published var plannedDate: Date = Date() // Planned start date - project becomes ACTIVE when this date arrives
    @Published var currency: String = "INR" // Only INR exposed in UI for now
    @Published var phases: [PhaseItem] = {
        var initialPhase = PhaseItem(phaseNumber: 1)
        initialPhase.hasStartDate = true
        initialPhase.hasEndDate = true
        return [initialPhase]
    }()
    @Published var allowTemplateOverrides: Bool = false
    
    // MARK: - Data Source for Dropdowns
    @Published var allApprovers: [User] = [] // Made public for picker access
    @Published private var allUsers: [User] = []

    // Project-level selections (same for all phases)
    @Published var selectedProjectManager: User? = nil // Single manager only
    @Published var selectedProjectTeamMembers: Set<User> = []
    @Published var projectManagerSearchText: String = ""
    @Published var projectTeamMemberSearchText: String = ""

    // MARK: - UI State
    @Published var isLoading: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var errorMessage: String? = nil
    @Published var showSuccessMessage: Bool = false
    @Published var isSavingDraft: Bool = false
    @Published var showDraftList: Bool = false
    @Published var drafts: [DraftProject] = []
    @Published var currentDraftId: String? = nil // Track which draft is currently loaded
    
    // MARK: - Attachment State
    @Published var attachmentURL: String?
    @Published var attachmentName: String?
    @Published var showingDocumentPicker: Bool = false
    @Published var showingImagePicker: Bool = false
    @Published var showingAttachmentOptions: Bool = false
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading: Bool = false
    
    // MARK: - Validation State
    @Published var shouldShowValidationErrors: Bool = false
    @Published var isCheckingProjectName: Bool = false
    @Published var projectNameExists: Bool = false
    
    // MARK: - Edit Mode State
    @Published var isEditingMode: Bool = false
    @Published var editingProjectId: String? = nil
    @Published var firstInvalidFieldId: String? = nil
    
    private var db = Firestore.firestore()
    private var authService: FirebaseAuthService?
    private let storage = Storage.storage()
    
    // MARK: - Form State Persistence
    private let formStateKey = "CreateProjectFormState"
    private var saveCancellables = Set<AnyCancellable>()
    
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
            let isNotSelected = selectedProjectManager?.phoneNumber != $0.phoneNumber
            let isActive = $0.isActive
            let matchesSearch = $0.name.localizedCaseInsensitiveContains(projectManagerSearchText) ||
                            $0.phoneNumber.localizedCaseInsensitiveContains(projectManagerSearchText) ||
                            ($0.email ?? "").localizedCaseInsensitiveContains(projectManagerSearchText)
            return isNotSelected && isActive && matchesSearch
        }
    }
    
    func filteredProjectTeamMembers() -> [User] {
        return allUsers.filter { user in
            let isNotSelected = !selectedProjectTeamMembers.contains(user)
            let isActive = user.isActive
            // If search text is empty, show all (filtered by selection and active status)
            // If search text exists, also filter by search
            if projectTeamMemberSearchText.isEmpty {
                return isActive && isNotSelected
            } else {
                let matches = user.name.localizedCaseInsensitiveContains(projectTeamMemberSearchText) ||
                              user.phoneNumber.localizedCaseInsensitiveContains(projectTeamMemberSearchText)
                return isActive && isNotSelected && matches
            }
        }
    }
    
    // MARK: - Computed Properties for Validation & Display
    
    var totalBudget: Double {
        phases.reduce(0) { total, phase in
            total + phase.departments.compactMap { Double(removeFormatting(from: $0.amount)) }.reduce(0, +)
        }
    }
    
    var totalBudgetFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: totalBudget)) ?? "₹0.00"
    }
    
    // MARK: - Phase Budget Calculation
    
    func phaseBudget(for phaseId: UUID) -> Double {
        guard let phase = phases.first(where: { $0.id == phaseId }) else {
            return 0
        }
        return phase.departments.compactMap { Double(removeFormatting(from: $0.amount)) }.reduce(0, +)
    }
    
    func phaseBudgetFormatted(for phaseId: UUID) -> String {
        let budget = phaseBudget(for: phaseId)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: budget)) ?? "₹0.00"
    }
    
    // MARK: - Indian Number Formatting Helpers
    
    // Helper to remove formatting (commas, spaces, etc.)
    private func removeFormatting(from value: String) -> String {
        return value.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    // Format number according to Indian numbering system (lakhs, crores)
    // Indian numbering: from RIGHT, first 3 digits, then groups of 2
    // Examples: 1,000; 10,000; 1,00,000 (lakh); 10,00,000; 1,00,00,000 (crore)
    func formatIndianNumber(_ number: Double) -> String {
        // Handle decimal part
        let integerPart = Int(number)
        let decimalPart = number - Double(integerPart)
        
        // Convert integer to string
        let integerString = String(integerPart)
        let digits = Array(integerString)
        let count = digits.count
        
        // For numbers < 1000, no formatting needed (but still return as is)
        if count < 4 {
            var result = integerString
            // Add decimal part if exists
            if decimalPart > 0.0001 {
                let decimalString = String(format: "%.2f", decimalPart)
                if let dotIndex = decimalString.firstIndex(of: ".") {
                    let afterDot = String(decimalString[decimalString.index(after: dotIndex)...])
                    result += "." + afterDot
                }
            }
            return result
        }
        
        // Process from RIGHT to LEFT
        // Indian numbering: last 3 digits, then groups of 2, then remaining
        // Examples: 1,000; 10,000; 1,00,000; 10,00,000; 1,00,00,000
        var groups: [String] = []
        var remainingDigits = digits
        
        // Step 1: Take last 3 digits from right (ones, tens, hundreds)
        if remainingDigits.count >= 3 {
            let lastThree = String(remainingDigits.suffix(3))
            groups.append(lastThree) // Add to end (will be last group)
            remainingDigits = Array(remainingDigits.dropLast(3))
        } else {
            // Less than 3 digits total, just add them
            groups.append(String(remainingDigits))
            remainingDigits = []
        }
        
        // Step 2: Take groups of 2 digits from right (thousands, ten thousands, lakhs, etc.)
        while remainingDigits.count >= 2 {
            let lastTwo = String(remainingDigits.suffix(2))
            groups.insert(lastTwo, at: 0) // Insert at beginning (will be before last 3)
            remainingDigits = Array(remainingDigits.dropLast(2))
        }
        
        // Step 3: If one digit remains, add it at the beginning
        if remainingDigits.count == 1 {
            groups.insert(String(remainingDigits[0]), at: 0)
        }
        
        // Join with commas (groups are already in correct order: left to right)
        let result = groups.joined(separator: ",")
        
        // Add decimal part if exists
        var finalResult = result
        if decimalPart > 0.0001 {
            let decimalString = String(format: "%.2f", decimalPart)
            if let dotIndex = decimalString.firstIndex(of: ".") {
                let afterDot = String(decimalString[decimalString.index(after: dotIndex)...])
                finalResult += "." + afterDot
            }
        }
        
        return finalResult
    }
    
    // Method to format amount as user types
    func formatAmountInput(_ input: String) -> String {
        // Remove any existing formatting
        let cleaned = removeFormatting(from: input)
        
        // If empty, return empty
        guard !cleaned.isEmpty else { return "" }
        
        // Convert to number
        guard let number = Double(cleaned) else { return cleaned }
        
        // Format according to Indian numbering system
        return formatIndianNumber(number)
    }
    
    // MARK: - Check if form has any data
    var hasAnyData: Bool {
        !projectName.trimmingCharacters(in: .whitespaces).isEmpty ||
        !projectDescription.trimmingCharacters(in: .whitespaces).isEmpty ||
        !client.trimmingCharacters(in: .whitespaces).isEmpty ||
        !location.trimmingCharacters(in: .whitespaces).isEmpty ||
        selectedProjectManager != nil ||
        !selectedProjectTeamMembers.isEmpty ||
        phases.contains { phase in
            !phase.phaseName.trimmingCharacters(in: .whitespaces).isEmpty ||
            !phase.departments.isEmpty ||
            phase.departments.contains { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        } ||
        attachmentURL != nil
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
        if selectedProjectManager == nil { return false }
        if selectedProjectTeamMembers.isEmpty { return false }

        // Validate each phase
        for phase in phases {
            let trimmedName = phase.phaseName.trimmingCharacters(in: .whitespaces)
            
            // Phase name required
            if trimmedName.isEmpty {
                return false
            }
            
            // Check for duplicate phase names (case-insensitive)
            let duplicateCount = phases.filter { phaseItem in
                phaseItem.id != phase.id && // Exclude current phase
                phaseItem.phaseName.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
            }.count
            
            if duplicateCount > 0 {
                return false
            }
            
            // At least one department with a name required (budget can be 0)
            if phase.departments.isEmpty || phase.departments.allSatisfy({ $0.name.trimmingCharacters(in: .whitespaces).isEmpty }) {
                return false
            }
            
            // Check for duplicate department names within the same phase (case-insensitive)
            let departmentNames = phase.departments.map { $0.name.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let lowercasedNames = departmentNames.map { $0.lowercased() }
            let uniqueNames = Set(lowercasedNames)
            if lowercasedNames.count != uniqueNames.count {
                return false // Duplicate department names found
            }
            
            // Date validation: phase start date must be >= planned start date
            let calendar = Calendar.current
            let plannedStart = calendar.startOfDay(for: plannedDate)
            let phaseStart = calendar.startOfDay(for: phase.startDate)
            if phaseStart < plannedStart {
                return false
            }
            
            // Date validation: end date must be after start date (dates are now required)
            if phase.endDate <= phase.startDate {
                return false
            }
        }
        
        // Validate phase timeline: next phase must start after previous phase ends (dates are now required)
        for i in 0..<phases.count - 1 {
            let currentPhase = phases[i]
            let nextPhase = phases[i + 1]
            
            if nextPhase.startDate <= currentPhase.endDate {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Validation Error Messages
    
    var projectNameError: String? {
        // Always show duplicate error if it exists (even before validation)
        if projectNameExists {
            return "A project with this name already exists"
        }
        guard shouldShowValidationErrors else { return nil }
        if projectName.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Project name is required"
        }
        return nil
    }
    
    var projectDescriptionError: String? {
        guard shouldShowValidationErrors else { return nil }
        if projectDescription.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Project description is required"
        }
        return nil
    }
    
    var clientError: String? {
        guard shouldShowValidationErrors else { return nil }
        if client.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Client name is required"
        }
        return nil
    }
    
    var locationError: String? {
        guard shouldShowValidationErrors else { return nil }
        if location.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Location is required"
        }
        return nil
    }
    
    var plannedDateError: String? {
        guard shouldShowValidationErrors else { return nil }
        // Planned date is required
        return nil // No validation needed as DatePicker always has a value
    }
    
    var projectManagersError: String? {
        guard shouldShowValidationErrors else { return nil }
        if selectedProjectManager == nil {
            return "A project manager is required"
        }
        return nil
    }
    
    var projectTeamMembersError: String? {
        guard shouldShowValidationErrors else { return nil }
        if selectedProjectTeamMembers.isEmpty {
            return "At least one team member is required"
        }
        return nil
    }
    
    func phaseNameError(for phaseId: UUID) -> String? {
        guard let phase = phases.first(where: { $0.id == phaseId }) else { return nil }
        
        let trimmedName = phase.phaseName.trimmingCharacters(in: .whitespaces)
        
        // Check if phase name is empty (only show after submit attempt)
        if trimmedName.isEmpty {
            if shouldShowValidationErrors {
                return "Phase name is required"
            }
            return nil
        }
        
        // Check for duplicate phase names (case-insensitive) - show in real-time
        let duplicateCount = phases.filter { phaseItem in
            phaseItem.id != phaseId && // Exclude current phase
            phaseItem.phaseName.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }.count
        
        if duplicateCount > 0 {
            return "\"\(trimmedName)\" already exists in this project. Enter a unique phase name."
        }
        
        return nil
    }
    
    func phaseDateError(for phaseId: UUID) -> String? {
        guard let phase = phases.first(where: { $0.id == phaseId }) else { return nil }
        
        // Check if phase start date is before planned start date (show in real-time)
        let calendar = Calendar.current
        let plannedStart = calendar.startOfDay(for: plannedDate)
        let phaseStart = calendar.startOfDay(for: phase.startDate)
        
        if phaseStart < plannedStart {
            return "Phase start date must be on or after planned start date (\(formatDate(plannedDate)))"
        }
        
        // Check if end date is after start date (only show after submit attempt)
        if shouldShowValidationErrors {
            if phase.endDate <= phase.startDate {
                return "End date must be after start date"
            }
        }
        
        return nil
    }
    
    // Helper function to format date for error messages
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    func phaseTimelineError(for phaseId: UUID) -> String? {
        guard shouldShowValidationErrors else { return nil }
        guard let phaseIndex = phases.firstIndex(where: { $0.id == phaseId }),
              phaseIndex > 0 else { return nil }
        let currentPhase = phases[phaseIndex]
        let previousPhase = phases[phaseIndex - 1]
        if currentPhase.startDate <= previousPhase.endDate {
            return "Phase must start after the previous phase ends"
        }
        return nil
    }
    
    func departmentNameError(for phaseId: UUID, departmentId: UUID) -> String? {
        guard let phase = phases.first(where: { $0.id == phaseId }),
              let department = phase.departments.first(where: { $0.id == departmentId }) else { return nil }
        
        let trimmedName = department.name.trimmingCharacters(in: .whitespaces)
        
        // Check if department name is empty (only show after submit attempt)
        if trimmedName.isEmpty {
            if shouldShowValidationErrors {
                return "Department name is required"
            }
            return nil
        }
        
        // Check for duplicate department names within the same phase (case-insensitive) - show in real-time
        let duplicateCount = phase.departments.filter { dept in
            dept.id != departmentId && // Exclude current department
            dept.name.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }.count
        
        if duplicateCount > 0 {
            let phaseName = phase.phaseName.trimmingCharacters(in: .whitespaces)
            return "\"\(trimmedName)\" already exists in \"\(phaseName)\". Enter a unique department name."
        }
        
        return nil
    }
    
    func phaseDepartmentsError(for phaseId: UUID) -> String? {
        guard shouldShowValidationErrors else { return nil }
        guard let phase = phases.first(where: { $0.id == phaseId }) else { return nil }
        if phase.departments.isEmpty || phase.departments.allSatisfy({ $0.name.trimmingCharacters(in: .whitespaces).isEmpty }) {
            return "At least one department with a name is required"
        }
        return nil
    }
    
    // MARK: - Find First Invalid Field
    
    func findFirstInvalidFieldId() -> String? {
        // Check project name
        if projectName.trimmingCharacters(in: .whitespaces).isEmpty {
            return "projectName"
        }
        // Check if project name already exists
        if projectNameExists {
            return "projectName"
        }
        
        // Check client
        if client.trimmingCharacters(in: .whitespaces).isEmpty {
            return "client"
        }
        
        // Check location
        if location.trimmingCharacters(in: .whitespaces).isEmpty {
            return "location"
        }
        
        // Check planned date (always has a value from DatePicker, but we can add validation if needed)
        
        // Check description
        if projectDescription.trimmingCharacters(in: .whitespaces).isEmpty {
            return "projectDescription"
        }
        
        // Check project manager
        if selectedProjectManager == nil {
            return "projectManagers"
        }
        
        // Check team members
        if selectedProjectTeamMembers.isEmpty {
            return "projectTeamMembers"
        }
        
        // Check phases
        for phase in phases {
            let trimmedName = phase.phaseName.trimmingCharacters(in: .whitespaces)
            
            if trimmedName.isEmpty {
                return "phase_\(phase.id)_name"
            }
            
            // Check for duplicate phase names (case-insensitive)
            let duplicateCount = phases.filter { phaseItem in
                phaseItem.id != phase.id && // Exclude current phase
                phaseItem.phaseName.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
            }.count
            
            if duplicateCount > 0 {
                return "phase_\(phase.id)_name"
            }
            
            // Check if phase start date is before planned start date
            let calendar = Calendar.current
            let plannedStart = calendar.startOfDay(for: plannedDate)
            let phaseStart = calendar.startOfDay(for: phase.startDate)
            if phaseStart < plannedStart {
                return "phase_\(phase.id)_dates"
            }
            
            if phase.endDate <= phase.startDate {
                return "phase_\(phase.id)_dates"
            }
            
            if phase.departments.isEmpty || phase.departments.allSatisfy({ $0.name.trimmingCharacters(in: .whitespaces).isEmpty }) {
                return "phase_\(phase.id)_departments"
            }
            
            // Check for empty department names and duplicate department names
            for department in phase.departments {
                let trimmedName = department.name.trimmingCharacters(in: .whitespaces)
                
                if trimmedName.isEmpty {
                    return "phase_\(phase.id)_dept_\(department.id)_name"
                }
                
                // Check for duplicate department names within the same phase (case-insensitive)
                let duplicateCount = phase.departments.filter { dept in
                    dept.id != department.id && // Exclude current department
                    dept.name.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
                }.count
                
                if duplicateCount > 0 {
                    return "phase_\(phase.id)_dept_\(department.id)_name"
                }
            }
        }
        
        // Check phase timeline
        for i in 0..<phases.count - 1 {
            let currentPhase = phases[i]
            let nextPhase = phases[i + 1]
            if nextPhase.startDate <= currentPhase.endDate {
                return "phase_\(nextPhase.id)_timeline"
            }
        }
        
        return nil
    }
    
    // MARK: - Project Name Duplicate Check
    
    /// Check if a project name already exists in Firestore
    /// - Parameter name: The project name to check
    /// - Returns: True if a project with this name exists (excluding the current project being edited)
    func checkProjectNameExists(_ name: String) async -> Bool {
        // Don't check if name is empty or just whitespace
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            await MainActor.run {
                projectNameExists = false
                isCheckingProjectName = false
            }
            return false
        }
        
        guard let customerId = authService?.currentCustomerId else {
            await MainActor.run {
                projectNameExists = false
                isCheckingProjectName = false
            }
            return false
        }
        
        await MainActor.run {
            isCheckingProjectName = true
        }
        
        do {
            // Query all projects for this customer (we'll filter case-insensitively in memory)
            let querySnapshot = try await FirebasePathHelper.shared
                .projectsCollection(customerId: customerId)
                .getDocuments()
            
            // Filter for projects with the same name (case-insensitive) and exclude current project if editing
            let existingProjects = querySnapshot.documents.filter { doc in
                // Exclude current project if editing
                if let editingId = editingProjectId, doc.documentID == editingId {
                    return false
                }
                
                // Case-insensitive name comparison
                if let projectData = try? doc.data(as: Project.self) {
                    return projectData.name.trimmingCharacters(in: .whitespaces)
                        .localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
                }
                return false
            }
            
            let exists = !existingProjects.isEmpty
            
            await MainActor.run {
                projectNameExists = exists
                isCheckingProjectName = false
            }
            
            return exists
        } catch {
            print("Error checking project name: \(error.localizedDescription)")
            await MainActor.run {
                projectNameExists = false
                isCheckingProjectName = false
            }
            return false
        }
    }
    
    // Debounced check task
    private var nameCheckTask: Task<Void, Never>?
    
    /// Debounced check for project name duplicates
    func debouncedCheckProjectName() {
        // Cancel previous task
        nameCheckTask?.cancel()
        
        // Reset state immediately
        projectNameExists = false
        
        let nameToCheck = projectName
        
        // Create new task with debounce delay
        nameCheckTask = Task {
            // Wait 500ms before checking
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Check if task was cancelled or name changed
            guard !Task.isCancelled, nameToCheck == projectName else {
                return
            }
            
            // Perform the check
            await checkProjectNameExists(nameToCheck)
        }
    }
    
    func validateAndFindFirstInvalidField() -> String? {
        shouldShowValidationErrors = true
        let fieldId = findFirstInvalidFieldId()
        if let fieldId = fieldId {
            print("🔍 First invalid field found: \(fieldId)")
        } else {
            print("✅ All fields are valid")
        }
        return fieldId
    }
    
    // MARK: - Initialization
    init(authService: FirebaseAuthService? = nil) {
        self.authService = authService
        loadFormState()
        setupAutoSave()
        Task {
            await fetchUsers()
            // Restore team selections after users are loaded
            restoreTeamSelections()
        }
    }
    
    // MARK: - Data Fetching using AuthService
    func fetchUsers() async {
        isLoading = true
        errorMessage = nil
        
        guard let customerId = authService?.currentCustomerId else {
            errorMessage = "Customer ID not found"
            isLoading = false
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
    
    // MARK: - Load Project for Editing
    func loadProjectForEditing(_ project: Project) async {
        guard let projectId = project.id,
              let customerId = authService?.currentCustomerId else {
            return
        }
        
        isLoading = true
        
        do {
            // Set edit mode
            isEditingMode = true
            editingProjectId = projectId
            
            // Reset duplicate check state
            projectNameExists = false
            isCheckingProjectName = false
            
            // Load project basic info
            projectName = project.name
            projectDescription = project.description
            client = project.client
            location = project.location
            currency = project.currency
            
            // Parse planned date
            if let plannedDateStr = project.plannedDate {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                if let date = dateFormatter.date(from: plannedDateStr) {
                    plannedDate = date
                }
            }
            
            allowTemplateOverrides = project.Allow_Template_Overrides ?? false
            
            // Load phases
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .order(by: "phaseNumber")
                .getDocuments()
            
            var loadedPhases: [PhaseItem] = []
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            
            for doc in phasesSnapshot.documents {
                let phaseId = doc.documentID
                guard let phase = try? doc.data(as: Phase.self) else {
                    continue
                }
                
                var phaseItem = PhaseItem(phaseNumber: phase.phaseNumber)
                phaseItem.phaseName = phase.phaseName
                
                // Parse dates
                if let startDateStr = phase.startDate,
                   let startDate = dateFormatter.date(from: startDateStr) {
                    phaseItem.startDate = startDate
                    phaseItem.hasStartDate = true
                }
                if let endDateStr = phase.endDate,
                   let endDate = dateFormatter.date(from: endDateStr) {
                    phaseItem.endDate = endDate
                    phaseItem.hasEndDate = true
                }
                
                // Load departments from departments subcollection
                var departments: [DepartmentItem] = []
                do {
                    let departmentsSnapshot = try await FirebasePathHelper.shared
                        .departmentsCollection(customerId: customerId, projectId: projectId, phaseId: phaseId)
                        .getDocuments()
                    
                    for deptDoc in departmentsSnapshot.documents {
                        if let department = try? deptDoc.data(as: Department.self) {
                            // Convert DepartmentLineItemData back to DepartmentLineItem
                            let lineItems = department.lineItems.map { lineItemData in
                                var lineItem = DepartmentLineItem()
                                lineItem.itemType = lineItemData.itemType
                                lineItem.item = lineItemData.item
                                lineItem.spec = lineItemData.spec
                                lineItem.quantity = formatIndianNumber(lineItemData.quantity)
                                lineItem.unitPrice = formatIndianNumber(lineItemData.unitPrice)
                                return lineItem
                            }
                            
                            // Convert ContractorMode string back to enum
                            let contractorMode = ContractorMode(rawValue: department.contractorMode) ?? .labourOnly
                            
                            departments.append(DepartmentItem(
                                id: UUID(),
                                name: department.name,
                                amount: formatIndianNumber(department.totalBudget),
                                contractorMode: contractorMode,
                                lineItems: lineItems.isEmpty ? [DepartmentLineItem()] : lineItems
                            ))
                        }
                    }
                } catch {
                    print("⚠️ Error loading departments for phase \(phaseId): \(error.localizedDescription)")
                    // Fallback to loading from phase.departments dictionary (backward compatibility)
                    for (deptKey, amount) in phase.departments {
                        let deptName: String
                        if let underscoreIndex = deptKey.firstIndex(of: "_") {
                            deptName = String(deptKey[deptKey.index(after: underscoreIndex)...])
                        } else {
                            deptName = deptKey
                        }
                        departments.append(DepartmentItem(
                            id: UUID(),
                            name: deptName,
                            amount: formatIndianNumber(amount)
                        ))
                    }
                }
                
                phaseItem.departments = departments.isEmpty ? [DepartmentItem()] : departments
                phaseItem.categories = phase.categories
                
                loadedPhases.append(phaseItem)
            }
            
            phases = loadedPhases.isEmpty ? [PhaseItem(phaseNumber: 1)] : loadedPhases
            
            // Load team members and manager (need to fetch users first)
            await fetchUsers()
            
            // Set manager
            if let managerId = project.managerIds.first {
                selectedProjectManager = allApprovers.first { approver in
                    approver.phoneNumber == managerId || approver.email == managerId
                }
            }
            
            // Set team members
            selectedProjectTeamMembers = Set(allUsers.filter { user in
                project.teamMembers.contains(user.phoneNumber)
            })
            
            isLoading = false
        } catch {
            print("Error loading project for editing: \(error)")
            errorMessage = "Failed to load project: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Phase Management
    func addPhase() {
        let nextPhaseNumber = phases.count + 1
        var newPhase = PhaseItem(phaseNumber: nextPhaseNumber)
        
        let calendar = Calendar.current
        let plannedStart = calendar.startOfDay(for: plannedDate)
        
        // If previous phase exists, set start date to day after its end date
        if let lastPhase = phases.last {
            let dayAfterLastPhase = calendar.date(byAdding: .day, value: 1, to: lastPhase.endDate) ?? Date()
            let dayAfterLastPhaseStart = calendar.startOfDay(for: dayAfterLastPhase)
            // Use the later of: day after last phase end date, or planned start date
            newPhase.startDate = max(dayAfterLastPhaseStart, plannedStart)
            newPhase.endDate = calendar.date(byAdding: .day, value: 31, to: newPhase.startDate) ?? Date().addingTimeInterval(86400 * 30)
        } else {
            // First phase: start date should be at least planned start date
            newPhase.startDate = plannedStart
            newPhase.endDate = calendar.date(byAdding: .day, value: 31, to: newPhase.startDate) ?? Date().addingTimeInterval(86400 * 30)
        }
        
        // Dates are now always required
        newPhase.hasStartDate = true
        newPhase.hasEndDate = true
        
        phases.append(newPhase)
    }
    
    func removePhase(at index: Int) {
        guard index < phases.count else { return }
        
        // Remove the phase
        phases.remove(at: index)
        
        // Renumber remaining phases
        for i in 0..<phases.count {
            phases[i].phaseNumber = i + 1
        }
    }

    func removePhaseById(_ phaseId: UUID) {
        // Find and remove the phase
        phases.removeAll(where: { $0.id == phaseId })
        
        // Renumber remaining phases
        for i in 0..<phases.count {
            phases[i].phaseNumber = i + 1
        }
    }

    // REMOVE the IndexSet version completely or update it:
    func removePhase(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        removePhase(at: index)
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
    
    func removeDepartmentById(from phaseId: UUID, departmentId: UUID) {
        if let phaseIndex = phases.firstIndex(where: { $0.id == phaseId }),
           let departmentIndex = phases[phaseIndex].departments.firstIndex(where: { $0.id == departmentId }) {
            phases[phaseIndex].departments.remove(at: departmentIndex)
        }
    }

    // MARK: - Helper to Calculate Handover Date
    private func calculateHandoverDate() -> String? {
        guard !phases.isEmpty else { return nil }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        // Find the highest end date among all phases
        let highestEndDate = phases.map { $0.endDate }.max()
        
        guard let highestDate = highestEndDate else { return nil }
        
        return dateFormatter.string(from: highestDate)
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
                    total + phase.departments.compactMap { Double(removeFormatting(from: $0.amount)) }.reduce(0, +)
                }
                
                // Calculate handover date (highest end date among all phases)
                let handoverDateStr = calculateHandoverDate()
                
                // Format planned date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                let plannedDateStr = dateFormatter.string(from: plannedDate)
                
                // Calculate default maintenance date (1 month from handover date)
                let maintenanceDateStr: String?
                if let handoverDateStr = handoverDateStr,
                   let handoverDate = dateFormatter.date(from: handoverDateStr) {
                    let calendar = Calendar.current
                    let defaultMaintenanceDate = calendar.date(byAdding: .month, value: 1, to: handoverDate) ?? handoverDate
                    maintenanceDateStr = dateFormatter.string(from: defaultMaintenanceDate)
                } else {
                    maintenanceDateStr = nil
                }
                
                // Get customer ID from auth service
                guard let customerId = authService?.currentCustomerId else {
                    throw NSError(domain: "CreateProjectError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Customer ID not found. Please log in again."])
                }
                
                // Project-level team members and manager
                // Note: Backend stores managerIds as array, but UI only allows single selection
                let allTeamMembers = Set(selectedProjectTeamMembers.map { $0.phoneNumber })
                let managerId = selectedProjectManager?.email ?? selectedProjectManager?.phoneNumber ?? ""
                let managerIds = managerId.isEmpty ? [] : [managerId] // Store as array for backend compatibility
                
                // Get project document reference
                let docRef: DocumentReference
                if isEditingMode, let projectId = editingProjectId {
                    // Editing existing project
                    docRef = FirebasePathHelper.shared.projectDocument(customerId: customerId, projectId: projectId)
                    
                    // Update project data
                    var updateData: [String: Any] = [
                        "name": projectName,
                        "description": projectDescription,
                        "client": client,
                        "location": location,
                        "currency": currency,
                        "budget": totalBudget,
                        "status": ProjectStatus.IN_REVIEW.rawValue, // Reset to IN_REVIEW when resubmitting
                        "plannedDate": plannedDateStr,
                        "teamMembers": Array(allTeamMembers),
                        "managerIds": managerIds,
                        "Allow_Template_Overrides": allowTemplateOverrides,
                        "updatedAt": Timestamp()
                    ]
                    
                    // Add handoverDate and initialHandOverDate if calculated
                    if let handoverDateStr = handoverDateStr {
                        updateData["handoverDate"] = handoverDateStr
                        updateData["initialHandOverDate"] = handoverDateStr // Set initial same as handover on edit
                    }
                    
                    // Add maintenanceDate if calculated
                    if let maintenanceDateStr = maintenanceDateStr {
                        updateData["maintenanceDate"] = maintenanceDateStr
                    }
                    
                    try await docRef.updateData(updateData)
                    
                    // Delete existing phases and create new ones
                    let existingPhasesSnapshot = try await docRef.collection("phases").getDocuments()
                    for phaseDoc in existingPhasesSnapshot.documents {
                        try await phaseDoc.reference.delete()
                    }
                } else {
                    // Creating new project
                    docRef = FirebasePathHelper.shared.projectsCollection(customerId: customerId).document()
                    
                    // Set status to IN_REVIEW - project needs approver approval before becoming active
                    let initialStatus = ProjectStatus.IN_REVIEW.rawValue
                    
                    let projectData = Project(
                        id: docRef.documentID,
                        name: projectName,
                        description: projectDescription,
                        client: client,
                        location: location,
                        currency: currency,
                        budget: totalBudget,
                        estimatedBudget: totalBudget, // Set estimated budget to total budget on creation (constant)
                        status: initialStatus,
                        startDate: nil, // Removed from main project
                        endDate: nil, // Removed from main project
                        plannedDate: plannedDateStr,
                        handoverDate: handoverDateStr, // Highest end date among all phases
                        initialHandOverDate: handoverDateStr, // Same as handoverDate on creation
                        maintenanceDate: maintenanceDateStr, // Default: 1 month from handover date
                        isSuspended: nil, // New projects are not suspended
                        suspendedDate: nil, // No suspension date for new projects
                        suspensionReason: nil, // No suspension reason for new projects
                        rejectionReason: nil, // No rejection reason for new projects
                        rejectedBy: nil, // No rejector for new projects
                        rejectedAt: nil, // No rejection timestamp for new projects
                        teamMembers: Array(allTeamMembers),
                        managerIds: managerIds,
                        tempApproverID: nil,
                        Allow_Template_Overrides: allowTemplateOverrides,
                        createdAt: Timestamp(),
                        updatedAt: Timestamp()
                    )
                    
                    // Save project
                    try await docRef.setData(from: projectData)
                }
                
                // Save phases in subcollection
                for phase in phases {
                    let phaseRef = docRef.collection("phases").document()
                    let phaseId = phaseRef.documentID
                    
                    // Format dates (dates are now always required)
                    let startDateStr = dateFormatter.string(from: phase.startDate)
                    let endDateStr = dateFormatter.string(from: phase.endDate)
                    
                    // Create phase with empty departments dictionary (departments are stored in subcollection)
                    let phaseData = Phase(
                        id: phaseId,
                        phaseName: phase.phaseName,
                        phaseNumber: phase.phaseNumber,
                        startDate: startDateStr,
                        endDate: endDateStr,
                        departments: [:], // Empty dictionary - departments are stored in subcollection
                        categories: phase.categories,
                        isEnabled: true,
                        createdAt: Timestamp(),
                        updatedAt: Timestamp()
                    )
                    
                    try await phaseRef.setData(from: phaseData)
                    
                    // Save departments separately in departments subcollection
                    for dept in phase.departments {
                        guard !dept.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                        
                        let deptRef = phaseRef.collection("departments").document()
                        
                        // Convert DepartmentLineItem to DepartmentLineItemData
                        let lineItemsData = dept.lineItems.map { lineItem in
                            DepartmentLineItemData(
                                itemType: lineItem.itemType,
                                item: lineItem.item,
                                spec: lineItem.spec,
                                quantity: Double(lineItem.quantity.replacingOccurrences(of: ",", with: "")) ?? 0,
                                unitPrice: Double(lineItem.unitPrice.replacingOccurrences(of: ",", with: "")) ?? 0
                            )
                        }
                        
                        let departmentData = Department(
                            id: deptRef.documentID,
                            name: dept.name.trimmingCharacters(in: .whitespacesAndNewlines),
                            contractorMode: dept.contractorMode.rawValue,
                            lineItems: lineItemsData,
                            phaseId: phaseId,
                            projectId: docRef.documentID,
                            createdAt: Timestamp(),
                            updatedAt: Timestamp()
                        )
                        
                        try await deptRef.setData(from: departmentData)
                    }
                }
                
                // Delete draft from draft_projects collection if one was loaded
                if let draftId = currentDraftId, !draftId.isEmpty {
                    do {
                        let draftRef = db.collection("customers")
                            .document(customerId)
                            .collection("draft_projects")
                            .document(draftId)
                        
                        // Verify document exists before deleting
                        let draftDoc = try await draftRef.getDocument()
                        if draftDoc.exists {
                            try await draftRef.delete()
                            
                            // Update customer document if no drafts remain
                            let remainingDrafts = try await db.collection("customers")
                                .document(customerId)
                                .collection("draft_projects")
                                .getDocuments()
                            
                            if remainingDrafts.documents.isEmpty {
                                let customerRef = db.collection("customers").document(customerId)
                                try await customerRef.updateData([
                                    "hasDrafts": false
                                ])
                            }
                            
                            // Refresh drafts list
                            await loadDrafts()
                        }
                    } catch {
                        // Log error but don't fail the project creation
                        print("⚠️ Failed to delete draft after project creation: \(error.localizedDescription)")
                    }
                }
                
                // Clear current draft ID
                currentDraftId = nil
                
                // Show success message
                isLoading = false
                showSuccessMessage = true
                if isEditingMode {
                    alertMessage = "Project updated successfully! The project is now IN REVIEW and will be sent to the approver for approval."
                } else {
                    alertMessage = "Project created successfully! The project is now IN REVIEW and will be sent to the approver for approval."
                }
                showAlert = true
                
                // Clear saved form state before resetting
                clearFormState()
                resetForm()
                
                // Reset edit mode
                isEditingMode = false
                editingProjectId = nil
                
                // Notify that project was created/updated
                NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
                
            } catch {
                isLoading = false
                errorMessage = "Failed to create project: \(error.localizedDescription)"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
    
    // MARK: - Set AuthService
    func setAuthService(_ authService: FirebaseAuthService) {
        self.authService = authService
        Task {
            await fetchUsers() // Refresh users with new auth service
            // Restore team selections after users are loaded
            restoreTeamSelections()
        }
    }
    
    // MARK: - File Upload
    func uploadAttachment(_ url: URL) {
        isUploading = true
        uploadProgress = 0.0
        
        // Get file name and extension
        let fileName = url.lastPathComponent
        attachmentName = fileName
        
        // Create unique file path
        guard let customerId = authService?.currentCustomerId else {
            isUploading = false
            alertMessage = "Customer ID not found. Please log in again."
            showAlert = true
            return
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let storageRef = storage.reference()
            .child("customers")
            .child(customerId)
            .child("projects")
            .child("drafts")
            .child("\(timestamp)_\(fileName)")
        
        // Process and compress file before upload
        Task {
            do {
                // Handle security-scoped resources properly
                let accessibleURL = try await getAccessibleFileURL(from: url)
                let (compressedData, contentType) = try await compressFile(at: accessibleURL)
                
                // Create metadata with content type
                let metadata = StorageMetadata()
                metadata.contentType = contentType
                
                // Upload compressed file
                let uploadTask = storageRef.putData(compressedData, metadata: metadata) { [weak self] metadata, error in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        self.isUploading = false
                        
                        if let error = error {
                            self.alertMessage = "Upload failed: \(error.localizedDescription)"
                            self.showAlert = true
                            return
                        }
                        
                        // Get download URL
                        storageRef.downloadURL { url, error in
                            if let error = error {
                                self.alertMessage = "Failed to get download URL: \(error.localizedDescription)"
                                self.showAlert = true
                                return
                            }
                            
                            if let downloadURL = url {
                                self.attachmentURL = downloadURL.absoluteString
                                self.alertMessage = "File uploaded successfully!"
                                self.showAlert = true
                            }
                        }
                    }
                }
                
                // Observe upload progress
                uploadTask.observe(.progress) { [weak self] snapshot in
                    guard let progress = snapshot.progress else { return }
                    
                    DispatchQueue.main.async {
                        self?.uploadProgress = Double(progress.fractionCompleted)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isUploading = false
                    self.alertMessage = "Failed to process file: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
    
    // MARK: - Handle Security-Scoped Resources
    private func getAccessibleFileURL(from url: URL) async throws -> URL {
        // Check if URL is a security-scoped resource
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Copy file to temporary directory for processing
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileName = "\(UUID().uuidString)_\(url.lastPathComponent)"
        let tempFileURL = tempDir.appendingPathComponent(tempFileName)
        
        // Remove file if it already exists
        if FileManager.default.fileExists(atPath: tempFileURL.path) {
            try FileManager.default.removeItem(at: tempFileURL)
        }
        
        // Copy file to temporary location
        try FileManager.default.copyItem(at: url, to: tempFileURL)
        
        return tempFileURL
    }
    
    // MARK: - Upload Image
    func uploadImage(_ image: UIImage) {
        isUploading = true
        uploadProgress = 0.0
        
        // Generate file name
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "project_\(timestamp).jpg"
        attachmentName = fileName
        
        // Create unique file path
        guard let customerId = authService?.currentCustomerId else {
            isUploading = false
            alertMessage = "Customer ID not found. Please log in again."
            showAlert = true
            return
        }
        
        let storageRef = storage.reference()
            .child("customers")
            .child(customerId)
            .child("projects")
            .child("drafts")
            .child(fileName)
        
        // Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            isUploading = false
            alertMessage = "Failed to process image"
            showAlert = true
            return
        }
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload image
        let uploadTask = storageRef.putData(imageData, metadata: metadata) { [weak self] metadata, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isUploading = false
                
                if let error = error {
                    self.alertMessage = "Upload failed: \(error.localizedDescription)"
                    self.showAlert = true
                    return
                }
                
                // Get download URL
                storageRef.downloadURL { url, error in
                    if let error = error {
                        self.alertMessage = "Failed to get download URL: \(error.localizedDescription)"
                        self.showAlert = true
                        return
                    }
                    
                    if let downloadURL = url {
                        self.attachmentURL = downloadURL.absoluteString
                        self.alertMessage = "Image uploaded successfully!"
                        self.showAlert = true
                    }
                }
            }
        }
        
        // Observe upload progress
        uploadTask.observe(.progress) { [weak self] snapshot in
            guard let progress = snapshot.progress else { return }
            
            DispatchQueue.main.async {
                self?.uploadProgress = Double(progress.fractionCompleted)
            }
        }
    }
    
    // MARK: - File Compression
    private func compressFile(at url: URL) async throws -> (Data, String) {
        let fileExtension = url.pathExtension.lowercased()
        let fileData = try Data(contentsOf: url)
        
        // Determine content type
        let contentType: String
        let compressedData: Data
        
        switch fileExtension {
        case "jpg", "jpeg":
            // Compress JPEG images
            if let image = UIImage(data: fileData) {
                // Use 0.7 quality for good compression while maintaining quality
                if let jpegData = image.jpegData(compressionQuality: 0.7) {
                    compressedData = jpegData
                    contentType = "image/jpeg"
                } else {
                    compressedData = fileData
                    contentType = "image/jpeg"
                }
            } else {
                compressedData = fileData
                contentType = "image/jpeg"
            }
            
        case "png":
            // Compress PNG images by converting to JPEG if possible
            if let image = UIImage(data: fileData) {
                // Convert PNG to JPEG for better compression
                if let jpegData = image.jpegData(compressionQuality: 0.75) {
                    compressedData = jpegData
                    contentType = "image/jpeg"
                } else {
                    // If conversion fails, use original PNG
                    compressedData = fileData
                    contentType = "image/png"
                }
            } else {
                compressedData = fileData
                contentType = "image/png"
            }
            
        case "pdf":
            // For PDFs, we can't easily compress them without external libraries
            // But we can check if the file is already reasonably sized
            if fileData.count > 5 * 1024 * 1024 {
                // For very large PDFs, we could add PDF compression here if needed
                // For now, we'll use the original file
                compressedData = fileData
            } else {
                compressedData = fileData
            }
            contentType = "application/pdf"
            
        default:
            // For other file types, use as-is
            compressedData = fileData
            contentType = "application/octet-stream"
        }
        
        return (compressedData, contentType)
    }
    
    func removeAttachment() {
        // If there's an existing attachment URL, optionally delete it from storage
        if let urlString = attachmentURL,
           let url = URL(string: urlString) {
            let storageRef = Storage.storage().reference(forURL: urlString)
            storageRef.delete { [weak self] error in
                if let error = error {
                    print("Failed to delete file: \(error.localizedDescription)")
                }
            }
        }
        
        attachmentURL = nil
        attachmentName = nil
    }
    
    // MARK: - Document Picker Support
    func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            uploadAttachment(url)
            
        case .failure(let error):
            alertMessage = "Failed to select file: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    func handleImageSelection(_ image: UIImage?) {
        guard let image = image else { return }
        uploadImage(image)
    }
    
    // MARK: - Form State Persistence
    
    private func setupAutoSave() {
        // Debounce saves to avoid excessive writes
        Publishers.CombineLatest4(
            $projectName,
            $projectDescription,
            $phases,
            $plannedDate
        )
        .debounce(for: .seconds(1), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.saveFormState(expandedPhaseIds: self?.restoredExpandedPhaseIds ?? [])
        }
        .store(in: &saveCancellables)
        
        // Also save on other field changes
        Publishers.CombineLatest4(
            $client,
            $location,
            $currency,
            $allowTemplateOverrides
        )
        .debounce(for: .seconds(1), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.saveFormState(expandedPhaseIds: self?.restoredExpandedPhaseIds ?? [])
        }
        .store(in: &saveCancellables)
        
        // Save when team selections change
        $selectedProjectManager
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveFormState(expandedPhaseIds: self?.restoredExpandedPhaseIds ?? [])
            }
            .store(in: &saveCancellables)
        
        $selectedProjectTeamMembers
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveFormState(expandedPhaseIds: self?.restoredExpandedPhaseIds ?? [])
            }
            .store(in: &saveCancellables)
        
        // Save attachment info
        Publishers.CombineLatest(
            $attachmentURL,
            $attachmentName
        )
        .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.saveFormState(expandedPhaseIds: self?.restoredExpandedPhaseIds ?? [])
        }
        .store(in: &saveCancellables)
    }
    
    func saveFormState(expandedPhaseIds: Set<UUID>? = nil) {
        // Create form state with current values
        // Note: We save manager/team member IDs, not full User objects
        let managerId = selectedProjectManager?.email ?? selectedProjectManager?.phoneNumber
        let teamMemberIds = selectedProjectTeamMembers.map { $0.phoneNumber }
        
        // Update phases with manager/team IDs before saving
        var phasesToSave = phases
        for i in 0..<phasesToSave.count {
            phasesToSave[i].selectedManagerId = phasesToSave[i].selectedManager?.email ?? phasesToSave[i].selectedManager?.phoneNumber
            phasesToSave[i].selectedTeamMemberIds = Array(phasesToSave[i].selectedTeamMembers).map { $0.phoneNumber }
        }
        
        // Use provided expandedPhaseIds or fall back to restoredExpandedPhaseIds
        let phaseIdsToSave = expandedPhaseIds ?? restoredExpandedPhaseIds
        
        // Update restoredExpandedPhaseIds if new IDs were provided
        if let newPhaseIds = expandedPhaseIds {
            restoredExpandedPhaseIds = newPhaseIds
        }
        
        let formState = CreateProjectFormState(
            projectName: projectName,
            projectDescription: projectDescription,
            client: client,
            location: location,
            plannedDate: plannedDate,
            currency: currency,
            allowTemplateOverrides: allowTemplateOverrides,
            phases: phasesToSave,
            selectedProjectManagerId: managerId,
            selectedProjectTeamMemberIds: teamMemberIds,
            attachmentURL: attachmentURL,
            attachmentName: attachmentName,
            expandedPhaseIds: phaseIdsToSave.map { $0.uuidString }
        )
        
        // Encode and save to UserDefaults
        if let encoded = try? JSONEncoder().encode(formState) {
            UserDefaults.standard.set(encoded, forKey: formStateKey)
        }
    }
    
    private func loadFormState() {
        guard let data = UserDefaults.standard.data(forKey: formStateKey),
              let formState = try? JSONDecoder().decode(CreateProjectFormState.self, from: data) else {
            // No saved state, use defaults
            return
        }
        
        // Restore form fields
        projectName = formState.projectName
        projectDescription = formState.projectDescription
        client = formState.client
        location = formState.location
        plannedDate = formState.plannedDate
        currency = formState.currency
        allowTemplateOverrides = formState.allowTemplateOverrides
        phases = formState.phases
        attachmentURL = formState.attachmentURL
        attachmentName = formState.attachmentName
        
        // Restore expanded phase IDs
        restoredExpandedPhaseIds = Set(formState.expandedPhaseIds.compactMap { UUID(uuidString: $0) })
        
        // Note: Manager and team members will be restored after users are loaded
        // Store IDs for later restoration
        if let managerId = formState.selectedProjectManagerId {
            // Will be restored in restoreTeamSelections after users load
            _restoreManagerId = managerId
        }
        _restoreTeamMemberIds = formState.selectedProjectTeamMemberIds
    }
    
    // Temporary storage for restoration after users load
    private var _restoreManagerId: String?
    private var _restoreTeamMemberIds: [String] = []
    @Published var restoredExpandedPhaseIds: Set<UUID> = []
    
    func restoreTeamSelections() {
        // Restore project manager
        if let managerId = _restoreManagerId {
            if let manager = allApprovers.first(where: { $0.email == managerId || $0.phoneNumber == managerId }) {
                selectedProjectManager = manager
            }
            _restoreManagerId = nil
        }
        
        // Restore team members
        if !_restoreTeamMemberIds.isEmpty {
            let restoredMembers = allUsers.filter { user in
                _restoreTeamMemberIds.contains(user.phoneNumber)
            }
            selectedProjectTeamMembers = Set(restoredMembers)
            _restoreTeamMemberIds = []
        }
        
        // Restore phase-level selections
        for i in 0..<phases.count {
            let phase = phases[i]
            if let managerId = phase.selectedManagerId {
                if let manager = allApprovers.first(where: { $0.email == managerId || $0.phoneNumber == managerId }) {
                    phases[i].selectedManager = manager
                }
            }
            
            if !phase.selectedTeamMemberIds.isEmpty {
                let restoredMembers = allUsers.filter { user in
                    phase.selectedTeamMemberIds.contains(user.phoneNumber)
                }
                phases[i].selectedTeamMembers = Set(restoredMembers)
            }
        }
    }
    
    func clearFormState() {
        UserDefaults.standard.removeObject(forKey: formStateKey)
        _restoreManagerId = nil
        _restoreTeamMemberIds = []
    }
    
    // Check if there's saved data in local storage
    var hasSavedLocalData: Bool {
        UserDefaults.standard.data(forKey: formStateKey) != nil
    }
    
    // MARK: - Reset Form
    private func resetForm() {
        projectName = ""
        projectDescription = ""
        client = ""
        location = ""
        plannedDate = Date()
        currency = "INR"
        selectedProjectManager = nil
        selectedProjectTeamMembers = []
        projectManagerSearchText = ""
        projectTeamMemberSearchText = ""
        var initialPhase = PhaseItem(phaseNumber: 1)
        initialPhase.hasStartDate = true
        initialPhase.hasEndDate = true
        phases = [initialPhase]
        allowTemplateOverrides = false
        showSuccessMessage = false
        errorMessage = nil
        shouldShowValidationErrors = false
        firstInvalidFieldId = nil
        attachmentURL = nil
        attachmentName = nil
        uploadProgress = 0.0
        
        // Clear saved form state
        clearFormState()
    }
    
    // MARK: - Draft Management
    
    func saveDraft() {
        Task {
            guard hasAnyData else {
                alertMessage = "Please fill in at least one field before saving a draft"
                showAlert = true
                return
            }
            
            guard let customerId = authService?.currentCustomerId else {
                alertMessage = "Customer ID not found. Please log in again."
                showAlert = true
                return
            }
            
            isSavingDraft = true
            
            do {
                // Prepare form state for saving
                let managerId = selectedProjectManager?.email ?? selectedProjectManager?.phoneNumber
                let teamMemberIds = selectedProjectTeamMembers.map { $0.phoneNumber }
                
                // Update phases with manager/team IDs before saving
                var phasesToSave = phases
                for i in 0..<phasesToSave.count {
                    phasesToSave[i].selectedManagerId = phasesToSave[i].selectedManager?.email ?? phasesToSave[i].selectedManager?.phoneNumber
                    phasesToSave[i].selectedTeamMemberIds = Array(phasesToSave[i].selectedTeamMembers).map { $0.phoneNumber }
                }
                
                let formState = CreateProjectFormState(
                    projectName: projectName,
                    projectDescription: projectDescription,
                    client: client,
                    location: location,
                    plannedDate: plannedDate,
                    currency: currency,
                    allowTemplateOverrides: allowTemplateOverrides,
                    phases: phasesToSave,
                    selectedProjectManagerId: managerId,
                    selectedProjectTeamMemberIds: teamMemberIds,
                    attachmentURL: attachmentURL,
                    attachmentName: attachmentName,
                    expandedPhaseIds: restoredExpandedPhaseIds.map { $0.uuidString }
                )
                
                var draft = DraftProject(formState: formState)
                draft.updatedAt = Timestamp() // Update timestamp
                
                // Save to draft_projects collection - update existing draft if one is loaded, otherwise create new
                let draftRef: DocumentReference
                if let existingDraftId = currentDraftId, !existingDraftId.isEmpty {
                    // Update existing draft
                    draftRef = db.collection("customers")
                        .document(customerId)
                        .collection("draft_projects")
                        .document(existingDraftId)
                    // Preserve the original createdAt timestamp
                    let existingDraftDoc = try await draftRef.getDocument()
                    if let existingData = existingDraftDoc.data(),
                       let existingCreatedAt = existingData["createdAt"] as? Timestamp {
                        draft.createdAt = existingCreatedAt
                    }
                } else {
                    // Create new draft
                    draftRef = db.collection("customers")
                        .document(customerId)
                        .collection("draft_projects")
                        .document()
                    // Set the current draft ID so future saves will update this draft
                    currentDraftId = draftRef.documentID
                }
                
                try await draftRef.setData(from: draft)
                
                // Update customer document with draft info (optional metadata)
                let customerRef = db.collection("customers").document(customerId)
                try await customerRef.updateData([
                    "lastDraftUpdatedAt": Timestamp(),
                    "hasDrafts": true
                ])
                
                isSavingDraft = false
                alertMessage = "Draft saved successfully!"
                showAlert = true
                
                // Clear local storage and reset form
                clearFormState()
                resetFormAfterDraftSave()
                
                // Refresh drafts list
                await loadDrafts()
                
                // Note: We keep currentDraftId set so that if user continues editing and saves again,
                // it will update the same draft instead of creating a new one
                
            } catch {
                isSavingDraft = false
                alertMessage = "Failed to save draft: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    // Reset form after saving draft (keeps initial phase)
    private func resetFormAfterDraftSave() {
        projectName = ""
        projectDescription = ""
        client = ""
        location = ""
        plannedDate = Date()
        currency = "INR"
        selectedProjectManager = nil
        selectedProjectTeamMembers = []
        projectManagerSearchText = ""
        projectTeamMemberSearchText = ""
        var initialPhase = PhaseItem(phaseNumber: 1)
        initialPhase.hasStartDate = true
        initialPhase.hasEndDate = true
        phases = [initialPhase]
        allowTemplateOverrides = false
        errorMessage = nil
        shouldShowValidationErrors = false
        firstInvalidFieldId = nil
        attachmentURL = nil
        attachmentName = nil
        uploadProgress = 0.0
        restoredExpandedPhaseIds = []
        // Note: We don't clear currentDraftId here because the user might want to continue editing
        // The draft ID will be cleared when project is successfully created or when a new draft is loaded
    }
    
    func loadDrafts() async {
        guard let customerId = authService?.currentCustomerId else { return }
        
        do {
            let querySnapshot = try await db.collection("customers")
                .document(customerId)
                .collection("draft_projects")
                .order(by: "updatedAt", descending: true)
                .getDocuments()
            
            var loadedDrafts: [DraftProject] = []
            for document in querySnapshot.documents {
                do {
                    var draft = try document.data(as: DraftProject.self)
                    // Ensure document ID is set
                    draft.id = document.documentID
                    loadedDrafts.append(draft)
                } catch {
                    // Skip documents that can't be decoded
                    continue
                }
            }
            
            await MainActor.run {
                drafts = loadedDrafts
            }
        } catch {
            await MainActor.run {
                alertMessage = "Failed to load drafts: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    func loadDraft(_ draft: DraftProject) {
        let formState = draft.formState
        
        // Set the current draft ID so future saves will update this draft instead of creating a new one
        currentDraftId = draft.id
        
        // Restore form fields
        projectName = formState.projectName
        projectDescription = formState.projectDescription
        client = formState.client
        location = formState.location
        plannedDate = formState.plannedDate
        currency = formState.currency
        allowTemplateOverrides = formState.allowTemplateOverrides
        phases = formState.phases
        attachmentURL = formState.attachmentURL
        attachmentName = formState.attachmentName
        
        // Restore expanded phase IDs
        restoredExpandedPhaseIds = Set(formState.expandedPhaseIds.compactMap { UUID(uuidString: $0) })
        
        // Store IDs for restoration after users load
        _restoreManagerId = formState.selectedProjectManagerId
        _restoreTeamMemberIds = formState.selectedProjectTeamMemberIds
        
        // Restore team selections if users are already loaded
        if !allApprovers.isEmpty && !allUsers.isEmpty {
            restoreTeamSelections()
        } else {
            // Fetch users first, then restore
            Task {
                await fetchUsers()
                restoreTeamSelections()
            }
        }
        
        // Clear local form state since we're loading from draft
        clearFormState()
    }
    
    func deleteDraft(_ draft: DraftProject) {
        guard let customerId = authService?.currentCustomerId else {
            alertMessage = "Customer ID not found. Please log in again."
            showAlert = true
            return
        }
        
        guard let draftId = draft.id, !draftId.isEmpty else {
            alertMessage = "Draft ID is missing. Cannot delete."
            showAlert = true
            return
        }
        
        // Store the draft ID for restoration if deletion fails
        let draftIdToDelete = draftId
        
        // Clear currentDraftId if the deleted draft is the current one
        if currentDraftId == draftIdToDelete {
            currentDraftId = nil
        }
        
        // Optimistically remove from UI immediately with smooth animation
        withAnimation(.easeInOut(duration: 0.25)) {
            drafts.removeAll { $0.id == draftIdToDelete }
        }
        
        Task {
            do {
                let draftRef = db.collection("customers")
                    .document(customerId)
                    .collection("draft_projects")
                    .document(draftIdToDelete)
                
                // Verify document exists before deleting
                let documentSnapshot = try await draftRef.getDocument()
                
                guard documentSnapshot.exists else {
                    // Document doesn't exist, just refresh the list
                    await loadDrafts()
                    return
                }
                
                // Delete the document
                try await draftRef.delete()
                
                // Update customer document if no drafts remain
                let remainingDrafts = try await db.collection("customers")
                    .document(customerId)
                    .collection("draft_projects")
                    .getDocuments()
                
                if remainingDrafts.documents.isEmpty {
                    let customerRef = db.collection("customers").document(customerId)
                    try await customerRef.updateData([
                        "hasDrafts": false
                    ])
                }
                
                // Refresh drafts list to ensure consistency
                await loadDrafts()
                
            } catch {
                // If deletion fails, reload drafts to restore the item
                await loadDrafts()
                
                alertMessage = "Failed to delete draft: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    func clearFormAndLocalStorage() {
        // Clear all form fields
        resetFormAfterDraftSave()
        
        // Clear local storage (auto-save feature)
        clearFormState()
        
        // Show success message
        alertMessage = "Form and local storage cleared successfully"
        showAlert = true
    }
    
    func deleteAllDrafts() {
        Task {
            guard let customerId = authService?.currentCustomerId else { return }
            
            do {
                let querySnapshot = try await db.collection("customers")
                    .document(customerId)
                    .collection("draft_projects")
                    .getDocuments()
                
                // Delete all drafts in batch
                let batch = db.batch()
                for document in querySnapshot.documents {
                    batch.deleteDocument(document.reference)
                }
                
                try await batch.commit()
                
                // Update customer document
                let customerRef = db.collection("customers").document(customerId)
                try await customerRef.updateData([
                    "hasDrafts": false
                ])
                
                await loadDrafts()
                
                await MainActor.run {
                    alertMessage = "All drafts cleared successfully"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to clear drafts: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}
