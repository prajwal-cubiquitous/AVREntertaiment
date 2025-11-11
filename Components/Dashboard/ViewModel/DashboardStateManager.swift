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
            updatedDepartments[department] = amount
            updatedPhase = DashboardView.PhaseSummary(
                id: updatedPhase.id,
                name: updatedPhase.name,
                start: updatedPhase.start,
                end: updatedPhase.end,
                departments: updatedDepartments
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
            updatedDepartments.removeValue(forKey: department)
            updatedPhase = DashboardView.PhaseSummary(
                id: updatedPhase.id,
                name: updatedPhase.name,
                start: updatedPhase.start,
                end: updatedPhase.end,
                departments: updatedDepartments
            )
            allPhases[index] = updatedPhase
            
            // Remove from department spent map
            phaseDepartmentSpentMap[phaseId]?.removeValue(forKey: department)
            
            // Recalculate phase budget
            recalculatePhaseBudget(phaseId: phaseId)
        }
    }
    
    /// Recalculate phase budget after department changes
    private func recalculatePhaseBudget(phaseId: String) {
        guard let phase = allPhases.first(where: { $0.id == phaseId }) else { return }
        let totalBudget = phase.departments.values.reduce(0, +)
        let spent = phaseBudgetMap[phaseId]?.spent ?? 0
        
        phaseBudgetMap[phaseId] = DashboardView.PhaseBudget(
            id: phaseId,
            totalBudget: totalBudget,
            spent: spent
        )
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
                if let p = try? doc.data(as: Phase.self) {
                    let s = p.startDate.flatMap { dateFormatter.date(from: $0) }
                    let e = p.endDate.flatMap { dateFormatter.date(from: $0) }
                    collected.append(DashboardView.PhaseSummary(
                        id: doc.documentID,
                        name: p.phaseName,
                        start: s,
                        end: e,
                        departments: p.departments
                    ))
                    enabledMap[doc.documentID] = p.isEnabledValue
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
                let totalBudget = phase.departments.values.reduce(0, +)
                let spent = phaseSpentMap[phase.id] ?? 0
                budgetMap[phase.id] = DashboardView.PhaseBudget(
                    id: phase.id,
                    totalBudget: totalBudget,
                    spent: spent
                )
            }
            
            phaseBudgetMap = budgetMap
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
                    departmentSpentMap[phaseId]?[expense.department, default: 0] += expense.amount
                }
            }
            
            phaseDepartmentSpentMap = departmentSpentMap
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

