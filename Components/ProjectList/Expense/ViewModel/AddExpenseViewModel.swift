import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import Combine
import UniformTypeIdentifiers

@MainActor
class AddExpenseViewModel: ObservableObject {
    
    // MARK: - Form Inputs
    @Published var expenseDate: Date = Date()
    @Published var amount: String = ""
    @Published var selectedPhaseId: String = ""
    @Published var selectedDepartment: String = ""
    @Published var categories: [String] = [""]
    @Published var categoryCustomNames: [Int: String] = [:] // Store custom names for "Misc / Other" selections (keyed by index)
    @Published var categorySearchTexts: [Int: String] = [:] // Track search text for each category field
    @Published var description: String = ""
    @Published var selectedPaymentMode: PaymentMode = .cash
    @Published var attachmentURL: String?
    @Published var attachmentName: String?
    
    // MARK: - Predefined Categories
    static let predefinedCategories: [String] = [
        "Labour",
        "Raw Materials (cement/steel/sand/bricks)",
        "Ready-Mix / Precast (RMC, precast items)",
        "Equipment/Machinery Hire",
        "Tools & Consumables (bits, blades, smalls)",
        "Subcontractor Services",
        "Transport & Logistics (freight, loading)",
        "Site Utilities (power, water, fuel, internet)",
        "Safety & Compliance (PPE, audits)",
        "Permits & Regulatory Fees",
        "Testing & Quality (soil/cube tests, inspections)",
        "Waste & Disposal (debris, haulage)",
        "Temporary Works (scaffolding, shuttering/formwork)",
        "Finishes & Fixtures (tiles, paint, sanitary, lights)",
        "Repairs & Rework / Snag-fix",
        "Maintenance (post-handover window)",
        "Misc / Other (notes required)"
    ]
    
    // Filter categories based on search text
    func filteredCategories(for index: Int) -> [String] {
        let searchText = categorySearchTexts[index] ?? ""
        if searchText.isEmpty {
            return AddExpenseViewModel.predefinedCategories
        }
        return AddExpenseViewModel.predefinedCategories.filter { category in
            category.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - UI State
    @Published var isLoading: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var showingDocumentPicker: Bool = false
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading: Bool = false
    
    // MARK: - Validation State
    @Published var shouldShowValidationErrors: Bool = false
    @Published var firstInvalidFieldId: String? = nil
    
    // MARK: - Project Data
    let project: Project
    @Published var availablePhases: [PhaseInfo] = []
    @Published var adminApprovalMessage: String? = nil
    var customerId: String? // Customer ID for multi-tenant support
    
    struct PhaseInfo: Identifiable, Equatable {
        let id: String
        let name: String
        let departments: [String: Double] // Department name to budget mapping
        let isEnabled: Bool
        let canAddExpense: Bool // True if phase is in timeline and enabled
        let totalBudget: Double
        let remainingAmount: Double
        let departmentRemainingAmounts: [String: Double] // Department name to remaining amount mapping
        
        static func == (lhs: PhaseInfo, rhs: PhaseInfo) -> Bool {
            lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.departments == rhs.departments &&
            lhs.isEnabled == rhs.isEnabled &&
            lhs.canAddExpense == rhs.canAddExpense &&
            lhs.totalBudget == rhs.totalBudget &&
            lhs.remainingAmount == rhs.remainingAmount &&
            lhs.departmentRemainingAmounts == rhs.departmentRemainingAmounts
        }
    }
    
    // MARK: - Firebase References
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - Update Customer ID
    func updateCustomerId(_ newCustomerId: String) {
        customerId = newCustomerId
        // Reload phases with new customerId
        loadPhases()
    }
    
    // MARK: - Computed Properties
    var amountValue: Double {
        Double(amount) ?? 0.0
    }
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: amountValue)) ?? "₹0.00"
    }
    
    var isFormValid: Bool {
        let hasValidAmount = !amount.isEmpty && amountValue >= 1
        let hasValidPhase = !selectedPhaseId.isEmpty
        let hasValidDepartment = !selectedDepartment.isEmpty
        let hasValidDescription = !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        // Check categories: each must have a value, and if it's "Misc / Other", must have custom name
        let validCategories = categories.enumerated().compactMap { index, category -> String? in
            if category.isEmpty {
                return nil
            }
            if category == "Misc / Other (notes required)" {
                // Must have custom name
                if let customName = categoryCustomNames[index], !customName.trimmingCharacters(in: .whitespaces).isEmpty {
                    return customName
                }
                return nil
            }
            return category
        }
        let hasValidCategories = !validCategories.isEmpty
        
        return hasValidAmount && hasValidPhase && hasValidDepartment && hasValidDescription && hasValidCategories
    }
    
    var selectedPhase: PhaseInfo? {
        availablePhases.first { $0.id == selectedPhaseId }
    }
    
    var nonEmptyCategories: [String] {
        categories.enumerated().compactMap { index, category -> String? in
            if category.isEmpty {
                return nil
            }
            return getFinalCategoryName(at: index)
        }
    }
    
    // MARK: - Initialization
    init(project: Project, customerId: String?) {
        self.project = project
        self.customerId = customerId
        if customerId != nil {
            loadPhases()
        }
    }
    
    // MARK: - Category Management
    func addCategory() {
        categories.append("")
        categorySearchTexts[categories.count - 1] = ""
    }
    
    func selectCategory(_ category: String, at index: Int) {
        if category == "Misc / Other (notes required)" {
            // Keep the category as is, but allow custom name entry
            categories[index] = category
            categorySearchTexts[index] = ""
            // Initialize custom name if not exists
            if categoryCustomNames[index] == nil {
                categoryCustomNames[index] = ""
            }
        } else {
            // For other categories, set directly and clear custom name
            categories[index] = category
            categorySearchTexts[index] = ""
            categoryCustomNames.removeValue(forKey: index)
        }
    }
    
    func setCategoryCustomName(_ name: String, at index: Int) {
        if index >= 0 && index < categories.count && categories[index] == "Misc / Other (notes required)" {
            categoryCustomNames[index] = name
        }
    }
    
    func getCategoryDisplayName(at index: Int) -> String {
        let category = (index >= 0 && index < categories.count) ? categories[index] : ""
        if category == "Misc / Other (notes required)" {
            if let customName = categoryCustomNames[index], !customName.isEmpty {
                return customName
            }
        }
        return category
    }
    
    func getFinalCategoryName(at index: Int) -> String {
        let category = (index >= 0 && index < categories.count) ? categories[index] : ""
        if category == "Misc / Other (notes required)" {
            if let customName = categoryCustomNames[index], !customName.isEmpty {
                return customName
            }
            return category
        }
        return category
    }

    // MARK: - Load Phases
    func loadPhases(for date: Date? = nil) {
        guard let projectId = project.id,
              let customerId = customerId else { return }
        
        Task {
            do {
                // Load phases
                let phasesSnapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .order(by: "phaseNumber")
                    .getDocuments()
                
                // Load approved expenses to calculate remaining amounts
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .getDocuments()
                
                // Calculate approved amounts by phase and department
                var phaseApprovedAmounts: [String: Double] = [:]
                var phaseDepartmentApprovedAmounts: [String: [String: Double]] = [:]
                
                for expenseDoc in expensesSnapshot.documents {
                    if let expense = try? expenseDoc.data(as: Expense.self),
                       let phaseId = expense.phaseId {
                        phaseApprovedAmounts[phaseId, default: 0] += expense.amount
                        phaseDepartmentApprovedAmounts[phaseId, default: [:]][expense.department, default: 0] += expense.amount
                    }
                }
                
                var phasesList: [PhaseInfo] = []
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                let referenceDate = date ?? expenseDate
                
                for doc in phasesSnapshot.documents {
                    if let phase = try? doc.data(as: Phase.self) {
                        // Check if phase is in timeline
                        let startDate = phase.startDate.flatMap { dateFormatter.date(from: $0) }
                        let endDate = phase.endDate.flatMap { dateFormatter.date(from: $0) }
                        
                        let isInTimeline: Bool = {
                            switch (startDate, endDate) {
                            case (nil, nil): return true
                            case (let s?, nil): return s <= referenceDate
                            case (nil, let e?): return referenceDate <= e
                            case (let s?, let e?): return s <= referenceDate && referenceDate <= e
                            }
                        }()
                        
                        let isEnabled = phase.isEnabledValue
                        let canAddExpense = isInTimeline && isEnabled
                        
                        // Calculate phase budget and remaining amount
                        let totalBudget = phase.departments.values.reduce(0, +)
                        let approvedAmount = phaseApprovedAmounts[doc.documentID] ?? 0
                        let remainingAmount = totalBudget - approvedAmount
                        
                        // Calculate department remaining amounts
                        var departmentRemainingAmounts: [String: Double] = [:]
                        let deptApprovedAmounts = phaseDepartmentApprovedAmounts[doc.documentID] ?? [:]
                        
                        for (deptName, deptBudget) in phase.departments {
                            let deptApproved = deptApprovedAmounts[deptName] ?? 0
                            departmentRemainingAmounts[deptName] = deptBudget - deptApproved
                        }
                        
                        phasesList.append(PhaseInfo(
                            id: doc.documentID,
                            name: phase.phaseName,
                            departments: phase.departments,
                            isEnabled: isEnabled,
                            canAddExpense: canAddExpense,
                            totalBudget: totalBudget,
                            remainingAmount: remainingAmount,
                            departmentRemainingAmounts: departmentRemainingAmounts
                        ))
                    }
                }
                
                await MainActor.run {
                    let previousSelectedPhaseId = self.selectedPhaseId
                    self.availablePhases = phasesList
                    
                    // If previously selected phase is still valid, keep it
                    if let previousPhase = phasesList.first(where: { $0.id == previousSelectedPhaseId && $0.canAddExpense }) {
                        if !previousPhase.departments.keys.contains(self.selectedDepartment) {
                            self.selectedDepartment = previousPhase.departments.keys.sorted().first ?? ""
                        }
                    } else {
                        if let firstAvailable = phasesList.first(where: { $0.canAddExpense }) {
                            self.selectedPhaseId = firstAvailable.id
                            self.selectedDepartment = firstAvailable.departments.keys.sorted().first ?? ""
                        } else {
                            self.selectedPhaseId = ""
                            self.selectedDepartment = ""
                        }
                    }
                    
                    // Check admin approval conditions
                    self.checkAdminApprovalConditions()
                }
            } catch {
                print("Error loading phases: \(error)")
            }
        }
    }
    
    func updateDepartmentForPhase() {
        guard let phase = selectedPhase else {
            selectedDepartment = ""
            return
        }
        
        // If current department is not in selected phase, select first available
        if !phase.departments.keys.contains(selectedDepartment) {
            selectedDepartment = phase.departments.keys.sorted().first ?? ""
        }
        
        // Check admin approval conditions when department changes
        checkAdminApprovalConditions()
    }
    
    // MARK: - Admin Approval Check
    
    func checkAdminApprovalConditions() {
        guard amountValue > 0 else {
            adminApprovalMessage = nil
            return
        }
        
        var messages: [String] = []
        
        // Check phase conditions
        if let phase = selectedPhase {
            if phase.totalBudget == 0 {
                messages.append("Phase total budget is 0, so expense will be approved by admin")
            } else if amountValue > phase.remainingAmount {
                messages.append("Entered amount is greater than remaining amount in phase, so expense will be approved by admin")
            }
        }
        
        // Check department conditions
        if let phase = selectedPhase, !selectedDepartment.isEmpty {
            let deptBudget = phase.departments[selectedDepartment] ?? 0
            let deptRemaining = phase.departmentRemainingAmounts[selectedDepartment] ?? 0
            
            if deptBudget == 0 {
                messages.append("Department total budget is 0, so expense will be approved by admin")
            } else if amountValue > deptRemaining {
                messages.append("Entered amount is greater than remaining amount in department, so expense will be approved by admin")
            }
        }
        
        adminApprovalMessage = messages.isEmpty ? nil : messages.joined(separator: ". ")
    }
    
    // MARK: - Calculate isAdmin
    
    var isAdmin: Bool {
        guard amountValue > 0 else { return false }
        
        // Check phase conditions
        if let phase = selectedPhase {
            if phase.totalBudget == 0 {
                return true
            }
            if amountValue > phase.remainingAmount {
                return true
            }
        }
        
        // Check department conditions
        if let phase = selectedPhase, !selectedDepartment.isEmpty {
            let deptBudget = phase.departments[selectedDepartment] ?? 0
            let deptRemaining = phase.departmentRemainingAmounts[selectedDepartment] ?? 0
            
            if deptBudget == 0 {
                return true
            }
            if amountValue > deptRemaining {
                return true
            }
        }
        
        return false
    }
    
    func removeCategory(at index: Int) {
        guard categories.count > 1 else { return }
        categories.remove(at: index)
        // Clean up search text and custom name for removed category
        categorySearchTexts.removeValue(forKey: index)
        categoryCustomNames.removeValue(forKey: index)
        // Reindex remaining search texts and custom names
        var newSearchTexts: [Int: String] = [:]
        var newCustomNames: [Int: String] = [:]
        for (oldIndex, searchText) in categorySearchTexts {
            if oldIndex < index {
                newSearchTexts[oldIndex] = searchText
            } else if oldIndex > index {
                newSearchTexts[oldIndex - 1] = searchText
            }
        }
        for (oldIndex, customName) in categoryCustomNames {
            if oldIndex < index {
                newCustomNames[oldIndex] = customName
            } else if oldIndex > index {
                newCustomNames[oldIndex - 1] = customName
            }
        }
        categorySearchTexts = newSearchTexts
        categoryCustomNames = newCustomNames
    }
    
    // MARK: - File Upload
    func uploadAttachment(_ url: URL) {
        guard let projectId = project.id else { return }
        
        isUploading = true
        uploadProgress = 0.0
        
        // Get file name and extension
        let fileName = url.lastPathComponent
        attachmentName = fileName
        
        // Create unique file path
        guard let customerId = customerId else { return }
        let timestamp = Int(Date().timeIntervalSince1970)
        let storageRef = storage.reference()
            .child("customers")
            .child(customerId)
            .child("projects")
            .child(projectId)
            .child("expenses")
            .child("\(timestamp)_\(fileName)")
        
        // Upload file
        let uploadTask = storageRef.putFile(from: url, metadata: nil) { [weak self] metadata, error in
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
    
    // MARK: - Validation Error Messages
    
    var amountError: String? {
        guard shouldShowValidationErrors else { return nil }
        if amount.isEmpty {
            return "Amount is required"
        }
        if amountValue < 1 {
            return "Value must be greater than 0"
        }
        return nil
    }
    
    var phaseError: String? {
        guard shouldShowValidationErrors else { return nil }
        if selectedPhaseId.isEmpty {
            return "Please select a phase"
        }
        return nil
    }
    
    var departmentError: String? {
        guard shouldShowValidationErrors else { return nil }
        if selectedDepartment.isEmpty {
            return "Please select a department"
        }
        return nil
    }
    
    var descriptionError: String? {
        guard shouldShowValidationErrors else { return nil }
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Description is required"
        }
        return nil
    }
    
    func categoryError(at index: Int) -> String? {
        guard shouldShowValidationErrors else { return nil }
        guard index >= 0 && index < categories.count else { return nil }
        let category = categories[index]
        if category.isEmpty {
            return "Category is required"
        }
        if category == "Misc / Other (notes required)" {
            if let customName = categoryCustomNames[index], !customName.trimmingCharacters(in: .whitespaces).isEmpty {
                return nil
            }
            return "Custom category name is required"
        }
        return nil
    }
    
    var categoriesError: String? {
        guard shouldShowValidationErrors else { return nil }
        let validCategories = categories.enumerated().compactMap { index, category -> String? in
            if category.isEmpty {
                return nil
            }
            if category == "Misc / Other (notes required)" {
                if let customName = categoryCustomNames[index], !customName.trimmingCharacters(in: .whitespaces).isEmpty {
                    return customName
                }
                return nil
            }
            return category
        }
        if validCategories.isEmpty {
            return "At least one category is required"
        }
        return nil
    }
    
    // MARK: - Find First Invalid Field
    
    func findFirstInvalidFieldId() -> String? {
        // Check amount first (most important)
        if amount.isEmpty || amountValue < 1 {
            return "amount"
        }
        
        // Check phase
        if selectedPhaseId.isEmpty {
            return "phase"
        }
        
        // Check department
        if selectedDepartment.isEmpty {
            return "department"
        }
        
        // Check description
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "description"
        }
        
        // Check categories
        for (index, category) in categories.enumerated() {
            if category.isEmpty {
                return "category_\(index)"
            }
            if category == "Misc / Other (notes required)" {
                if let customName = categoryCustomNames[index], !customName.trimmingCharacters(in: .whitespaces).isEmpty {
                    continue
                }
                return "category_\(index)_custom"
            }
        }
        
        return nil
    }
    
    func validateAndFindFirstInvalidField() -> String? {
        shouldShowValidationErrors = true
        return findFirstInvalidFieldId()
    }
    
    // MARK: - Submit Expense
    func submitExpense() {
        guard isFormValid else {
            // Validate and find first invalid field for scrolling
            if let firstInvalidField = validateAndFindFirstInvalidField() {
                firstInvalidFieldId = firstInvalidField
            }
            alertMessage = "Please fill in all required fields correctly."
            showAlert = true
            return
        }
        
        guard let projectId = project.id else {
            alertMessage = "Project ID not found."
            showAlert = true
            return
        }
        
        guard let customerId = customerId else {
            alertMessage = "Customer ID not found. Please log in again."
            showAlert = true
            return
        }
        
        guard let currentUserPhone = UserServices.shared.currentUserPhone else {
            alertMessage = "User not logged in."
            showAlert = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let phase = selectedPhase
                let expenseData: [String: Any] = [
                    "projectId": projectId,
                    "date": formatDate(expenseDate),
                    "amount": amountValue,
                    "department": selectedDepartment,
                    "phaseId": selectedPhaseId,
                    "phaseName": phase?.name ?? "",
                    "categories": nonEmptyCategories,
                    "description": description.trimmingCharacters(in: .whitespacesAndNewlines),
                    "modeOfPayment": selectedPaymentMode.rawValue,
                    "attachmentURL": attachmentURL as Any,
                    "attachmentName": attachmentName as Any,
                    "submittedBy": "\(currentUserPhone)",
                    "status": ExpenseStatus.pending.rawValue,
                    "isAdmin": isAdmin,
                    "createdAt": Timestamp(),
                    "updatedAt": Timestamp()
                ]
                
                // Store in subcollection: customers/{customerId}/projects/{projectId}/expenses/{expenseId}
                try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .addDocument(data: expenseData)
                
                // Check if project is DRAFT and has 0 expenses (this is the first expense)
                // Check the expenses count before adding this expense
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .getDocuments()
                
                // If project is DRAFT and this is the first expense (count == 1 after adding)
                if project.statusType == .DRAFT && expensesSnapshot.documents.count == 1 {
                    // Update project status to ACTIVE
                    try await FirebasePathHelper.shared
                        .projectDocument(customerId: customerId, projectId: projectId)
                        .updateData(["status": ProjectStatus.ACTIVE.rawValue])
                    
                    // Notify that project was updated
                    NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
                }
                
                await MainActor.run {
                    self.isLoading = false
                    self.alertMessage = "Expense submitted successfully for approval!"
                    self.resetForm()
                    self.showAlert = true
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.alertMessage = "Error submitting expense: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
    
    // MARK: - Update Expense
    func updateExpense(expenseId: String) {
        guard isFormValid else {
            alertMessage = "Please fill in all required fields correctly."
            showAlert = true
            return
        }
        
        guard let projectId = project.id else {
            alertMessage = "Project ID not found."
            showAlert = true
            return
        }
        
        guard let customerId = customerId else {
            alertMessage = "Customer ID not found. Please log in again."
            showAlert = true
            return
        }
        
        isLoading = true
        
        let phase = selectedPhase
        var updateData: [String: Any] = [
            "date": formatDate(expenseDate),
            "amount": amountValue,
            "department": selectedDepartment,
            "phaseId": selectedPhaseId,
            "phaseName": phase?.name ?? "",
            "categories": nonEmptyCategories,
            "description": description.trimmingCharacters(in: .whitespacesAndNewlines),
            "modeOfPayment": selectedPaymentMode.rawValue,
            "isAdmin": isAdmin,
            "updatedAt": Timestamp()
        ]
        
        // Only update attachment if it has changed
        if let url = attachmentURL {
            updateData["attachmentURL"] = url
        }
        if let name = attachmentName {
            updateData["attachmentName"] = name
        }
        
        // Update document in Firestore
        FirebasePathHelper.shared
            .expensesCollection(customerId: customerId, projectId: projectId)
            .document(expenseId)
            .updateData(updateData) { [weak self] error in
                
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.alertMessage = "Error updating expense: \(error.localizedDescription)"
                    } else {
                        self?.alertMessage = "Expense updated successfully!"
                    }
                    self?.showAlert = true
                }
            }
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
    
    private func resetForm() {
        expenseDate = Date()
        amount = ""
        description = ""
        categories = [""]
        categoryCustomNames = [:]
        categorySearchTexts = [:]
        selectedPaymentMode = .cash
        attachmentURL = nil
        attachmentName = nil
        uploadProgress = 0.0
        shouldShowValidationErrors = false
        firstInvalidFieldId = nil
        
        // Reset phase and department to first available
        if let firstAvailable = availablePhases.first(where: { $0.canAddExpense }) {
            selectedPhaseId = firstAvailable.id
            selectedDepartment = firstAvailable.departments.keys.sorted().first ?? ""
        }
    }
}

// MARK: - Document Picker Support
extension AddExpenseViewModel {
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
} 
