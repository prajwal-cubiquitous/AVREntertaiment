//
//  PendingApprovalsViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/26/25.
//

import Foundation
import FirebaseFirestore
import SwiftUI

enum ApprovalAction {
    case approve
    case reject
}

@MainActor
class PendingApprovalsViewModel: ObservableObject {
    @Published var pendingExpenses: [Expense] = []
    @Published var selectedExpenses: Set<String> = []
    @Published var selectedDateFilter: String?
    @Published var selectedDepartmentFilter: String?
    @Published var availableDepartments: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingConfirmation = false
    @Published var pendingAction: ApprovalAction = .approve
    @Published var confirmationMessage = ""
    
    private let db = Firestore.firestore()
    private let currentUserPhone: String
    
    var hasSelectedExpenses: Bool {
        !selectedExpenses.isEmpty
    }
    
    var filteredExpenses: [Expense] {
        var filtered = pendingExpenses
        
        // Apply date filter
        if let dateFilter = selectedDateFilter {
            let calendar = Calendar.current
            let now = Date()
            
            switch dateFilter {
            case "Today":
                filtered = filtered.filter { calendar.isDate($0.createdAt.dateValue(), inSameDayAs: now) }
            case "This Week":
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                filtered = filtered.filter { $0.createdAt.dateValue() >= weekStart }
            case "This Month":
                let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
                filtered = filtered.filter { $0.createdAt.dateValue() >= monthStart }
            default:
                break
            }
        }
        
        // Apply department filter
        if let departmentFilter = selectedDepartmentFilter {
            filtered = filtered.filter { $0.department == departmentFilter }
        }
        
        return filtered.sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
    }
    
    init() {
        self.currentUserPhone = UserDefaults.standard.string(forKey: "currentUserPhone") ?? ""
    }
    
    func loadPendingExpenses() {
        isLoading = true
        
        Task {
            await loadExpensesFromFirebase()
            await loadAvailableDepartments()
            isLoading = false
        }
    }
    
    private func loadExpensesFromFirebase() async {
        do {
            // Get all projects where current user is the manager
            let projectsSnapshot = try await db.collection("projects_ios")
                .whereField("managerId", isEqualTo: currentUserPhone)
                .getDocuments()
            
            var expenses: [Expense] = []
            
            for projectDoc in projectsSnapshot.documents {
                // Get pending expenses from each project
                let expensesSnapshot = try await projectDoc.reference
                    .collection("expenses")
                    .whereField("status", isEqualTo: ExpenseStatus.pending.rawValue)
                    .getDocuments()
                
                for expenseDoc in expensesSnapshot.documents {
                    var expense = try expenseDoc.data(as: Expense.self)
                    expense.id = expenseDoc.documentID
                    print("Debug 1 : \(expense)")
                    print("DEBUG 2: docuemntID for \(expenseDoc.documentID)")
                    expenses.append(expense)
                }
            }
            
            pendingExpenses = expenses
            
        } catch {
            print("Error loading pending expenses: \(error)")
            errorMessage = "Failed to load pending expenses"
        }
    }
    
    private func loadAvailableDepartments() async {
        do {
            let projectsSnapshot = try await db.collection("projects_ios")
                .whereField("managerId", isEqualTo: currentUserPhone)
                .getDocuments()
            
            var departments: Set<String> = []
            
            for projectDoc in projectsSnapshot.documents {
                let project = try projectDoc.data(as: Project.self)
                departments.formUnion(project.departments.keys)
            }
            
            availableDepartments = Array(departments).sorted()
            
        } catch {
            print("Error loading departments: \(error)")
        }
    }
    
    func toggleExpenseSelection(_ expense: Expense, isSelected: Bool) {
        guard let expenseId = expense.id else { return }
        
        if isSelected {
            selectedExpenses.insert(expenseId)
        } else {
            selectedExpenses.remove(expenseId)
        }
    }
    
    func showApprovalConfirmation() {
        pendingAction = .approve
        confirmationMessage = "Are you sure you want to approve \(selectedExpenses.count) expense(s)?"
        showingConfirmation = true
    }
    
    func showRejectionConfirmation() {
        pendingAction = .reject
        confirmationMessage = "Are you sure you want to reject \(selectedExpenses.count) expense(s)?"
        showingConfirmation = true
    }
    
    func executeAction() {
        Task {
            await processSelectedExpenses()
        }
    }
    
    private func processSelectedExpenses() async {
        isLoading = true
        
        do {
            let newStatus: ExpenseStatus = pendingAction == .approve ? .approved : .rejected
            
            // Update each selected expense
            for expenseId in selectedExpenses {
                // Find the project and update the expense
                let projectsSnapshot = try await db.collection("projects_ios")
                    .whereField("managerId", isEqualTo: currentUserPhone)
                    .getDocuments()
                
                for projectDoc in projectsSnapshot.documents {
                    let expenseRef = projectDoc.reference.collection("expenses").document(expenseId)
                    
                    // Check if expense exists in this project
                    let expenseDoc = try await expenseRef.getDocument()
                    if expenseDoc.exists {
                        try await expenseRef.updateData([
                            "status": newStatus.rawValue,
                            "approvedAt": Date(),
                            "approvedBy": currentUserPhone
                        ])
                        break
                    }
                }
            }
            
            // Refresh the list
            await loadExpensesFromFirebase()
            
            // Clear selections
            selectedExpenses.removeAll()
            
            // Show success feedback
            HapticManager.notification(.success)
            
        } catch {
            print("Error processing expenses: \(error)")
            errorMessage = "Failed to process expenses"
            HapticManager.notification(.error)
        }
        
        isLoading = false
    }
    
    // Mock data for preview
    private func loadMockData() {
        pendingExpenses = [
            Expense(
                id: "expense1",
                projectId: "project1",
                date: "15/04/2024",
                amount: 7900,
                department: "Set Design",
                categories: ["Wages"],
                modeOfPayment: .cash,
                description: "Set design wages",
                attachmentURL: nil,
                attachmentName: nil,
                submittedBy: "Anil",
                status: .pending,
                remark: nil,
                createdAt: Timestamp(),
                updatedAt: Timestamp()
            ),
            Expense(
                id: "expense2",
                projectId: "project1",
                date: "16/04/2024",
                amount: 5500,
                department: "Costumes",
                categories: ["Equip/Rentals"],
                modeOfPayment: .upi,
                description: "Costume equipment rentals",
                attachmentURL: nil,
                attachmentName: nil,
                submittedBy: "Priya",
                status: .pending,
                remark: nil,
                createdAt: Timestamp(),
                updatedAt: Timestamp()
            ),
            Expense(
                id: "expense3",
                projectId: "project1",
                date: "17/04/2024",
                amount: 3200,
                department: "Miscellaneous",
                categories: ["Travel"],
                modeOfPayment: .cash,
                description: "Travel expenses",
                attachmentURL: nil,
                attachmentName: nil,
                submittedBy: "Vrew",
                status: .pending,
                remark: nil,
                createdAt: Timestamp(),
                updatedAt: Timestamp()
            ),
            Expense(
                id: "expense4",
                projectId: "project1",
                date: "18/04/2024",
                amount: 12000,
                department: "Equipment",
                categories: ["Equipment"],
                modeOfPayment: .check,
                description: "Equipment purchase",
                attachmentURL: nil,
                attachmentName: nil,
                submittedBy: "Ramesh",
                status: .pending,
                remark: nil,
                createdAt: Timestamp(),
                updatedAt: Timestamp()
            )
        ]
        
        availableDepartments = ["Set Design", "Costumes", "Miscellaneous", "Equipment", "Travel"]
    }
} 
