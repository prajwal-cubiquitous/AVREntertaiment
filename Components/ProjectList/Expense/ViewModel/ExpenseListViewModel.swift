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
    private let currentUserPhone = UserDefaults.standard.string(forKey: "currentUserPhone") ?? ""
    
    init(project: Project) {
        self.project = project
    }
    
    func fetchExpenses() {
        isLoading = true
        
        Task {
            do {
                let snapshot = try await db.collection("projects_ios")
                    .document(project.id ?? "")
                    .collection("expenses")
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
        guard let expenseId = expense.id else { return }
        
        do {
            let expenseRef = db.collection("projects_ios")
                .document(project.id ?? "")
                .collection("expenses")
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
