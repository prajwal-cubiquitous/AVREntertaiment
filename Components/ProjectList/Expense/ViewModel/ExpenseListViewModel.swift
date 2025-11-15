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
    private var hasLoaded: Bool = false // Track if expenses have been loaded
    private var currentFetchTask: Task<Void, Never>? // Track current fetch task
    
    init(project: Project, currentUserPhone: String, customerId: String?) {
        self.project = project
        self.currentUserPhone = currentUserPhone
        self.customerId = customerId
    }
    
    func updateCustomerId(_ newCustomerId: String) {
        // Only update if customerId actually changed
        guard customerId != newCustomerId else { return }
        customerId = newCustomerId
        // Reset hasLoaded so expenses can be fetched with new customerId
        hasLoaded = false
    }
    
    func fetchExpenses(forceRefresh: Bool = false) {
        // Prevent duplicate fetches
        guard !isLoading else { return }
        
        // If already loaded and not forcing refresh, skip
        if hasLoaded && !forceRefresh {
            return
        }
        
        guard let projectId = project.id,
              let customerId = customerId else {
            isLoading = false
            return
        }
        
        // Cancel any existing fetch task
        currentFetchTask?.cancel()
        
        isLoading = true
        
        currentFetchTask = Task {
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                let snapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("submittedBy", isEqualTo: currentUserPhone)
                    .order(by: "createdAt", descending: true)
                    .getDocuments()
                
                // Check again if task was cancelled
                try Task.checkCancellation()
                
                var loadedExpenses: [Expense] = []
                for document in snapshot.documents {
                    var expense = try document.data(as: Expense.self)
                    expense.id = document.documentID
                    loadedExpenses.append(expense)
                }
                
                // Only update if task wasn't cancelled
                if !Task.isCancelled {
                    expenses = loadedExpenses
                    hasLoaded = true
                    isLoading = false
                }
            } catch {
                // Don't update state if task was cancelled
                if !Task.isCancelled {
                    print("Error fetching expenses: \(error)")
                    isLoading = false
                }
            }
        }
    }
    
    func fetchAllExpenses() {
        guard let projectId = project.id,
              let customerId = customerId else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Fetch all expenses without filtering by submittedBy
                let snapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
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
                print("Error fetching all expenses: \(error)")
                isLoading = false
            }
        }
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
            
            // Refresh the expenses list (force refresh to get updated status)
            fetchExpenses(forceRefresh: true)
            
            // Show success feedback
            HapticManager.notification(.success)
            
        } catch {
            print("Error updating expense status: \(error)")
            HapticManager.notification(.error)
        }
    }
}
