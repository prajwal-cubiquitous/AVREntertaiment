//
//  DashboardViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/26/25.
//

import Foundation
import FirebaseFirestore
import SwiftUI

struct DepartmentBudget: Equatable {
    let department: String
    let totalBudget: Double
    let spentBudget: Double
    let remainingBudget: Double
    let color: Color
    
    var spentPercentage: Double {
        guard totalBudget > 0 else { return 0 }
        return spentBudget / totalBudget
    }
    
    // MARK: - Equatable conformance
    static func == (lhs: DepartmentBudget, rhs: DepartmentBudget) -> Bool {
        return lhs.department == rhs.department &&
               lhs.totalBudget == rhs.totalBudget &&
               lhs.spentBudget == rhs.spentBudget &&
               lhs.remainingBudget == rhs.remainingBudget
    }
}

struct NotificationItem {
    let id: String
    let title: String
    let message: String
    let timestamp: Date
    let type: NotificationType
    
    enum NotificationType {
        case expenseSubmitted
        case expenseApproved
        case expenseRejected
        case pendingReview
    }
}

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var departmentBudgets: [DepartmentBudget] = []
    @Published var notifications: [NotificationItem] = []
    @Published var pendingNotifications: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let currentUserPhone: String
    private var project: Project?
    
    init(project: Project? = nil) {
        self.project = project
        // Get current user phone from UserDefaults or UserServices
        self.currentUserPhone = UserDefaults.standard.string(forKey: "currentUserPhone") ?? ""
        
        if let project = project {
            // Load data from provided project
            loadDataFromProject(project)
        } else {
            // Load data from Firebase (existing behavior)
            loadMockData() // For preview/testing
        }
    }
    
    // MARK: - Computed Properties for Project Data
    var totalProjectBudgetFormatted: String {
        guard let project = project else { return "₹0.00" }
        let totalBudget = project.budget
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: totalBudget)) ?? "₹0.00"
    }
    
    // MARK: - Update Project Method
    func updateProject(_ newProject: Project?) {
        // Update the internal project property
        self.project = newProject
        
        if let newProject = newProject {
            loadDataFromProject(newProject)
        } else {
            departmentBudgets = []
        }
    }
    
    func loadDashboardData() {
        isLoading = true
        
        Task {
            do {
                if project != nil {
                    // Data already loaded from project
                    await loadNotificationsFromProject()
                } else {
                    // Load from Firebase (existing behavior)
                    await loadProjectForApprover()
                    await loadNotifications()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    // MARK: - Load Data from Project
    private func loadDataFromProject(_ project: Project) {
        var budgets: [String: (total: Double, spent: Double)] = [:]
        
        // Get department budgets from the project
        for (department, amount) in project.departments {
            budgets[department] = (total: amount, spent: 0)
        }
        
        // Convert to DepartmentBudget objects
        departmentBudgets = budgets.map { (department, budget) in
            DepartmentBudget(
                department: department,
                totalBudget: budget.total,
                spentBudget: budget.spent, // TODO: Load actual spent amounts from expenses
                remainingBudget: budget.total - budget.spent,
                color: colorForDepartment(department)
            )
        }.sorted { $0.department < $1.department }
    }
    
    private func loadNotificationsFromProject() async {
        // TODO: Load notifications based on project
        // For now, keep empty or load mock data
        notifications = []
        pendingNotifications = 0
    }
    
    private func loadProjectForApprover() async {
        do {
            // Query project where current user is the manager (approver)
            let snapshot = try await db.collection("projects_ios")
                .whereField("managerId", isEqualTo: currentUserPhone)
                .limit(to: 1) // Only get one project
                .getDocuments()
            
            guard let document = snapshot.documents.first else { return }
            let project = try document.data(as: Project.self)
            
            var budgets: [String: (total: Double, spent: Double)] = [:]
            
            // Add department budgets from project
            for (department, amount) in project.departments {
                budgets[department] = (total: amount, spent: 0)
            }
            
            // Calculate spent amounts from expenses
            let expensesSnapshot = try await document.reference
                .collection("expenses")
                .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                .getDocuments()
            
            for expenseDoc in expensesSnapshot.documents {
                let expense = try expenseDoc.data(as: Expense.self)
                budgets[expense.department]?.spent += expense.amount
            }
            
            // Convert to DepartmentBudget objects
            departmentBudgets = budgets.map { (department, budget) in
                DepartmentBudget(
                    department: department,
                    totalBudget: budget.total,
                    spentBudget: budget.spent,
                    remainingBudget: budget.total - budget.spent,
                    color: colorForDepartment(department)
                )
            }.sorted { $0.department < $1.department }
            
        } catch {
            print("Error loading project: \(error)")
        }
    }
    
    private func loadNotifications() async {
        do {
            // Load pending expenses for approval
            let projectsSnapshot = try await db.collection("projects_ios")
                .whereField("managerId", isEqualTo: currentUserPhone)
                .getDocuments()
            
            var notificationItems: [NotificationItem] = []
            
            for projectDoc in projectsSnapshot.documents {
                let expensesSnapshot = try await projectDoc.reference
                    .collection("expenses")
                    .whereField("status", isEqualTo: ExpenseStatus.pending.rawValue)
                    .order(by: "createdAt", descending: true)
                    .getDocuments()
                
                for expenseDoc in expensesSnapshot.documents {
                    let expense = try expenseDoc.data(as: Expense.self)
                    
                    let notification = NotificationItem(
                        id: expense.id ?? "",
                        title: "New expense submitted:",
                        message: "\(expense.department), ₹\(expense.amount.formattedCurrency)",
                        timestamp: expense.createdAt.dateValue(),
                        type: .expenseSubmitted
                    )
                    notificationItems.append(notification)
                }
            }
            
            notifications = notificationItems
            pendingNotifications = notificationItems.count
            
        } catch {
            print("Error loading notifications: \(error)")
        }
    }
    
    private func colorForDepartment(_ department: String) -> Color {
        switch department.lowercased() {
        case "set design", "set design & construction":
            return .blue
        case "costumes", "costume design":
            return .green
        case "miscellaneous", "misc":
            return .purple
        case "equipment", "equipment rental":
            return .orange
        case "travel", "transportation":
            return .red
        case "wages", "crew wages":
            return .cyan
        default:
            return .gray
        }
    }
    
    // Mock data for preview
    private func loadMockData() {
        departmentBudgets = [
            DepartmentBudget(
                department: "Set Design",
                totalBudget: 300000,
                spentBudget: 280000,
                remainingBudget: 20000,
                color: .blue
            ),
            DepartmentBudget(
                department: "Costumes",
                totalBudget: 100000,
                spentBudget: 45000,
                remainingBudget: 55000,
                color: .green
            ),
            DepartmentBudget(
                department: "Miscellaneous",
                totalBudget: 50000,
                spentBudget: 20000,
                remainingBudget: 30000,
                color: .purple
            )
        ]
        
        notifications = [
            NotificationItem(
                id: "1",
                title: "New expense submitted:",
                message: "Set Design, ₹7,900",
                timestamp: Calendar.current.date(byAdding: .minute, value: -2, to: Date()) ?? Date(),
                type: .expenseSubmitted
            ),
            NotificationItem(
                id: "2",
                title: "Expense approved:",
                message: "Costumes, ₹1,375",
                timestamp: Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date(),
                type: .expenseApproved
            )
        ]
        
        pendingNotifications = 5
    }
    
    // MARK: - Chart Calculation Methods
    func startAngle(for index: Int) -> CGFloat {
        guard !departmentBudgets.isEmpty else { return 0 }
        
        let totalBudget = departmentBudgets.reduce(0) { $0 + $1.totalBudget }
        let previousBudgets = departmentBudgets.prefix(index).reduce(0) { $0 + $1.totalBudget }
        
        return previousBudgets / totalBudget
    }
    
    func endAngle(for index: Int) -> CGFloat {
        guard !departmentBudgets.isEmpty else { return 0 }
        
        let totalBudget = departmentBudgets.reduce(0) { $0 + $1.totalBudget }
        let currentAndPreviousBudgets = departmentBudgets.prefix(index + 1).reduce(0) { $0 + $1.totalBudget }
        
        return currentAndPreviousBudgets / totalBudget
    }
}

// Extension for Double formatting
extension Double {
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "0"
    }
} 
