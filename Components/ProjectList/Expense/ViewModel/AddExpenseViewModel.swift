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
    
    // MARK: - Project Data
    let project: Project
    @Published var availablePhases: [PhaseInfo] = []
    
    struct PhaseInfo: Identifiable, Equatable {
        let id: String
        let name: String
        let departments: [String]
        let isEnabled: Bool
        let canAddExpense: Bool // True if phase is in timeline and enabled
    }
    
    // MARK: - Firebase References
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
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
        let hasValidAmount = !amount.isEmpty && amountValue > 0
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
    init(project: Project) {
        self.project = project
        loadPhases()
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
    private func loadPhases() {
        guard let projectId = project.id else { return }
        let phasesRef = db.collection("projects_ios1").document(projectId).collection("phases")
        phasesRef.order(by: "phaseNumber").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            var phasesList: [PhaseInfo] = []
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            let now = Date()
            
            if let documents = snapshot?.documents {
                for doc in documents {
                    if let phase = try? doc.data(as: Phase.self) {
                        // Check if phase is in timeline
                        let startDate = phase.startDate.flatMap { dateFormatter.date(from: $0) }
                        let endDate = phase.endDate.flatMap { dateFormatter.date(from: $0) }
                        
                        let isInTimeline: Bool = {
                            switch (startDate, endDate) {
                            case (nil, nil):
                                return true // Always visible if no dates
                            case (let s?, nil):
                                return s <= now // Visible if start date passed
                            case (nil, let e?):
                                return now <= e // Visible if before end date
                            case (let s?, let e?):
                                return s <= now && now <= e // Visible if in range
                            }
                        }()
                        
                        let isEnabled = phase.isEnabledValue
                        let canAddExpense = isInTimeline && isEnabled
                        
                        phasesList.append(PhaseInfo(
                            id: doc.documentID,
                            name: phase.phaseName,
                            departments: Array(phase.departments.keys).sorted(),
                            isEnabled: isEnabled,
                            canAddExpense: canAddExpense
                        ))
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.availablePhases = phasesList
                // Auto-select first available phase that can add expense
                if let firstAvailable = phasesList.first(where: { $0.canAddExpense }),
                   self.selectedPhaseId.isEmpty {
                    self.selectedPhaseId = firstAvailable.id
                    if let firstDept = firstAvailable.departments.first {
                        self.selectedDepartment = firstDept
                    }
                }
            }
        }
    }
    
    func updateDepartmentForPhase() {
        guard let phase = selectedPhase else {
            selectedDepartment = ""
            return
        }
        
        // If current department is not in selected phase, select first available
        if !phase.departments.contains(selectedDepartment) {
            selectedDepartment = phase.departments.first ?? ""
        }
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
        let timestamp = Int(Date().timeIntervalSince1970)
        let storageRef = storage.reference()
            .child("projects_ios1")
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
    
    // MARK: - Submit Expense
    func submitExpense() {
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
                    "createdAt": Timestamp(),
                    "updatedAt": Timestamp()
                ]
                
                // Store in subcollection: projects_ios1/{projectId}/expenses/{expenseId}
                try await db.collection("projects_ios1")
                    .document(projectId)
                    .collection("expenses")
                    .addDocument(data: expenseData)
                
                // Check if project is DRAFT and has 0 expenses (this is the first expense)
                // Check the expenses count before adding this expense
                let expensesSnapshot = try await db.collection("projects_ios1")
                    .document(projectId)
                    .collection("expenses")
                    .getDocuments()
                
                // If project is DRAFT and this is the first expense (count == 1 after adding)
                if project.statusType == .DRAFT && expensesSnapshot.documents.count == 1 {
                    // Update project status to ACTIVE
                    try await db.collection("projects_ios1")
                        .document(projectId)
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
        db.collection("projects_ios1")
            .document(projectId)
            .collection("expenses")
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
        
        // Reset phase and department to first available
        if let firstAvailable = availablePhases.first(where: { $0.canAddExpense }) {
            selectedPhaseId = firstAvailable.id
            selectedDepartment = firstAvailable.departments.first ?? ""
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
