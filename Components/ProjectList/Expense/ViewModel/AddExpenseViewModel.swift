import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import Combine
import UniformTypeIdentifiers
import UIKit

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
    
    // MARK: - Line Item Fields
    @Published var selectedItemType: String = "" // Sub-category (Global)
    @Published var selectedItem: String = "" // Material
    @Published var brand: String = "" // Brand (optional, manual entry)
    @Published var selectedSpec: String = "" // Grade (from spec)
    @Published var thickness: String = "16 mm" // Thickness (default value)
    @Published var quantity: String = "" // Quantity (numbers only)
    @Published var uom: String = "ton" // Unit of Measure
    @Published var unitPrice: String = "" // Unit Price (manual entry)
    @Published var availableItemTypes: [String] = [] // Available item types from department
    @Published var selectedPaymentMode: PaymentMode = .cash
    @Published var attachmentURL: String?
    @Published var attachmentName: String?
    @Published var paymentProofURL: String?
    @Published var paymentProofName: String?
    
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
    @Published var shouldDismissOnAlert: Bool = false // Flag to determine if view should dismiss
    @Published var showingDocumentPicker: Bool = false
    @Published var showingImagePicker: Bool = false
    @Published var showingAttachmentOptions: Bool = false
    @Published var showingPaymentProofOptions: Bool = false
    @Published var showingPaymentProofImagePicker: Bool = false
    @Published var showingPaymentProofDocumentPicker: Bool = false
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading: Bool = false
    @Published var paymentProofUploadProgress: Double = 0.0
    @Published var isUploadingPaymentProof: Bool = false
    
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
        
        // For numbers < 1000, no formatting needed
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
    
    var amountValue: Double {
        Double(removeFormatting(from: amount)) ?? 0.0
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
        let hasValidAttachment = attachmentURL != nil && !attachmentURL!.isEmpty
        
        // Payment proof is required for UPI and check payment modes
        let requiresPaymentProof = selectedPaymentMode == .upi || selectedPaymentMode == .check
        let hasValidPaymentProof = !requiresPaymentProof || (paymentProofURL != nil && !paymentProofURL!.isEmpty)
        
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
        
        return hasValidAmount && hasValidPhase && hasValidDepartment && hasValidDescription && hasValidCategories && hasValidAttachment && hasValidPaymentProof
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
        let trimmedCategory = category.trimmingCharacters(in: .whitespaces)
        guard !trimmedCategory.isEmpty else { return }
        
        if trimmedCategory == "Misc / Other (notes required)" {
            // Keep the category as is, but allow custom name entry
            categories[index] = trimmedCategory
            categorySearchTexts[index] = trimmedCategory
            // Initialize custom name if not exists
            if categoryCustomNames[index] == nil {
                categoryCustomNames[index] = ""
            }
        } else {
            // For other categories (including custom entries), set directly and clear custom name
            categories[index] = trimmedCategory
            categorySearchTexts[index] = trimmedCategory
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
                let calendar = Calendar.current
                
                // Normalize reference date to start of day for accurate comparison
                let referenceDate = date ?? expenseDate
                let normalizedReferenceDate = calendar.startOfDay(for: referenceDate)
                
                for doc in phasesSnapshot.documents {
                    if let phase = try? doc.data(as: Phase.self) {
                        // Check if phase is in timeline
                        // Normalize dates to start of day to handle same-day comparisons correctly
                        let startDate = phase.startDate.flatMap { dateFormatter.date(from: $0) }
                            .map { calendar.startOfDay(for: $0) }
                        let endDate = phase.endDate.flatMap { dateFormatter.date(from: $0) }
                            .map { calendar.startOfDay(for: $0) }
                        
                        let isInTimeline: Bool = {
                            switch (startDate, endDate) {
                            case (nil, nil): return true
                            case (let s?, nil): return s <= normalizedReferenceDate
                            case (nil, let e?): return normalizedReferenceDate <= e
                            case (let s?, let e?): 
                                // If end date is today and reference date is today, include it
                                // This ensures phases ending today are eligible when selected date is today
                                return s <= normalizedReferenceDate && normalizedReferenceDate <= e
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
        
        // Load available item types from department
        loadAvailableItemTypes()
        
        // Check admin approval conditions when department changes
        checkAdminApprovalConditions()
    }
    
    // MARK: - Load Available Item Types from Department
    func loadAvailableItemTypes() {
        guard let projectId = project.id,
              let customerId = customerId,
              !selectedPhaseId.isEmpty,
              !selectedDepartment.isEmpty else {
            availableItemTypes = []
            return
        }
        
        Task {
            do {
                // Format department name (remove phaseId prefix if exists)
                let departmentName: String
                if let underscoreIndex = selectedDepartment.firstIndex(of: "_") {
                    departmentName = String(selectedDepartment[selectedDepartment.index(after: underscoreIndex)...])
                } else {
                    departmentName = selectedDepartment
                }
                
                // Load department from subcollection
                let departmentsSnapshot = try await FirebasePathHelper.shared
                    .departmentsCollection(customerId: customerId, projectId: projectId, phaseId: selectedPhaseId)
                    .whereField("name", isEqualTo: departmentName)
                    .getDocuments()
                
                var itemTypesSet: Set<String> = []
                
                for deptDoc in departmentsSnapshot.documents {
                    if let department = try? deptDoc.data(as: Department.self) {
                        // Extract unique item types from line items
                        for lineItem in department.lineItems {
                            if !lineItem.itemType.isEmpty {
                                itemTypesSet.insert(lineItem.itemType)
                            }
                        }
                    }
                }
                
                // If no item types found in department, use all available from DepartmentItemData
                if itemTypesSet.isEmpty {
                    itemTypesSet = Set(DepartmentItemData.itemTypeKeys)
                }
                
                await MainActor.run {
                    self.availableItemTypes = Array(itemTypesSet).sorted()
                }
            } catch {
                print("Error loading item types: \(error)")
                // Fallback to all available item types
                await MainActor.run {
                    self.availableItemTypes = DepartmentItemData.itemTypeKeys
                }
            }
        }
    }
    
    // MARK: - Line Item Computed Properties
    var availableItems: [String] {
        guard !selectedItemType.isEmpty else { return [] }
        return DepartmentItemData.items(for: selectedItemType)
    }
    
    var availableSpecs: [String] {
        guard !selectedItemType.isEmpty, !selectedItem.isEmpty else { return [] }
        return DepartmentItemData.specs(for: selectedItemType, item: selectedItem)
    }
    
    var lineAmount: Double {
        let qty = Double(quantity.replacingOccurrences(of: ",", with: "")) ?? 0
        let price = Double(unitPrice.replacingOccurrences(of: ",", with: "")) ?? 0
        return qty * price
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
                                self.shouldDismissOnAlert = false // Don't dismiss on file upload
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
        guard let projectId = project.id else { return }
        
        isUploading = true
        uploadProgress = 0.0
        
        // Generate file name
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "expense_\(timestamp).jpg"
        attachmentName = fileName
        
        // Create unique file path
        guard let customerId = customerId else { return }
        let storageRef = storage.reference()
            .child("customers")
            .child(customerId)
            .child("projects")
            .child(projectId)
            .child("expenses")
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
                        self.shouldDismissOnAlert = false // Don't dismiss on image upload
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
            // If larger than 5MB, we'll keep it as is (Firebase Storage handles large files well)
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
    
    // MARK: - Payment Proof Upload
    func uploadPaymentProof(_ url: URL) {
        guard let projectId = project.id else { return }
        
        isUploadingPaymentProof = true
        paymentProofUploadProgress = 0.0
        
        // Get file name and extension
        let fileName = url.lastPathComponent
        paymentProofName = fileName
        
        // Create unique file path
        guard let customerId = customerId else { return }
        let timestamp = Int(Date().timeIntervalSince1970)
        let storageRef = storage.reference()
            .child("customers")
            .child(customerId)
            .child("projects")
            .child(projectId)
            .child("expenses")
            .child("payment_proof_\(timestamp)_\(fileName)")
        
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
                        self.isUploadingPaymentProof = false
                        
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
                                self.paymentProofURL = downloadURL.absoluteString
                                self.alertMessage = "Payment proof uploaded successfully!"
                                self.shouldDismissOnAlert = false
                                self.showAlert = true
                            }
                        }
                    }
                }
                
                // Observe upload progress
                uploadTask.observe(.progress) { [weak self] snapshot in
                    guard let progress = snapshot.progress else { return }
                    
                    DispatchQueue.main.async {
                        self?.paymentProofUploadProgress = Double(progress.fractionCompleted)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isUploadingPaymentProof = false
                    self.alertMessage = "Failed to process file: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
    
    // MARK: - Upload Payment Proof Image
    func uploadPaymentProofImage(_ image: UIImage) {
        guard let projectId = project.id else { return }
        
        isUploadingPaymentProof = true
        paymentProofUploadProgress = 0.0
        
        // Generate file name
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "payment_proof_\(timestamp).jpg"
        paymentProofName = fileName
        
        // Create unique file path
        guard let customerId = customerId else { return }
        let storageRef = storage.reference()
            .child("customers")
            .child(customerId)
            .child("projects")
            .child(projectId)
            .child("expenses")
            .child(fileName)
        
        // Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            isUploadingPaymentProof = false
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
                self.isUploadingPaymentProof = false
                
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
                        self.paymentProofURL = downloadURL.absoluteString
                        self.alertMessage = "Payment proof uploaded successfully!"
                        self.shouldDismissOnAlert = false
                        self.showAlert = true
                    }
                }
            }
        }
        
        // Observe upload progress
        uploadTask.observe(.progress) { [weak self] snapshot in
            guard let progress = snapshot.progress else { return }
            
            DispatchQueue.main.async {
                self?.paymentProofUploadProgress = Double(progress.fractionCompleted)
            }
        }
    }
    
    func removePaymentProof() {
        // If there's an existing payment proof URL, optionally delete it from storage
        if let urlString = paymentProofURL,
           let url = URL(string: urlString) {
            let storageRef = Storage.storage().reference(forURL: urlString)
            storageRef.delete { [weak self] error in
                if let error = error {
                    print("Failed to delete file: \(error.localizedDescription)")
                }
            }
        }
        
        paymentProofURL = nil
        paymentProofName = nil
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
    
    var attachmentError: String? {
        guard shouldShowValidationErrors else { return nil }
        if attachmentURL == nil || attachmentURL!.isEmpty {
            return "Receipt is required"
        }
        return nil
    }
    
    var paymentProofError: String? {
        guard shouldShowValidationErrors else { return nil }
        let requiresPaymentProof = selectedPaymentMode == .upi || selectedPaymentMode == .check
        if requiresPaymentProof && (paymentProofURL == nil || paymentProofURL!.isEmpty) {
            return "Payment proof is required"
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
        
        // Check attachment (receipt)
        if attachmentURL == nil || attachmentURL!.isEmpty {
            return "attachment"
        }
        
        // Check payment proof (required for UPI and check)
        let requiresPaymentProof = selectedPaymentMode == .upi || selectedPaymentMode == .check
        if requiresPaymentProof && (paymentProofURL == nil || paymentProofURL!.isEmpty) {
            return "paymentProof"
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
        
        let currentUserPhone = UserServices.shared.currentUserPhone != nil ? UserServices.shared.currentUserPhone! : "Admin"
        
        isLoading = true
        
        Task {
            do {
                let phase = selectedPhase
                
                // Ensure department name includes phaseId prefix for uniqueness
                // This prevents expenses from appearing in wrong phases
                let departmentKey: String
                if !selectedPhaseId.isEmpty {
                    // Check if selectedDepartment already has phaseId prefix
                    if selectedDepartment.hasPrefix("\(selectedPhaseId)_") {
                        departmentKey = selectedDepartment
                    } else {
                        // Add phaseId prefix to ensure uniqueness
                        departmentKey = "\(selectedPhaseId)_\(selectedDepartment)"
                    }
                } else {
                    // Fallback to selectedDepartment if no phaseId (shouldn't happen)
                    departmentKey = selectedDepartment
                }
                
                let expenseData: [String: Any] = [
                    "projectId": projectId,
                    "date": formatDate(expenseDate),
                    "amount": amountValue,
                    "department": departmentKey, // Use department key with phaseId prefix
                    "phaseId": selectedPhaseId,
                    "phaseName": phase?.name ?? "",
                    "categories": nonEmptyCategories,
                    "description": description.trimmingCharacters(in: .whitespacesAndNewlines),
                    "modeOfPayment": selectedPaymentMode.rawValue,
                    "attachmentURL": attachmentURL as Any,
                    "attachmentName": attachmentName as Any,
                    "paymentProofURL": paymentProofURL as Any,
                    "paymentProofName": paymentProofName as Any,
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
                
                // Check if project is LOCKED and has 0 expenses (this is the first expense)
                // Check the expenses count before adding this expense
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .getDocuments()
                
                // If project is LOCKED and this is the first expense (count == 1 after adding)
                // Note: LOCKED projects will become ACTIVE when planned date or phase start date arrives
                // This check is kept for backward compatibility but LOCKED projects should transition via date checks
                if project.statusType == .LOCKED && expensesSnapshot.documents.count == 1 {
                    // Check if planned date has arrived - if so, activate
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "dd/MM/yyyy"
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    
                    if let plannedDateStr = project.plannedDate,
                       let plannedDate = dateFormatter.date(from: plannedDateStr) {
                        let planned = calendar.startOfDay(for: plannedDate)
                        if planned <= today {
                            // Update project status to ACTIVE
                            try await FirebasePathHelper.shared
                                .projectDocument(customerId: customerId, projectId: projectId)
                                .updateData(["status": ProjectStatus.ACTIVE.rawValue])
                        }
                    }
                    
                    // Notify that project was updated
                    NotificationCenter.default.post(name: NSNotification.Name("ProjectUpdated"), object: nil)
                }
                
                await MainActor.run {
                    self.isLoading = false
                    self.alertMessage = "Expense submitted successfully for approval!"
                    self.shouldDismissOnAlert = true // Dismiss view only on expense submission
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
        
        // Ensure department name includes phaseId prefix for uniqueness
        let departmentKey: String
        if !selectedPhaseId.isEmpty {
            // Check if selectedDepartment already has phaseId prefix
            if selectedDepartment.hasPrefix("\(selectedPhaseId)_") {
                departmentKey = selectedDepartment
            } else {
                // Add phaseId prefix to ensure uniqueness
                departmentKey = "\(selectedPhaseId)_\(selectedDepartment)"
            }
        } else {
            // Fallback to selectedDepartment if no phaseId (shouldn't happen)
            departmentKey = selectedDepartment
        }
        
        var updateData: [String: Any] = [
            "date": formatDate(expenseDate),
            "amount": amountValue,
            "department": departmentKey, // Use department key with phaseId prefix
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
        
        // Only update payment proof if it has changed
        if let url = paymentProofURL {
            updateData["paymentProofURL"] = url
        }
        if let name = paymentProofName {
            updateData["paymentProofName"] = name
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
        paymentProofURL = nil
        paymentProofName = nil
        uploadProgress = 0.0
        paymentProofUploadProgress = 0.0
        shouldShowValidationErrors = false
        firstInvalidFieldId = nil
        shouldDismissOnAlert = false // Reset dismiss flag
        
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
    
    func handleImageSelection(_ image: UIImage?) {
        guard let image = image else { return }
        uploadImage(image)
    }
    
    func handlePaymentProofDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            uploadPaymentProof(url)
            
        case .failure(let error):
            alertMessage = "Failed to select file: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    func handlePaymentProofImageSelection(_ image: UIImage?) {
        guard let image = image else { return }
        uploadPaymentProofImage(image)
    }
} 
