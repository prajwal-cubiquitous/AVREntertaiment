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
    let approvedBudget: Double
    let color: Color
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
        let total = departmentBudgets.reduce(0) { $0 + $1.totalBudget }
        return total.formattedCurrency
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
                approvedBudget: 0, // Placeholder, will be updated
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
            
            var departmentBudgetDict: [String: (total: Double, approved: Double)] = [:]
            
            // Add department budgets from project
            for (department, amount) in project.departments {
                departmentBudgetDict[department] = (Double(amount), 0)
            }
            
            // Fetch and calculate approved amounts from expenses
            let expensesSnapshot = try await document.reference
                .collection("expenses")
                .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                .getDocuments()
            
            for expenseDoc in expensesSnapshot.documents {
                if let expense = try? expenseDoc.data(as: Expense.self) {
                    let department = expense.department
                    var currentValues = departmentBudgetDict[department] ?? (0, 0)
                    currentValues.approved += expense.amount
                    departmentBudgetDict[department] = currentValues
                }
            }
            
            // Convert to DepartmentBudget objects
            let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .yellow, .mint]
            let budgets = departmentBudgetDict.enumerated().map { index, entry in
                DepartmentBudget(
                    department: entry.key,
                    totalBudget: entry.value.total,
                    approvedBudget: entry.value.approved,
                    color: colors[index % colors.count]
                )
            }
            
            await MainActor.run {
                self.departmentBudgets = budgets.sorted { $0.totalBudget > $1.totalBudget }
            }
            
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
                approvedBudget: 0, // Placeholder, will be updated
                color: .blue
            ),
            DepartmentBudget(
                department: "Costumes",
                totalBudget: 100000,
                approvedBudget: 0, // Placeholder, will be updated
                color: .green
            ),
            DepartmentBudget(
                department: "Miscellaneous",
                totalBudget: 50000,
                approvedBudget: 0, // Placeholder, will be updated
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
