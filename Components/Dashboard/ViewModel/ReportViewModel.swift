//
//  ReportViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 7/10/25.
//
import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Decodable DepartmentBudget for Firebase
struct ReportDepartmentBudget: Codable {
    let department: String
    let totalBudget: Double
    let approvedBudget: Double
}

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
    
    var filteredDepartmentBudgets: [DepartmentBudget] {
        if selectedDepartment == "All" {
            return departmentBudgets
        } else {
            return departmentBudgets.filter { $0.department == selectedDepartment }
        }
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
    
    // MARK: - Data Loading
    func loadReportData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            await loadDepartmentBudgets()
            await loadExpenses()
            isLoading = false
        }
    }
    
    private func loadDepartmentBudgets() async {
        do {
            let snapshot = try await db.collection("departmentBudgets").getDocuments()
            let budgets = snapshot.documents.compactMap { doc -> DepartmentBudget? in
                do {
                    let reportBudget = try doc.data(as: ReportDepartmentBudget.self)
                    return DepartmentBudget(
                        department: reportBudget.department,
                        totalBudget: reportBudget.totalBudget,
                        approvedBudget: reportBudget.approvedBudget,
                        color: colorForDepartment(reportBudget.department)
                    )
                } catch {
                    print("Error decoding department budget: \(error)")
                    return nil
                }
            }
            
            await MainActor.run {
                self.departmentBudgets = budgets
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load department budgets: \(error.localizedDescription)"
            }
        }
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
    
    private func loadExpenses() async {
        do {
            let snapshot = try await db.collection("expenses").getDocuments()
            let expenseList = snapshot.documents.compactMap { doc -> Expense? in
                try? doc.data(as: Expense.self)
            }
            
            await MainActor.run {
                self.expenses = expenseList
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load expenses: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Helper Methods
    private func colorForDepartment(_ department: String) -> Color {
        let colors: [String: Color] = [
            "Cast": .blue,
            "Location": .green,
            "Equipment": .orange,
            "Production": .purple,
            "Marketing": .red,
            "Design": .pink,
            "Research": .cyan,
            "Website": .indigo,
            "Development": .teal,
            "Other": .gray
        ]
        
        let key = colors.keys.first { department.lowercased().contains($0.lowercased()) }
        return key.flatMap { colors[$0] } ?? .gray
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
