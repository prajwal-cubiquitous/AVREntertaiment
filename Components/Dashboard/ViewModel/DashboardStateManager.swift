//
//  DashboardStateManager.swift
//  AVREntertainment
//
//  Created for optimized state management and fast UI updates
//

import SwiftUI
import Combine
import FirebaseFirestore

/// Shared state manager for Dashboard data to enable immediate UI updates without Firebase fetches
@MainActor
class DashboardStateManager: ObservableObject {
    // MARK: - Published Properties
    @Published var allPhases: [DashboardView.PhaseSummary] = []
    @Published var phaseEnabledMap: [String: Bool] = [:]
    @Published var phaseBudgetMap: [String: DashboardView.PhaseBudget] = [:]
    @Published var phaseExtensionMap: [String: Bool] = [:]
    @Published var phaseAnonymousExpensesMap: [String: Double] = [:]
    @Published var phaseDepartmentSpentMap: [String: [String: Double]] = [:]
    @Published var isLoading = false
    @Published var lastRefreshTime: Date?
    
    // Project-level aggregated data for fast access
    @Published var totalProjectBudget: Double = 0
    @Published var totalProjectSpent: Double = 0
    @Published var departmentBudgets: [String: (total: Double, spent: Double)] = [:]
    
    // Team members data for shared state management
    @Published var teamMembers: [User] = []
    @Published var teamMemberIds: [String] = []
    
    // MARK: - Private Properties
    private var refreshTask: Task<Void, Never>?
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        return df
    }()
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Public Methods
    
    /// Load all phase data in parallel for optimal performance
    func loadAllData(projectId: String, customerId: String) async {
        // Cancel any existing refresh task
        refreshTask?.cancel()
        
        isLoading = true
        defer { isLoading = false }
        
        // Use structured concurrency to load data in parallel
        async let phasesTask = loadPhases(projectId: projectId, customerId: customerId)
        async let budgetsTask = loadPhaseBudgets(projectId: projectId, customerId: customerId)
        async let departmentSpentTask = loadPhaseDepartmentSpent(projectId: projectId, customerId: customerId)
        async let extensionsTask = loadPhaseExtensions(projectId: projectId, customerId: customerId)
        async let anonymousTask = loadPhaseAnonymousExpenses(projectId: projectId, customerId: customerId)
        
        // Wait for all tasks to complete
        _ = await phasesTask
        _ = await budgetsTask
        _ = await departmentSpentTask
        _ = await extensionsTask
        _ = await anonymousTask
        
        lastRefreshTime = Date()
    }
    
    /// Update phase data immediately (for deletions/additions)
    func updatePhase(_ phase: DashboardView.PhaseSummary) {
        if let index = allPhases.firstIndex(where: { $0.id == phase.id }) {
            allPhases[index] = phase
        } else {
            allPhases.append(phase)
        }
    }
    
    /// Remove phase immediately
    func removePhase(phaseId: String) {
        allPhases.removeAll { $0.id == phaseId }
        phaseBudgetMap.removeValue(forKey: phaseId)
        phaseDepartmentSpentMap.removeValue(forKey: phaseId)
        phaseExtensionMap.removeValue(forKey: phaseId)
        phaseAnonymousExpensesMap.removeValue(forKey: phaseId)
        phaseEnabledMap.removeValue(forKey: phaseId)
    }
    
    /// Update department in phase immediately
    func updateDepartmentInPhase(phaseId: String, department: String, amount: Double) {
        if let index = allPhases.firstIndex(where: { $0.id == phaseId }) {
            var updatedPhase = allPhases[index]
            var updatedDepartments = updatedPhase.departments
            
            // Use phaseId_departmentName format for storage
            let departmentKey = "\(phaseId)_\(department)"
            // Remove old format if exists
            updatedDepartments.removeValue(forKey: department)
            // Set new format
            updatedDepartments[departmentKey] = amount
            
            updatedPhase = DashboardView.PhaseSummary(
                id: updatedPhase.id,
                name: updatedPhase.name,
                start: updatedPhase.start,
                end: updatedPhase.end,
                departments: updatedDepartments,
                departmentList: updatedPhase.departmentList
            )
            allPhases[index] = updatedPhase
            
            // Recalculate phase budget
            recalculatePhaseBudget(phaseId: phaseId)
        }
    }
    
    /// Remove department from phase immediately
    func removeDepartmentFromPhase(phaseId: String, department: String) {
        if let index = allPhases.firstIndex(where: { $0.id == phaseId }) {
            var updatedPhase = allPhases[index]
            var updatedDepartments = updatedPhase.departments
            
            // Handle both old format (department) and new format (phaseId_department)
            let compositeKey = "\(phaseId)_\(department)"
            
            // Remove both formats if they exist
            updatedDepartments.removeValue(forKey: department)
            updatedDepartments.removeValue(forKey: compositeKey)
            
            updatedPhase = DashboardView.PhaseSummary(
                id: updatedPhase.id,
                name: updatedPhase.name,
                start: updatedPhase.start,
                end: updatedPhase.end,
                departments: updatedDepartments,
                departmentList: updatedPhase.departmentList
            )
            allPhases[index] = updatedPhase
            
            // Remove from department spent map (try both formats)
            phaseDepartmentSpentMap[phaseId]?.removeValue(forKey: department)
            phaseDepartmentSpentMap[phaseId]?.removeValue(forKey: compositeKey)
            
            // Recalculate phase budget
            recalculatePhaseBudget(phaseId: phaseId)
        }
    }
    
    /// Recalculate phase budget after department changes
    private func recalculatePhaseBudget(phaseId: String) {
        guard let phase = allPhases.first(where: { $0.id == phaseId }) else { return }
        // Use departmentList if available, otherwise fallback to departments dictionary
        let totalBudget: Double = {
            if !phase.departmentList.isEmpty {
                return phase.departmentList.reduce(0) { $0 + $1.budget }
            } else {
                return phase.departments.values.reduce(0, +)
            }
        }()
        let spent = phaseBudgetMap[phaseId]?.spent ?? 0
        
        phaseBudgetMap[phaseId] = DashboardView.PhaseBudget(
            id: phaseId,
            totalBudget: totalBudget,
            spent: spent
        )
        
        // Recalculate project-level totals
        recalculateProjectTotals()
    }
    
    /// Update expense amount immediately when approved/rejected
    func updateExpenseStatus(expenseId: String, phaseId: String?, department: String, oldStatus: ExpenseStatus, newStatus: ExpenseStatus, amount: Double) {
        guard let phaseId = phaseId else { return }
        
        // Update phase spent amount
        if let currentBudget = phaseBudgetMap[phaseId] {
            var newSpent = currentBudget.spent
            
            // Remove from old status
            if oldStatus == .approved {
                newSpent -= amount
            }
            
            // Add to new status
            if newStatus == .approved {
                newSpent += amount
            }
            
            phaseBudgetMap[phaseId] = DashboardView.PhaseBudget(
                id: phaseId,
                totalBudget: currentBudget.totalBudget,
                spent: max(0, newSpent)
            )
        }
        
        // Update department spent map
        // Expenses use just department name, but departments are stored as phaseId_departmentName
        // We need to match expenses to both formats for backward compatibility
        if phaseDepartmentSpentMap[phaseId] == nil {
            phaseDepartmentSpentMap[phaseId] = [:]
        }
        
        // Use phaseId_departmentName format for new storage
        let departmentKey = "\(phaseId)_\(department)"
        
        // Get spent from new format key, fallback to old format
        var deptSpent = phaseDepartmentSpentMap[phaseId]?[departmentKey] ?? 
                       phaseDepartmentSpentMap[phaseId]?[department] ?? 0
        
        // Remove from old status
        if oldStatus == .approved {
            deptSpent -= amount
        }
        
        // Add to new status
        if newStatus == .approved {
            deptSpent += amount
        }
        
        // Store using new format key
        phaseDepartmentSpentMap[phaseId]?[departmentKey] = max(0, deptSpent)
        // Also update old format for backward compatibility
        phaseDepartmentSpentMap[phaseId]?[department] = max(0, deptSpent)
        
        // Recalculate project-level totals
        recalculateProjectTotals()
    }
    
    /// Update department budget immediately
    func updateDepartmentBudget(phaseId: String, department: String, newBudget: Double) {
        if let index = allPhases.firstIndex(where: { $0.id == phaseId }) {
            var updatedPhase = allPhases[index]
            var updatedDepartments = updatedPhase.departments
            
            // Handle both old format (department) and new format (phaseId_department)
            let compositeKey = "\(phaseId)_\(department)"
            
            // Remove old format if exists
            updatedDepartments.removeValue(forKey: department)
            // Set new format
            updatedDepartments[compositeKey] = newBudget
            
            updatedPhase = DashboardView.PhaseSummary(
                id: updatedPhase.id,
                name: updatedPhase.name,
                start: updatedPhase.start,
                end: updatedPhase.end,
                departments: updatedDepartments,
                departmentList: updatedPhase.departmentList
            )
            allPhases[index] = updatedPhase
            
            // Recalculate phase budget
            recalculatePhaseBudget(phaseId: phaseId)
        }
    }
    
    /// Recalculate all project-level totals from phase data
    func recalculateProjectTotals() {
        // Calculate total project budget from all phases
        totalProjectBudget = allPhases.reduce(0) { total, phase in
            // Use departmentList if available, otherwise fallback to departments dictionary
            let phaseBudget: Double = {
                if !phase.departmentList.isEmpty {
                    return phase.departmentList.reduce(0) { $0 + $1.budget }
                } else {
                    return phase.departments.values.reduce(0, +)
                }
            }()
            return total + phaseBudget
        }
        
        // Calculate total project spent from all phases
        totalProjectSpent = phaseBudgetMap.values.reduce(0) { $0 + $1.spent }
        
        // Calculate department-level totals across all phases
        // Handle both old format (department) and new format (phaseId_department)
        var deptTotals: [String: (total: Double, spent: Double)] = [:]
        
        for phase in allPhases {
            // Use departmentList if available, otherwise fallback to departments dictionary
            if !phase.departmentList.isEmpty {
                for dept in phase.departmentList {
                    let current = deptTotals[dept.name] ?? (0, 0)
                    // Get spent from department spent map (try both formats)
                    let deptKeyWithPrefix = "\(phase.id)_\(dept.name)"
                    let spent = phaseDepartmentSpentMap[phase.id]?[deptKeyWithPrefix] ?? 
                               phaseDepartmentSpentMap[phase.id]?[dept.name] ?? 0
                    deptTotals[dept.name] = (current.total + dept.budget, current.spent + spent)
                }
            } else {
                // Fallback to departments dictionary
                for (deptKey, budget) in phase.departments {
                    // Extract department name from key (handle both formats)
                    let departmentName: String
                    if deptKey.contains("_") {
                        // New format: phaseId_department
                        departmentName = String(deptKey.split(separator: "_").dropFirst().joined(separator: "_"))
                    } else {
                        // Old format: department
                        departmentName = deptKey
                    }
                    
                    let current = deptTotals[departmentName] ?? (0, 0)
                    // Get spent from department spent map (try both formats)
                    let spent = phaseDepartmentSpentMap[phase.id]?[departmentName] ?? 
                               phaseDepartmentSpentMap[phase.id]?[deptKey] ?? 0
                    deptTotals[departmentName] = (current.total + budget, current.spent + spent)
                }
            }
        }
        
        departmentBudgets = deptTotals
    }
    
    // MARK: - Team Members Management
    
    /// Load team members for a project
    func loadTeamMembers(projectId: String, customerId: String) async {
        do {
            let projectDoc = try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .getDocument()
            
            guard let data = projectDoc.data(),
                  let memberIds = data["teamMembers"] as? [String] else {
                teamMemberIds = []
                teamMembers = []
                return
            }
            
            teamMemberIds = memberIds
            
            // Load user details in parallel
            var loadedMembers: [User] = []
            await withTaskGroup(of: User?.self) { group in
                for memberId in memberIds {
                    group.addTask {
                        await self.fetchUserDetails(userId: memberId, customerId: customerId)
                    }
                }
                
                for await member in group {
                    if let member = member {
                        loadedMembers.append(member)
                    }
                }
            }
            
            // Sort members by role (Admin first, then by name)
            loadedMembers.sort { first, second in
                if first.role == .ADMIN && second.role != .ADMIN {
                    return true
                } else if first.role != .ADMIN && second.role == .ADMIN {
                    return false
                } else {
                    return first.name < second.name
                }
            }
            
            teamMembers = loadedMembers
        } catch {
            print("❌ Error loading team members: \(error)")
            teamMemberIds = []
            teamMembers = []
        }
    }
    
    /// Fetch user details by ID
    private func fetchUserDetails(userId: String, customerId: String) async -> User? {
        do {
            let document = try await FirebasePathHelper.shared
                .usersCollection(customerId: customerId)
                .document(userId)
                .getDocument()
            
            if document.exists {
                var user = try document.data(as: User.self)
                user.id = document.documentID
                return user
            }
            return nil
        } catch {
            print("❌ Error fetching user \(userId): \(error)")
            return nil
        }
    }
    
    /// Add team member immediately (before Firebase update)
    func addTeamMember(_ user: User, memberId: String) {
        // Add to IDs if not already present
        if !teamMemberIds.contains(memberId) {
            teamMemberIds.append(memberId)
        }
        
        // Add to members if not already present
        if !teamMembers.contains(where: { $0.id == user.id || $0.phoneNumber == user.phoneNumber }) {
            teamMembers.append(user)
            
            // Sort members by role (Admin first, then by name)
            teamMembers.sort { first, second in
                if first.role == .ADMIN && second.role != .ADMIN {
                    return true
                } else if first.role != .ADMIN && second.role == .ADMIN {
                    return false
                } else {
                    return first.name < second.name
                }
            }
        }
    }
    
    /// Remove team member immediately (before Firebase update)
    func removeTeamMember(memberId: String) {
        // Remove from IDs
        teamMemberIds.removeAll { $0 == memberId }
        
        // Remove from members (check both phone number and email for admin)
        teamMembers.removeAll { user in
            let userMemberId = user.role == .ADMIN ? (user.email ?? "") : user.phoneNumber
            return userMemberId == memberId
        }
    }
    
    /// Update team members list (called after Firebase sync)
    func updateTeamMembers(_ members: [User], memberIds: [String]) {
        teamMembers = members
        teamMemberIds = memberIds
    }
    
    // MARK: - Private Loading Methods
    
    private func loadPhases(projectId: String, customerId: String) async {
        do {
            let snapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .order(by: "phaseNumber")
                .getDocuments()
            
            var collected: [DashboardView.PhaseSummary] = []
            var enabledMap: [String: Bool] = [:]
            
            for doc in snapshot.documents {
                let phaseId = doc.documentID
                if let p = try? doc.data(as: Phase.self) {
                    let s = p.startDate.flatMap { dateFormatter.date(from: $0) }
                    let e = p.endDate.flatMap { dateFormatter.date(from: $0) }
                    
                    // Load departments from departments subcollection
                    var departmentList: [DashboardView.DepartmentSummary] = []
                    var departmentsDict: [String: Double] = [:]
                    
                    do {
                        let departmentsSnapshot = try await FirebasePathHelper.shared
                            .departmentsCollection(customerId: customerId, projectId: projectId, phaseId: phaseId)
                            .getDocuments()
                        
                        for deptDoc in departmentsSnapshot.documents {
                            if let department = try? deptDoc.data(as: Department.self) {
                                let deptId = deptDoc.documentID
                                let deptBudget = department.totalBudget
                                
                                // Add to dictionary for backward compatibility (using phaseId_departmentName format)
                                let deptKey = String.departmentKey(phaseId: phaseId, departmentName: department.name)
                                departmentsDict[deptKey] = deptBudget
                                
                                // Add to department list
                                departmentList.append(DashboardView.DepartmentSummary(
                                    id: deptId,
                                    name: department.name,
                                    budget: deptBudget,
                                    contractorMode: department.contractorMode
                                ))
                            }
                        }
                    } catch {
                        print("⚠️ Error loading departments for phase \(phaseId): \(error.localizedDescription)")
                        // Fallback to phase.departments dictionary (backward compatibility)
                        departmentsDict = p.departments
                    }
                    
                    collected.append(DashboardView.PhaseSummary(
                        id: phaseId,
                        name: p.phaseName,
                        start: s,
                        end: e,
                        departments: departmentsDict,
                        departmentList: departmentList
                    ))
                    enabledMap[phaseId] = p.isEnabledValue
                }
            }
            
            allPhases = collected
            phaseEnabledMap = enabledMap
        } catch {
            print("Error loading phases: \(error)")
        }
    }
    
    private func loadPhaseBudgets(projectId: String, customerId: String) async {
        guard !allPhases.isEmpty else { return }
        
        do {
            let expensesSnapshot = try await FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: projectId)
                .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                .getDocuments()
            
            var phaseSpentMap: [String: Double] = [:]
            for expenseDoc in expensesSnapshot.documents {
                if let expense = try? expenseDoc.data(as: Expense.self),
                   let phaseId = expense.phaseId {
                    phaseSpentMap[phaseId, default: 0] += expense.amount
                }
            }
            
            var budgetMap: [String: DashboardView.PhaseBudget] = [:]
            for phase in allPhases {
                // Use departmentList if available, otherwise fallback to departments dictionary
                let totalBudget: Double = {
                    if !phase.departmentList.isEmpty {
                        return phase.departmentList.reduce(0) { $0 + $1.budget }
                    } else {
                        return phase.departments.values.reduce(0, +)
                    }
                }()
                let spent = phaseSpentMap[phase.id] ?? 0
                budgetMap[phase.id] = DashboardView.PhaseBudget(
                    id: phase.id,
                    totalBudget: totalBudget,
                    spent: spent
                )
            }
            
            phaseBudgetMap = budgetMap
            
            // Recalculate project totals after loading
            recalculateProjectTotals()
        } catch {
            print("Error loading phase budgets: \(error.localizedDescription)")
        }
    }
    
    private func loadPhaseDepartmentSpent(projectId: String, customerId: String) async {
        guard !allPhases.isEmpty else { return }
        
        do {
            let expensesSnapshot = try await FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: projectId)
                .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                .getDocuments()
            
            var departmentSpentMap: [String: [String: Double]] = [:]
            
            for expenseDoc in expensesSnapshot.documents {
                if let expense = try? expenseDoc.data(as: Expense.self),
                   let phaseId = expense.phaseId,
                   expense.isAnonymous != true {
                    if departmentSpentMap[phaseId] == nil {
                        departmentSpentMap[phaseId] = [:]
                    }
                    
                    // Determine the correct department key
                    // Expenses may be stored with format "phaseId_departmentName" or just "departmentName"
                    let departmentKey: String
                    if expense.department.hasPrefix("\(phaseId)_") {
                        // Expense already has phaseId prefix - use it directly
                        departmentKey = expense.department
                    } else {
                        // Expense has just department name - add phaseId prefix to match phase format
                        departmentKey = "\(phaseId)_\(expense.department)"
                    }
                    
                    // Store using the department key
                    departmentSpentMap[phaseId]?[departmentKey, default: 0] += expense.amount
                }
            }
            
            phaseDepartmentSpentMap = departmentSpentMap
            
            // Recalculate project totals after loading
            recalculateProjectTotals()
        } catch {
            print("Error loading phase department spent: \(error.localizedDescription)")
        }
    }
    
    private func loadPhaseExtensions(projectId: String, customerId: String) async {
        guard !allPhases.isEmpty else { return }
        
        do {
            var extensionMap: [String: Bool] = [:]
            
            for phase in allPhases {
                guard let phaseEndDate = phase.end else { continue }
                let phaseEndDateStr = dateFormatter.string(from: phaseEndDate)
                
                let requestsSnapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .document(phase.id)
                    .collection("requests")
                    .whereField("status", isEqualTo: "ACCEPTED")
                    .getDocuments()
                
                var hasExtension = false
                for requestDoc in requestsSnapshot.documents {
                    let requestData = requestDoc.data()
                    if let extendedDate = requestData["extendedDate"] as? String {
                        if extendedDate.trimmingCharacters(in: .whitespacesAndNewlines) == phaseEndDateStr.trimmingCharacters(in: .whitespacesAndNewlines) {
                            hasExtension = true
                            break
                        }
                    }
                }
                
                extensionMap[phase.id] = hasExtension
            }
            
            phaseExtensionMap = extensionMap
        } catch {
            print("Error loading phase extensions: \(error)")
        }
    }
    
    private func loadPhaseAnonymousExpenses(projectId: String, customerId: String) async {
        do {
            let expensesSnapshot = try await FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: projectId)
                .whereField("isAnonymous", isEqualTo: true)
                .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                .getDocuments()
            
            var anonymousMap: [String: Double] = [:]
            for expenseDoc in expensesSnapshot.documents {
                if let expense = try? expenseDoc.data(as: Expense.self),
                   let phaseId = expense.phaseId {
                    anonymousMap[phaseId, default: 0] += expense.amount
                }
            }
            
            phaseAnonymousExpensesMap = anonymousMap
        } catch {
            print("Error loading phase anonymous expenses: \(error)")
        }
    }
}

