//
//  ReportViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 7/10/25.
//
import Foundation
import FirebaseFirestore
import SwiftUI

@MainActor
class ReportViewModel: ObservableObject {
    @Published var departmentBudgets: [DepartmentBudget] = []
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var departmentNames: [String] = []
    
    // Filter properties
    @Published var selectedDateRange: DateRange = .thisMonth
    @Published var selectedDepartment: String = "All"
    
    private let db = Firestore.firestore()
    
    // MARK: - Date Range Enum
    enum DateRange: String, CaseIterable, CustomStringConvertible {
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case thisQuarter = "This Quarter"
        case thisYear = "This Year"
        case custom = "Custom"
        
        var description: String {
            return self.rawValue
        }
        
        var dateInterval: DateInterval {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .thisMonth:
                let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
                return DateInterval(start: startOfMonth, end: endOfMonth)
                
            case .lastMonth:
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                let startOfMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? now
                let endOfMonth = calendar.dateInterval(of: .month, for: lastMonth)?.end ?? now
                return DateInterval(start: startOfMonth, end: endOfMonth)
                
            case .thisQuarter:
                let quarter = calendar.component(.quarter, from: now)
                let year = calendar.component(.year, from: now)
                let startMonth = (quarter - 1) * 3 + 1
                let startOfQuarter = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)) ?? now
                let endOfQuarter = calendar.date(byAdding: DateComponents(month: 3, day: -1), to: startOfQuarter) ?? now
                return DateInterval(start: startOfQuarter, end: endOfQuarter)
                
            case .thisYear:
                let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
                let endOfYear = calendar.dateInterval(of: .year, for: now)?.end ?? now
                return DateInterval(start: startOfYear, end: endOfYear)
                
            case .custom:
                return DateInterval(start: now, end: now)
            }
        }
    }
    
    func fetchDepartmentNames(from documentID: String) {
        let db = Firestore.firestore()
        
        db.collection("projects_ios").document(documentID).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching document: \(error)")
                return
            }
            
            guard let data = snapshot?.data(),
                  let departments = data["departments"] as? [String: Any] else {
                print("Departments field missing or wrong type.")
                return
            }
            
            var keys = Array(departments.keys).sorted()
            keys.insert("All", at: 0) // Add "All" at the beginning

            DispatchQueue.main.async {
                self.departmentNames = keys
            }
        }
    }
    
    var filteredExpenses: [Expense] {
        let dateInterval = selectedDateRange.dateInterval
        var filtered = expenses.filter { expense in
            let expenseDate = expense.createdAt.dateValue()
            return dateInterval.contains(expenseDate)
        }
        
        if selectedDepartment != "All" {
            filtered = filtered.filter { $0.department == selectedDepartment }
        }
        
        return filtered
    }
    
    // Bar chart data for expense categories
    var expenseCategories: [ExpenseCategory] {
        let categories = Dictionary(grouping: filteredExpenses) { expense in
            // Use the first category from the categories array, or "Other" if empty
            expense.categories.first ?? "Other"
        }
        return categories.map { category, expenses in
            ExpenseCategory(
                name: category,
                amount: expenses.reduce(0) { $0 + $1.amount }
            )
        }.sorted { $0.amount > $1.amount }
    }
    
    func loadApprovedExpenses(projectId: String) async {
        let db = Firestore.firestore()
        let expenseCollectionRef = db.collection("projects_ios").document(projectId).collection("expenses")
        do {
            let snapshot: QuerySnapshot
            if selectedDepartment != "All"{
                snapshot = try await expenseCollectionRef
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .whereField("department", isEqualTo: selectedDepartment)
                    .getDocuments()
            }else{
                snapshot = try await expenseCollectionRef
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .getDocuments()
            }
            
            var loadedExpenses: [Expense] = []
            for doc in snapshot.documents {
                if let expense = try? doc.data(as: Expense.self) {
                    loadedExpenses.append(expense)
                }
            }
            
            // Assign to your published expenses list on the main thread
            await MainActor.run {
                self.expenses = loadedExpenses
            }
        } catch {
            print("Failed to load approved expenses: \(error)")
        }
    }
    
    func loadDepartmentBudgets(projectId: String) async {
        let db = Firestore.firestore()
        do {
            // Get the project document
            let projectDoc = try await db.collection("projects_ios").document(projectId).getDocument()
            
            guard let projectData = projectDoc.data(),
                  let departments = projectData["departments"] as? [String: Double] else {
                print("No departments found in project")
                return
            }
            
            // Calculate approved expenses for each department
            var departmentBudgetDict: [String: (total: Double, approved: Double)] = [:]
            
            // Initialize with project department budgets
            for (department, amount) in departments {
                departmentBudgetDict[department] = (total: amount, approved: 0)
            }
            
            // Get approved expenses for this project
            let expensesSnapshot = try await db.collection("projects_ios").document(projectId)
                .collection("expenses")
                .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                .getDocuments()
            
            // Calculate approved amounts per department
            for expenseDoc in expensesSnapshot.documents {
                if let expense = try? expenseDoc.data(as: Expense.self) {
                    let department = expense.department
                    if var current = departmentBudgetDict[department] {
                        current.approved += expense.amount
                        departmentBudgetDict[department] = current
                    }
                }
            }
            
            // Convert to DepartmentBudget objects
            let budgets = departmentBudgetDict.map { (department, values) in
                DepartmentBudget(
                    department: department,
                    totalBudget: values.total,
                    approvedBudget: values.approved,
                    color: .blue // Simple color for now
                )
            }.sorted { $0.department < $1.department }
            
            await MainActor.run {
                self.departmentBudgets = budgets
            }
            
        } catch {
            print("Failed to load department budgets: \(error)")
            // Load sample data if Firebase fails
            await loadSampleDepartmentBudgets()
        }
    }
    
    private func loadSampleDepartmentBudgets() async {
        let sampleBudgets = [
            DepartmentBudget(
                department: "Set Design",
                totalBudget: 300000,
                approvedBudget: 210000,
                color: .blue
            ),
            DepartmentBudget(
                department: "Costumes",
                totalBudget: 100000,
                approvedBudget: 55000,
                color: .green
            ),
            DepartmentBudget(
                department: "Miscellaneous",
                totalBudget: 50000,
                approvedBudget: 20000,
                color: .purple
            )
        ]
        
        await MainActor.run {
            self.departmentBudgets = sampleBudgets
        }
    }
    
    // MARK: - Export Functions
    func exportToPDF() {
        // TODO: Implement PDF export functionality
        print("Exporting to PDF...")
        HapticManager.notification(.success)
    }
    
    func exportToExcel() {
        // TODO: Implement Excel export functionality
        print("Exporting to Excel...")
        HapticManager.notification(.success)
    }
}

// MARK: - Supporting Models
struct ExpenseCategory {
    let name: String
    let amount: Double
    
    var formattedAmount: String {
        "₹\(Int(amount).formatted())"
    }
}
