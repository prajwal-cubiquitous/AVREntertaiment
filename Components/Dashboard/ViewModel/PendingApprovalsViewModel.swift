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
    @Published var project: Project
    private let db = Firestore.firestore()
    private let currentUserPhone: String
    let currentUserRole: UserRole
    
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
    
    init(role: UserRole? = nil, project: Project, phoneNumber: String) {
        self.currentUserPhone = phoneNumber
        self.currentUserRole = role ?? .USER
        self.project = project
    }
    
    func loadPendingExpenses() {
        isLoading = true
        
        Task {
            if currentUserRole == .ADMIN {
                await loadExpensesFromFirebaseAdmin()
                await loadAvailableDepartmentsAdmin()
            } else {
                await loadExpensesFromFirebase()
                await loadAvailableDepartments()
            }
            isLoading = false
        }
    }
    
    private func loadExpensesFromFirebase() async {
        do {
            guard let projectId = project.id else{ return }
            // Get all projects where current user is the manager or temp approver
            let projectsSnapshot = try await db.collection("projects_ios").document(projectId)
                .getDocument()
            
            var expenses: [Expense] = []
            
                // Get pending expenses from each project
                let expensesSnapshot = try await projectsSnapshot.reference
                    .collection("expenses")
                    .whereField("status", isEqualTo: ExpenseStatus.pending.rawValue)
                    .getDocuments()
                
                for expenseDoc in expensesSnapshot.documents {
                    var expense = try expenseDoc.data(as: Expense.self)
                    expense.id = expenseDoc.documentID
                    expenses.append(expense)
                }
            
            pendingExpenses = expenses
            
        } catch {
            print("Error loading pending expenses: \(error)")
            errorMessage = "Failed to load pending expenses"
        }
    }
    
    private func loadExpensesFromFirebaseAdmin() async {
        do {
            
            guard let projectId = project.id else{ return }
            
            // Get all projects where current user is the manager
            let projectsSnapshot = try await db.collection("projects_ios").document(projectId)
                .getDocument()
            
            var expenses: [Expense] = []
            
                // Get pending expenses from each project
                let expensesSnapshot = try await projectsSnapshot.reference
                    .collection("expenses")
                    .whereField("status", isEqualTo: ExpenseStatus.pending.rawValue)
                    .getDocuments()
                
                for expenseDoc in expensesSnapshot.documents {
                    var expense = try expenseDoc.data(as: Expense.self)
                    expense.id = expenseDoc.documentID
                    expenses.append(expense)
                }
            
            pendingExpenses = expenses
            
        } catch {
            print("Error loading pending expenses: \(error)")
            errorMessage = "Failed to load pending expenses"
        }
    }
    
    private func loadAvailableDepartments() async {
        do {
            
            guard let projectId = project.id else{ return }
            
            let projectsSnapshot = try await db.collection("projects_ios")
                .document(projectId)
                .getDocument()
            
            var departments: Set<String> = []
            
                let project = try projectsSnapshot.data(as: Project.self)
                departments.formUnion(project.departments.keys)
            
            availableDepartments = Array(departments).sorted()
            
        } catch {
            print("Error loading departments: \(error)")
        }
    }
    
    private func loadAvailableDepartmentsAdmin() async {
        do {
            guard let projectId = project.id else{ return }
            
            let projectsSnapshot = try await db.collection("projects_ios")
                .document(projectId)
                .getDocument()
            
            var departments: Set<String> = []
            
                let project = try projectsSnapshot.data(as: Project.self)
                departments.formUnion(project.departments.keys)
            
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
            
            guard let projectId = project.id else{ return }
            
            
            let newStatus: ExpenseStatus = pendingAction == .approve ? .approved : .rejected
            
            // Update each selected expense
            for expenseId in selectedExpenses {
                // Find the project and update the expense
                
                let projectsSnapshot = try await db.collection("projects_ios")
                    .document(projectId)
                    .getDocument()
                
                    let expenseRef = projectsSnapshot.reference.collection("expenses").document(expenseId)
                    
                    // Check if expense exists in this project
                    let expenseDoc = try await expenseRef.getDocument()
                    if expenseDoc.exists {
                        var updateData: [String: Any] = [
                            "status": newStatus.rawValue,
                            "approvedAt": Date(),
                            "approvedBy": currentUserPhone
                        ]
                        
                        // Add admin approval note if current user is admin
                        if currentUserRole == .ADMIN {
                            let adminNote = "Admin approved"
                            updateData["remark"] = adminNote
                        }
                        
                        try await expenseRef.updateData(updateData)
                        break
                    }
            }
            
            // Refresh the list
            if currentUserRole == .ADMIN {
                await loadExpensesFromFirebaseAdmin()
            } else {
                await loadExpensesFromFirebase()
            }
            
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
    
    func loadUserData(userId: String) async throws -> String {
        // 1. Throw an error for an invalid user ID
        guard !userId.isEmpty else {
            throw UserDataError.invalidUserId
        }
        
        let updatedUserId = userId.replacingOccurrences(of: "+91", with: "")
        
        // 2. Fetch the document
        let userSnapshot = try await db.collection("users_ios").document(updatedUserId).getDocument()
                
        // 3. Safely unwrap the document data
        guard let data = userSnapshot.data() else {
            throw UserDataError.userNotFound
        }
        
        // 4. Safely get the "name" as a String
        guard let name = data["name"] as? String else {
            throw UserDataError.missingNameField
        }
        
        // 5. Success! Return the name.
        return name
    }
    
    // MARK: - Chat Related Methods
    
    func getTempApproverId(for expense: Expense) -> String {
        // This should return the temp approver ID for the expense's project
        // For now, returning a placeholder - you'll need to implement this based on your data structure
        return "temp_approver_\(expense.projectId)"
    }
    
    func getCurrentUserPhoneNumber() -> String {
        return currentUserPhone
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
                isAnonymous: nil,
                originalDepartment: nil,
                departmentDeletedAt: nil,
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
                isAnonymous: nil,
                originalDepartment: nil,
                departmentDeletedAt: nil,
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
                isAnonymous: nil,
                originalDepartment: nil,
                departmentDeletedAt: nil,
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
                isAnonymous: nil,
                originalDepartment: nil,
                departmentDeletedAt: nil,
                createdAt: Timestamp(),
                updatedAt: Timestamp()
            )
        ]
        
        availableDepartments = ["Set Design", "Costumes", "Miscellaneous", "Equipment", "Travel"]
    }
} 


