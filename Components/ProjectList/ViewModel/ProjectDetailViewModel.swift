//
//  ProjectDetailViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 7/1/25.
//
import SwiftUI
import FirebaseFirestore
import FirebaseAuth


// MARK: - Project Detail ViewModel
@MainActor
class ProjectDetailViewModel: ObservableObject {
    // Phase-wise data structures
    struct PhaseInfo: Identifiable {
        let id: String
        let phaseName: String
        let phaseNumber: Int
        let startDate: Date?
        let endDate: Date?
        let totalBudget: Double
        let approvedAmount: Double
        let remainingAmount: Double
        let departments: [DepartmentInfo]
        let isEnabled: Bool
        
        var spentPercentage: Double {
            guard totalBudget > 0 else { return 0 }
            return approvedAmount / totalBudget
        }
    }
    
    struct DepartmentInfo: Identifiable {
        let id = UUID()
        let name: String
        let allocatedBudget: Double
        let approvedAmount: Double
        let remainingAmount: Double
        
        var spentPercentage: Double {
            guard allocatedBudget > 0 else { return 0 }
            return approvedAmount / allocatedBudget
        }
    }
    
    @Published var phases: [PhaseInfo] = []
    @Published var currentPhase: PhaseInfo?
    @Published var currentPhases: [PhaseInfo] = []
    @Published var expiredPhases: [PhaseInfo] = []
    @Published var isLoading = false
    @Published var phaseExtensionMap: [String: Bool] = [:] // Track if phase has accepted extension
    
    // Legacy properties for backward compatibility
    @Published var approvedExpensesByDepartment: [String: Double] = [:]
    @Published var allocatedBudgetsByDepartment: [String: Double] = [:]
    @Published var totalApprovedExpenses: Double = 0 // Total approved expenses across all phases
    
    private let project: Project
    private let db = Firestore.firestore()
    private let CurrentUserPhone : String
    private let customerId: String? // Customer ID passed from parent view
    
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        return df
    }
    
    private var now: Date { Date() }
    
    init(project: Project, CurrentUserPhone : String, customerId: String?) {
        self.project = project
        self.CurrentUserPhone = CurrentUserPhone
        self.customerId = customerId
        self.fetchAllocatedBudgets()
        self.fetchApprovedExpenses()
        self.loadPhases()
    }
    
    // MARK: - Load Phases
    func loadPhases() {
        guard let projectId = project.id,
              let customerId = customerId else {
            print("❌ Customer ID or Project ID not found in loadPhases")
            isLoading = false
            return
        }
        isLoading = true
        
        Task {
            do {
                let phasesRef = FirebasePathHelper.shared.phasesCollection(customerId: customerId, projectId: projectId)
                let snapshot = try await phasesRef.order(by: "phaseNumber").getDocuments()
                
                guard !snapshot.documents.isEmpty else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
            
                // Load all approved expenses once using customer-specific path
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .getDocuments()
                
                var expensesByPhaseId: [String: [Expense]] = [:]
                var expensesByPhaseAndDepartment: [String: [String: Double]] = [:]
                var totalApproved: Double = 0 // Track total approved expenses
                
                // Process expenses
                var processedCount = 0
                var failedCount = 0
                for expenseDoc in expensesSnapshot.documents {
                    do {
                        let expense = try expenseDoc.data(as: Expense.self)
                        // Add to total regardless of phaseId
                        totalApproved += expense.amount
                        processedCount += 1
                        
                        // Process phase-based expenses
                        if let phaseId = expense.phaseId {
                            if expensesByPhaseId[phaseId] == nil {
                                expensesByPhaseId[phaseId] = []
                            }
                            expensesByPhaseId[phaseId]?.append(expense)
                            
                            // Track by phase and department
                            // Expenses use just department name, but departments are stored as phaseId_departmentName
                            // We need to match expenses to both formats for backward compatibility
                            if expensesByPhaseAndDepartment[phaseId] == nil {
                                expensesByPhaseAndDepartment[phaseId] = [:]
                            }
                            // Store with new format key (phaseId_departmentName)
                            let departmentKey = "\(phaseId)_\(expense.department)"
                            expensesByPhaseAndDepartment[phaseId]?[departmentKey, default: 0] += expense.amount
                            // Also store with old format for backward compatibility
                            expensesByPhaseAndDepartment[phaseId]?[expense.department, default: 0] += expense.amount
                        }
                    } catch {
                        failedCount += 1
                        print("⚠️ Failed to decode expense document \(expenseDoc.documentID): \(error)")
                    }
                }
                
                print("📊 Processed \(processedCount) approved expenses, \(failedCount) failed, Total: ₹\(totalApproved)")
                
                // Process phases
                var phasesList: [PhaseInfo] = []
                
                for doc in snapshot.documents {
                    let phaseId = doc.documentID
                    if let phase = try? doc.data(as: Phase.self) {
                        // Parse dates
                        let startDate = phase.startDate.flatMap { self.dateFormatter.date(from: $0) }
                        let endDate = phase.endDate.flatMap { self.dateFormatter.date(from: $0) }
                        
                        // Calculate phase budget from departments
                        let totalBudget = phase.departments.values.reduce(0, +)
                        
                        // Calculate approved amount for this phase
                        let phaseExpenses = expensesByPhaseId[phaseId] ?? []
                        let approvedAmount = phaseExpenses.reduce(0) { $0 + $1.amount }
                        let remainingAmount = totalBudget - approvedAmount
                        
                        // Build department info
                        // Strip phaseId_ prefix from department keys for display
                        let departmentInfos = phase.departments.map { deptKey, deptBudget in
                            // Extract display name by removing phaseId_ prefix
                            let displayName: String
                            if let underscoreIndex = deptKey.firstIndex(of: "_") {
                                displayName = String(deptKey[deptKey.index(after: underscoreIndex)...])
                            } else {
                                displayName = deptKey // Old format, use as is
                            }
                            
                            // Look up expenses using the original key (with phaseId prefix)
                            let deptApproved = expensesByPhaseAndDepartment[phaseId]?[deptKey] ?? 0
                            let deptRemaining = deptBudget - deptApproved
                            
                            return DepartmentInfo(
                                name: displayName,
                                allocatedBudget: deptBudget,
                                approvedAmount: deptApproved,
                                remainingAmount: deptRemaining
                            )
                        }.sorted { $0.name < $1.name }
                        
                        let phaseInfo = PhaseInfo(
                            id: phaseId,
                            phaseName: phase.phaseName,
                            phaseNumber: phase.phaseNumber,
                            startDate: startDate,
                            endDate: endDate,
                            totalBudget: totalBudget,
                            approvedAmount: approvedAmount,
                            remainingAmount: remainingAmount,
                            departments: departmentInfos,
                            isEnabled: phase.isEnabledValue
                        )
                        
                        phasesList.append(phaseInfo)
                    }
                }
                
                await MainActor.run {
                    self.phases = phasesList
                    self.currentPhase = self.getCurrentPhase(from: phasesList)
                    self.currentPhases = self.getCurrentPhases(from: phasesList)
                    self.expiredPhases = self.getExpiredPhases(from: phasesList)
                    // Always update totalApprovedExpenses with the calculated value
                    self.totalApprovedExpenses = totalApproved
                    print("✅ Total approved expenses calculated: ₹\(totalApproved) from \(expensesSnapshot.documents.count) expense documents")
                    self.isLoading = false
                }
                
                // Load phase extensions after phases are loaded
                await self.loadPhaseExtensions()
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Error loading phases: \(error)")
            }
        }
    }
    
    // MARK: - Phase Filtering
    private func getCurrentPhase(from phases: [PhaseInfo]) -> PhaseInfo? {
        return phases.first { isPhaseInProgress($0) && $0.isEnabled }
    }
    
    private func getCurrentPhases(from phases: [PhaseInfo]) -> [PhaseInfo] {
        // Only show phases that are enabled AND in progress
        return phases.filter { isPhaseInProgress($0) && $0.isEnabled }
    }
    
    private func getExpiredPhases(from phases: [PhaseInfo]) -> [PhaseInfo] {
        // Only show phases that are enabled AND expired
        return phases.filter { isPhaseExpired($0) && $0.isEnabled }
    }
    
    private func isPhaseUpcoming(_ phase: PhaseInfo) -> Bool {
        let current = now
        switch (phase.startDate, phase.endDate) {
        case (nil, nil):
            return false // No dates means not upcoming
        case (let s?, nil):
            return s > current // Upcoming if start date is in future
        case (nil, let e?):
            return false // Only end date, not upcoming
        case (let s?, let e?):
            return s > current // Upcoming if start date is in future
        }
    }
    
    private func isPhaseInProgress(_ phase: PhaseInfo) -> Bool {
        let current = now
        switch (phase.startDate, phase.endDate) {
        case (nil, nil):
            return true // Always visible if no dates
        case (let s?, nil):
            return s <= current // Visible if start date passed
        case (nil, let e?):
            return current <= e // Visible if before end date
        case (let s?, let e?):
            return s <= current && current <= e // Visible if in range
        }
    }
    
    private func isPhaseExpired(_ phase: PhaseInfo) -> Bool {
        let current = now
        switch (phase.startDate, phase.endDate) {
        case (nil, nil):
            return false // No dates means not expired
        case (let s?, nil):
            return false // Only start date means not expired
        case (nil, let e?):
            return current > e // Expired if past end date
        case (let s?, let e?):
            return current > e // Expired if past end date
        }
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    func fetchApprovedExpenses()  {
        guard let projectId = project.id,
              let customerId = customerId else {
            print("❌ Customer ID or Project ID not found in fetchApprovedExpenses")
            return
        }
        
        FirebasePathHelper.shared
            .expensesCollection(customerId: customerId, projectId: projectId)
            .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let documents = snapshot?.documents else {
                        return
                    }
                    
                    var departmentTotals: [String: Double] = [:]
                    var totalApproved: Double = 0
                    for document in documents {
                        if let expense = try? document.data(as: Expense.self) {
                            totalApproved += expense.amount
                            if expense.isAnonymous == true {
                                departmentTotals["Other Expenses", default: 0] += expense.amount
                            } else {
                                departmentTotals[expense.department, default: 0] += expense.amount
                            }
                        }
                    }
                    
                    self?.approvedExpensesByDepartment = departmentTotals
                    // Update total approved expenses if phases haven't loaded yet or if total is 0
                    // Otherwise, loadPhases() will have the more accurate total (it processes all expenses)
                    if self?.phases.isEmpty == true || self?.totalApprovedExpenses == 0 {
                        self?.totalApprovedExpenses = totalApproved
                    }
                }
            }
    }

    func fetchAllocatedBudgets() {
        guard let projectId = project.id,
              let customerId = customerId else {
            print("❌ Customer ID or Project ID not found in fetchAllocatedBudgets")
            return
        }
        let phasesRef = FirebasePathHelper.shared.phasesCollection(customerId: customerId, projectId: projectId)
        phasesRef.getDocuments { [weak self] snapshot, error in
            var totals: [String: Double] = [:]
            if let documents = snapshot?.documents {
                for doc in documents {
                    if let phase = try? doc.data(as: Phase.self) {
                        for (dept, amount) in phase.departments {
                            totals[dept, default: 0] += amount
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                self?.allocatedBudgetsByDepartment = totals
            }
        }
    }
    
    func approvedAmount(for department: String) -> Double {
        return approvedExpensesByDepartment[department] ?? 0
    }
    
    func remainingBudget(for department: String, allocatedBudget: Double) -> Double {
        return allocatedBudget - approvedAmount(for: department)
    }
    
    func spentPercentage(for department: String, allocatedBudget: Double) -> Double {
        guard allocatedBudget > 0 else { return 0 }
        return approvedAmount(for: department) / allocatedBudget
    }
    
    // Computed property to get total approved expenses from phases
    var totalApprovedFromPhases: Double {
        return phases.reduce(0) { $0 + $1.approvedAmount }
    }
    
    // MARK: - Load Phase Extensions
    func loadPhaseExtensions() async {
        guard let projectId = project.id,
              let customerId = customerId else {
            print("❌ Customer ID or Project ID not found in loadPhaseExtensions")
            return
        }
        
        // Wait for phases to be loaded
        guard !phases.isEmpty else {
            print("⚠️ No phases loaded yet, skipping extension check")
            return
        }
        
        do {
            var extensionMap: [String: Bool] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            
            // Check each phase for accepted extension requests
            for phase in phases {
                // Get phase end date from Firebase directly (as String)
                let phaseDoc = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .document(phase.id)
                    .getDocument()
                
                guard let phaseData = phaseDoc.data(),
                      let phaseEndDateStr = phaseData["endDate"] as? String else {
                    continue
                }
                
                // Query requests collection for accepted requests
                let requestsSnapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .document(phase.id)
                    .collection("requests")
                    .whereField("status", isEqualTo: "ACCEPTED")
                    .getDocuments()
                
                
                // Check if any accepted request's extendedDate matches phase endDate
                var hasExtension = false
                for requestDoc in requestsSnapshot.documents {
                    let requestData = requestDoc.data()
                    if let extendedDate = requestData["extendedDate"] as? String {
                        // Compare extendedDate with phase endDate
                        if extendedDate == phaseEndDateStr {
                            hasExtension = true
                            break
                        }
                    }
                }
                
                extensionMap[phase.id] = hasExtension
            }
            
            await MainActor.run {
                self.phaseExtensionMap = extensionMap
            }
        } catch {
            print("❌ Error loading phase extensions: \(error)")
        }
    }
}
