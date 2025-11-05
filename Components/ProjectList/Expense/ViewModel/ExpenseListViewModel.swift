//
//  ExpenseListViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 7/1/25.
//
import SwiftUI
import FirebaseFirestore

// MARK: - ViewModel
@MainActor
class ExpenseListViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isLoading: Bool = false
    @Published var showingFullList: Bool = false
    
    private let project: Project
    private let db = Firestore.firestore()
    private let currentUserPhone: String
    var customerId: String? // Make it mutable so we can update it
    
    init(project: Project, currentUserPhone: String, customerId: String?) {
        self.project = project
        self.currentUserPhone = currentUserPhone
        self.customerId = customerId
    }
    
    func updateCustomerId(_ newCustomerId: String) {
        customerId = newCustomerId
    }
    
    func fetchExpenses() {
        guard let projectId = project.id,
              let customerId = customerId else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let snapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("submittedBy", isEqualTo: currentUserPhone)
                    .order(by: "createdAt", descending: true)
                    .getDocuments()
                
                var loadedExpenses: [Expense] = []
                for document in snapshot.documents {
                    var expense = try document.data(as: Expense.self)
                    expense.id = document.documentID
                    loadedExpenses.append(expense)
                }
                
                expenses = loadedExpenses
                isLoading = false
            } catch {
                print("Error fetching expenses: \(error)")
                isLoading = false
            }
        }
    }
    
    func fetchAllExpenses() {
        fetchExpenses() // For now, using the same method
    }
    
    @MainActor
    func updateExpenseStatus(_ expense: Expense, status: ExpenseStatus) async {
        guard let expenseId = expense.id,
              let projectId = project.id,
              let customerId = customerId else { return }
        
        do {
            let expenseRef = FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: projectId)
                .document(expenseId)
            
            try await expenseRef.updateData([
                "status": status.rawValue,
                "approvedAt": Date(),
                "approvedBy": currentUserPhone
            ])
            
            // Refresh the expenses list
            await fetchExpenses()
            
            // Show success feedback
            HapticManager.notification(.success)
            
        } catch {
            print("Error updating expense status: \(error)")
            HapticManager.notification(.error)
        }
    }
}
