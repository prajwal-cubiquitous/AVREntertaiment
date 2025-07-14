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
        case "set design", "set design & construction", "production design":
            return Color(red: 0.2, green: 0.6, blue: 1.0) // Apple Blue
        case "costumes", "costume design", "wardrobe":
            return Color(red: 0.3, green: 0.8, blue: 0.4) // Apple Green
        case "miscellaneous", "misc", "general":
            return Color(red: 0.8, green: 0.4, blue: 0.9) // Apple Purple
        case "equipment", "equipment rental", "technical":
            return Color(red: 1.0, green: 0.6, blue: 0.2) // Apple Orange
        case "travel", "transportation", "logistics":
            return Color(red: 1.0, green: 0.3, blue: 0.3) // Apple Red
        case "wages", "crew wages", "personnel":
            return Color(red: 0.2, green: 0.8, blue: 0.8) // Apple Teal
        case "marketing", "promotion", "advertising":
            return Color(red: 1.0, green: 0.4, blue: 0.6) // Apple Pink
        case "location", "venue", "site":
            return Color(red: 0.6, green: 0.4, blue: 0.8) // Apple Indigo
        case "post production", "editing", "post":
            return Color(red: 0.8, green: 0.8, blue: 0.2) // Apple Yellow
        case "sound", "audio", "music":
            return Color(red: 0.4, green: 0.8, blue: 0.6) // Apple Mint
        case "lighting", "grip", "electrical":
            return Color(red: 1.0, green: 0.7, blue: 0.3) // Apple Amber
        case "catering", "food", "refreshments":
            return Color(red: 0.9, green: 0.5, blue: 0.7) // Apple Rose
        case "insurance", "legal", "compliance":
            return Color(red: 0.5, green: 0.7, blue: 0.9) // Apple Sky Blue
        case "permits", "licenses", "authorization":
            return Color(red: 0.7, green: 0.6, blue: 0.9) // Apple Lavender
        case "props", "properties", "accessories":
            return Color(red: 0.8, green: 0.9, blue: 0.4) // Apple Lime
        case "makeup", "hair", "beauty":
            return Color(red: 1.0, green: 0.5, blue: 0.8) // Apple Magenta
        case "stunts", "action", "special effects":
            return Color(red: 0.9, green: 0.3, blue: 0.5) // Apple Crimson
        case "research", "development", "pre-production":
            return Color(red: 0.4, green: 0.6, blue: 0.8) // Apple Steel Blue
        case "distribution", "delivery", "shipping":
            return Color(red: 0.6, green: 0.8, blue: 0.4) // Apple Chartreuse
        case "publicity", "media", "communications":
            return Color(red: 0.8, green: 0.4, blue: 0.6) // Apple Orchid
        case "security", "safety", "protection":
            return Color(red: 0.7, green: 0.5, blue: 0.3) // Apple Brown
        default:
            // Generate a consistent color based on department name hash
            let hash = abs(department.hashValue)
            let hue = Double(hash % 360) / 360.0
            let saturation = 0.7 + Double(hash % 30) / 100.0
            let brightness = 0.8 + Double(hash % 20) / 100.0
            return Color(hue: hue, saturation: saturation, brightness: brightness)
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
