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
    
    // Legacy properties for backward compatibility
    @Published var approvedExpensesByDepartment: [String: Double] = [:]
    @Published var allocatedBudgetsByDepartment: [String: Double] = [:]
    
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
        
        let phasesRef = FirebasePathHelper.shared.phasesCollection(customerId: customerId, projectId: projectId)
        phasesRef.order(by: "phaseNumber").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            guard let documents = snapshot?.documents else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            print("DEBUG 1 : Count documents : \(documents.count)")
            
            // Load all approved expenses once using customer-specific path
            FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: projectId)
                .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                .getDocuments { [weak self] expensesSnapshot, _ in
                    guard let self = self else { return }
                    
                    
                    var expensesByPhaseId: [String: [Expense]] = [:]
                    var expensesByPhaseAndDepartment: [String: [String: Double]] = [:]
                    
                    // Process expenses
                    if let expenseDocs = expensesSnapshot?.documents {
                        for expenseDoc in expenseDocs {
                            if let expense = try? expenseDoc.data(as: Expense.self),
                               let phaseId = expense.phaseId {
                                if expensesByPhaseId[phaseId] == nil {
                                    expensesByPhaseId[phaseId] = []
                                }
                                expensesByPhaseId[phaseId]?.append(expense)
                                
                                // Track by phase and department
                                if expensesByPhaseAndDepartment[phaseId] == nil {
                                    expensesByPhaseAndDepartment[phaseId] = [:]
                                }
                                expensesByPhaseAndDepartment[phaseId]?[expense.department, default: 0] += expense.amount
                            }
                        }
                    }
                    
                    // Process phases
                    var phasesList: [PhaseInfo] = []
                    
                    for doc in documents {
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
                            let departmentInfos = phase.departments.map { deptName, deptBudget in
                                let deptApproved = expensesByPhaseAndDepartment[phaseId]?[deptName] ?? 0
                                let deptRemaining = deptBudget - deptApproved
                                
                                return DepartmentInfo(
                                    name: deptName,
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
                    
                    DispatchQueue.main.async {
                        self.phases = phasesList
                        self.currentPhase = self.getCurrentPhase(from: phasesList)
                        self.currentPhases = self.getCurrentPhases(from: phasesList)
                        self.expiredPhases = self.getExpiredPhases(from: phasesList)
                        self.isLoading = false
                    }
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
                    for document in documents {
                        if let expense = try? document.data(as: Expense.self) {
                            if expense.isAnonymous == true {
                                departmentTotals["Other Expenses", default: 0] += expense.amount
                            } else {
                                departmentTotals[expense.department, default: 0] += expense.amount
                            }
                        }
                    }
                    
                    self?.approvedExpensesByDepartment = departmentTotals
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
}
