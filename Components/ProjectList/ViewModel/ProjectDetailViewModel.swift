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
        guard let projectId = project.id else {
            print("❌ Project ID not found in loadPhases")
            isLoading = false
            return
        }
        isLoading = true
        
        Task {
            do {
                // Get customerId using fetchEffectiveUserID which gets ownerID from users collection
                let customerId = try await FirebasePathHelper.shared.fetchEffectiveUserID()
                
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
                            // Expenses may be stored with format "phaseId_departmentName" or just "departmentName"
                            // We need to match expenses to phase department keys correctly
                            if expensesByPhaseAndDepartment[phaseId] == nil {
                                expensesByPhaseAndDepartment[phaseId] = [:]
                            }
                            
                            // Determine the correct department key
                            let departmentKey: String
                            if expense.department.hasPrefix("\(phaseId)_") {
                                // Expense already has phaseId prefix - use it directly
                                departmentKey = expense.department
                            } else {
                                // Expense has just department name - add phaseId prefix to match phase format
                                departmentKey = "\(phaseId)_\(expense.department)"
                            }
                            
                            // Store using the department key (only once, no double counting)
                            expensesByPhaseAndDepartment[phaseId]?[departmentKey, default: 0] += expense.amount
                        }
                    } catch {
                        failedCount += 1
                        print("⚠️ Failed to decode expense document \(expenseDoc.documentID): \(error)")
                    }
                }
                
                // Processed expenses: \(processedCount) approved, \(failedCount) failed, Total: ₹\(totalApproved)
                
                // Process phases
                var phasesList: [PhaseInfo] = []
                
                for doc in snapshot.documents {
                    let phaseId = doc.documentID
                    if let phase = try? doc.data(as: Phase.self) {
                        // Parse dates
                        let startDate = phase.startDate.flatMap { self.dateFormatter.date(from: $0) }
                        let endDate = phase.endDate.flatMap { self.dateFormatter.date(from: $0) }
                        
                        // Load departments from departments subcollection
                        var departmentInfos: [DepartmentInfo] = []
                        var totalBudget: Double = 0
                        
                        do {
                            let departmentsSnapshot = try await FirebasePathHelper.shared
                                .departmentsCollection(customerId: customerId, projectId: projectId, phaseId: phaseId)
                                .getDocuments()
                            
                            if !departmentsSnapshot.documents.isEmpty {
                                // Calculate from departments subcollection
                                for deptDoc in departmentsSnapshot.documents {
                                    if let department = try? deptDoc.data(as: Department.self) {
                                        let deptBudget = department.totalBudget
                                        totalBudget += deptBudget
                                        
                                        // Look up expenses - try both with and without phaseId prefix
                                        let deptKeyWithPrefix = "\(phaseId)_\(department.name)"
                                        let deptApproved = expensesByPhaseAndDepartment[phaseId]?[deptKeyWithPrefix] ?? 
                                                          expensesByPhaseAndDepartment[phaseId]?[department.name] ?? 0
                                        let deptRemaining = deptBudget - deptApproved
                                        
                                        departmentInfos.append(DepartmentInfo(
                                            name: department.name,
                                            allocatedBudget: deptBudget,
                                            approvedAmount: deptApproved,
                                            remainingAmount: deptRemaining
                                        ))
                                    }
                                }
                            } else {
                                // Fallback to phase.departments dictionary
                                totalBudget = phase.departments.values.reduce(0, +)
                                
                                // Build department info from dictionary
                                for (deptKey, deptBudget) in phase.departments {
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
                                    
                                    departmentInfos.append(DepartmentInfo(
                                        name: displayName,
                                        allocatedBudget: deptBudget,
                                        approvedAmount: deptApproved,
                                        remainingAmount: deptRemaining
                                    ))
                                }
                            }
                        } catch {
                            print("⚠️ Error loading departments for phase \(phaseId): \(error.localizedDescription)")
                            // Fallback to phase.departments dictionary
                            totalBudget = phase.departments.values.reduce(0, +)
                            
                            for (deptKey, deptBudget) in phase.departments {
                                let displayName: String
                                if let underscoreIndex = deptKey.firstIndex(of: "_") {
                                    displayName = String(deptKey[deptKey.index(after: underscoreIndex)...])
                                } else {
                                    displayName = deptKey
                                }
                                
                                let deptApproved = expensesByPhaseAndDepartment[phaseId]?[deptKey] ?? 0
                                let deptRemaining = deptBudget - deptApproved
                                
                                departmentInfos.append(DepartmentInfo(
                                    name: displayName,
                                    allocatedBudget: deptBudget,
                                    approvedAmount: deptApproved,
                                    remainingAmount: deptRemaining
                                ))
                            }
                        }
                        
                        // Sort departments by name
                        departmentInfos.sort { $0.name < $1.name }
                        
                        // Calculate approved amount for this phase
                        let phaseExpenses = expensesByPhaseId[phaseId] ?? []
                        let approvedAmount = phaseExpenses.reduce(0) { $0 + $1.amount }
                        let remainingAmount = totalBudget - approvedAmount
                        
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
        let calendar = Calendar.current
        let current = calendar.startOfDay(for: now) // Normalize current date to start of day
        
        switch (phase.startDate, phase.endDate) {
        case (nil, nil):
            return true // Always visible if no dates
        case (let s?, nil):
            let startOfDay = calendar.startOfDay(for: s)
            return startOfDay <= current // Visible if start date passed or is today
        case (nil, let e?):
            let endOfDay = calendar.startOfDay(for: e)
            return current <= endOfDay // Visible if before or on end date (end date is inclusive)
        case (let s?, let e?):
            let startOfDay = calendar.startOfDay(for: s)
            let endOfDay = calendar.startOfDay(for: e)
            return startOfDay <= current && current <= endOfDay // Visible if in range (end date is inclusive)
        }
    }
    
    private func isPhaseExpired(_ phase: PhaseInfo) -> Bool {
        let calendar = Calendar.current
        let current = calendar.startOfDay(for: now) // Normalize current date to start of day
        
        switch (phase.startDate, phase.endDate) {
        case (nil, nil):
            return false // No dates means not expired
        case (let s?, nil):
            return false // Only start date means not expired
        case (nil, let e?):
            let endOfDay = calendar.startOfDay(for: e)
            return current > endOfDay // Expired if past end date (end date is not expired)
        case (let s?, let e?):
            let endOfDay = calendar.startOfDay(for: e)
            return current > endOfDay // Expired if past end date (end date is not expired)
        }
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    func fetchApprovedExpenses() {
        guard let projectId = project.id else {
            print("❌ Project ID not found in fetchApprovedExpenses")
            return
        }
        
        Task {
            do {
                // Get customerId using fetchEffectiveUserID which gets ownerID from users collection
                let customerId = try await FirebasePathHelper.shared.fetchEffectiveUserID()
                
                // Fetch all approved expenses for this project
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .getDocuments()
                
                var departmentTotals: [String: Double] = [:]
                var totalApproved: Double = 0
                var parsedCount = 0
                var failedCount = 0
                
                for document in expensesSnapshot.documents {
                    do {
                        var expense = try document.data(as: Expense.self)
                        expense.id = document.documentID
                        totalApproved += expense.amount
                        parsedCount += 1
                        
                        if expense.isAnonymous == true {
                            departmentTotals["Other Expenses", default: 0] += expense.amount
                        } else {
                            departmentTotals[expense.department, default: 0] += expense.amount
                        }
                    } catch {
                        failedCount += 1
                        print("⚠️ Failed to parse expense document \(document.documentID): \(error)")
                    }
                }
                
                await MainActor.run {
                    self.approvedExpensesByDepartment = departmentTotals
                    // Only update totalApprovedExpenses if we successfully parsed at least one expense
                    // or if we got 0 documents (meaning there really are no approved expenses)
                    // This prevents overwriting a correct value from loadPhases() if there's a parsing issue
                    if parsedCount > 0 || expensesSnapshot.documents.isEmpty {
                        self.totalApprovedExpenses = totalApproved
                    } else if failedCount > 0 {
                        print("⚠️ fetchApprovedExpenses: All expenses failed to parse. Keeping existing totalApprovedExpenses value of ₹\(self.totalApprovedExpenses)")
                    }
                }
            } catch {
                print("❌ Error fetching approved expenses: \(error)")
                // Don't overwrite existing value on error - keep the value from loadPhases()
            }
        }
    }

    func fetchAllocatedBudgets() {
        guard let projectId = project.id else {
            print("❌ Project ID not found in fetchAllocatedBudgets")
            return
        }
        
        Task {
            do {
                // Get customerId using fetchEffectiveUserID which gets ownerID from users collection
                let customerId = try await FirebasePathHelper.shared.fetchEffectiveUserID()
                
                let phasesRef = FirebasePathHelper.shared.phasesCollection(customerId: customerId, projectId: projectId)
                let snapshot = try await phasesRef.getDocuments()
                
                var totals: [String: Double] = [:]
                for doc in snapshot.documents {
                    if let phase = try? doc.data(as: Phase.self) {
                        for (dept, amount) in phase.departments {
                            totals[dept, default: 0] += amount
                        }
                    }
                }
                
                await MainActor.run {
                    self.allocatedBudgetsByDepartment = totals
                }
            } catch {
                print("❌ Error fetching allocated budgets: \(error)")
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
        guard let projectId = project.id else {
            print("❌ Project ID not found in loadPhaseExtensions")
            return
        }
        
        // Wait for phases to be loaded
        guard !phases.isEmpty else {
            print("⚠️ No phases loaded yet, skipping extension check")
            return
        }
        
        do {
            // Get customerId using fetchEffectiveUserID which gets ownerID from users collection
            let customerId = try await FirebasePathHelper.shared.fetchEffectiveUserID()
            
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
