//
//  ProjectDetailViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 7/1/25.
//
import SwiftUI
import FirebaseFirestore


// MARK: - Project Detail ViewModel
@MainActor
class ProjectDetailViewModel: ObservableObject {
    @Published var approvedExpensesByDepartment: [String: Double] = [:]
    @Published var isLoading = false
    
    private let project: Project
    private let db = Firestore.firestore()
    private let CurrentUserPhone : String
    
    init(project: Project, CurrentUserPhone : String) {
        self.project = project
        self.CurrentUserPhone = CurrentUserPhone
        self.fetchApprovedExpenses()
    }
    
    func fetchApprovedExpenses()  {
        guard let projectId = project.id else { return }
        isLoading = true
        
        db.collection("projects_ios")
            .document(projectId)
            .collection("expenses")
            .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
            .getDocuments { [weak self] snapshot, error in
                
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    guard let documents = snapshot?.documents else {
                        print("Error fetching approved expenses: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }
                    
                    var departmentTotals: [String: Double] = [:]
                    for document in documents {
                        if let expense = try? document.data(as: Expense.self) {
                            if expense.isAnonymous == true{
                                departmentTotals["Other Expenses", default: 0] += expense.amount
                            }else{
                                departmentTotals[expense.department, default: 0] += expense.amount
                            }
                        }
                    }
                    
                    self?.approvedExpensesByDepartment = departmentTotals
                }
            }
    }
    
    func approvedAmount(for department: String) -> Double {
        print("DEBUG 30 : \(approvedExpensesByDepartment)")
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
