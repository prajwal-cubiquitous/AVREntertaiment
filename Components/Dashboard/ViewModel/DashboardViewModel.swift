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
    private let customerId: String? // Customer ID for multi-tenant support
    private var project: Project?
    
    init(project: Project? = nil, phoneNumber: String = "", customerId: String? = nil) {
        self.project = project
        self.customerId = customerId
        // Use passed phone number or fallback to UserDefaults
        self.currentUserPhone = phoneNumber.isEmpty ? (UserDefaults.standard.string(forKey: "currentUserPhone") ?? "") : phoneNumber
        
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
    
    var totalApprovedExpenses: Double {
        return departmentBudgets.reduce(0) { $0 + $1.approvedBudget }
    }
    
    var remainingBudget: Double {
        let totalBudget = departmentBudgets.reduce(0) { $0 + $1.totalBudget }
        return totalBudget - totalApprovedExpenses
    }
    
    var remainingBudgetFormatted: String {
        return remainingBudget.formattedCurrency
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
        
        // Aggregate department budgets from phases subcollection
        Task {
            guard let projectId = project.id,
                  let customerId = customerId else { return }
            do {
                let phasesSnapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .getDocuments()
                for doc in phasesSnapshot.documents {
                    if let phase = try? doc.data(as: Phase.self) {
                        for (dept, amount) in phase.departments {
                            let current = budgets[dept] ?? (0, 0)
                            budgets[dept] = (current.0 + amount, current.1)
                        }
                    }
                }
            } catch {
                print("Error loading phases for aggregation: \(error)")
            }
            
            // Convert to DepartmentBudget objects
            var departmentBudgetsList = budgets.map { (department, budget) in
                DepartmentBudget(
                    department: department,
                    totalBudget: budget.total,
                    approvedBudget: 0, // Placeholder, will be updated
                    color: colorForDepartment(department)
                )
            }.sorted { $0.department < $1.department }
            
            // Always add "Other Expenses" department for anonymous expenses
            let otherExpensesBudget = DepartmentBudget(
                department: "Other Expenses",
                totalBudget: 0, // No allocated budget for anonymous expenses
                approvedBudget: 0, // Will be updated when loading expenses
                color: .gray
            )
            departmentBudgetsList.append(otherExpensesBudget)
            
            await MainActor.run { self.departmentBudgets = departmentBudgetsList }
            
            // Load approved expenses asynchronously
            await loadApprovedExpensesForProject(project)
        }
    }
    
    private func loadApprovedExpensesForProject(_ project: Project) async {
        guard let projectId = project.id,
              let customerId = customerId else { return }
        
        do {
            let expensesSnapshot = try await FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: projectId)
                .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                .getDocuments()
            
            var departmentSpent: [String: Double] = [:]
            var anonymousExpenses: Double = 0
            var anonymousDepartmentInfo: [String: String] = [:] // Track original departments
            
            // Get list of valid departments by aggregating phases
            var validDepartments = Set<String>()
            do {
                let phasesSnapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .getDocuments()
                for doc in phasesSnapshot.documents {
                    if let phase = try? doc.data(as: Phase.self) {
                        validDepartments.formUnion(phase.departments.keys)
                    }
                }
            } catch {
                print("Error loading phases for departments: \(error)")
            }
            for expenseDoc in expensesSnapshot.documents {

                if let expense = try? expenseDoc.data(as: Expense.self) {

                    let department = expense.department
                    
                    if validDepartments.contains(department) {
                        // Department exists in project, add to normal spending
                        departmentSpent[department, default: 0] += expense.amount
                    } else if expense.isAnonymous == true {
                        // Anonymous expense, add to anonymous total
                        anonymousExpenses += expense.amount
                        // Track original department for display
                        if let originalDept = expense.originalDepartment {
                            anonymousDepartmentInfo[originalDept] = originalDept
                        }
                    } else {
                        // Department doesn't exist in project, add to anonymous
                        anonymousExpenses += expense.amount
                    }
                }
            }
            
            await MainActor.run {
                // Update existing departmentBudgets with actual spent amounts
                var updatedBudgets = departmentBudgets.map { budget in
                    if budget.department == "Other Expenses" {
                        // Update Other Expenses with anonymous expenses
                        return DepartmentBudget(
                            department: budget.department,
                            totalBudget: budget.totalBudget,
                            approvedBudget: anonymousExpenses,
                            color: budget.color
                        )
                    } else {
                        // Update normal departments with their spent amounts
                        return DepartmentBudget(
                            department: budget.department,
                            totalBudget: budget.totalBudget,
                            approvedBudget: departmentSpent[budget.department] ?? 0,
                            color: budget.color
                        )
                    }
                }
                
                departmentBudgets = updatedBudgets
            }
            
        } catch {
            print("Error loading approved expenses: \(error)")
        }
    }
    
    private func loadNotificationsFromProject() async {
        // TODO: Load notifications based on project
        // For now, keep empty or load mock data
        notifications = []
        pendingNotifications = 0
    }
    
    private func loadProjectForApprover() async {
        guard let customerId = customerId else {
            print("❌ Customer ID not found in loadProjectForApprover")
            return
        }
        do {
            // Query project where current user is the manager or temp approver
            let snapshot = try await FirebasePathHelper.shared
                .projectsCollection(customerId: customerId)
                .whereFilter(
                    Filter.orFilter([
                        Filter.whereField("managerIds", arrayContains: currentUserPhone),
                        Filter.whereField("tempApproverID", isEqualTo: currentUserPhone)
                    ])
                )
                .limit(to: 1) // Only get one project
                .getDocuments()
            
            guard let document = snapshot.documents.first else { return }
            let project = try document.data(as: Project.self)
            
            var departmentBudgetDict: [String: (total: Double, approved: Double)] = [:]
            var anonymousExpenses: Double = 0
            
            // Aggregate department budgets from phases
            do {
                let phasesSnapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: document.documentID)
                    .getDocuments()
                for phaseDoc in phasesSnapshot.documents {
                    if let phase = try? phaseDoc.data(as: Phase.self) {
                        for (dept, amount) in phase.departments {
                            let current = departmentBudgetDict[dept] ?? (0, 0)
                            departmentBudgetDict[dept] = (current.0 + amount, current.1)
                        }
                    }
                }
            } catch {
                print("Error aggregating departments from phases: \(error)")
            }
            
            // Build validDepartments set
            let validDepartments = Set(departmentBudgetDict.keys)
            
            // Fetch and calculate approved amounts from expenses
            let expensesSnapshot = try await FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: document.documentID)
                .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                .getDocuments()
            
            for expenseDoc in expensesSnapshot.documents {
                if let expense = try? expenseDoc.data(as: Expense.self) {
                    let department = expense.department
                    
                    if validDepartments.contains(department) {
                        // Department exists in project, add to normal spending
                        var currentValues = departmentBudgetDict[department] ?? (0, 0)
                        currentValues.approved += expense.amount
                        departmentBudgetDict[department] = currentValues
                    } else {
                        // Department doesn't exist in project, add to anonymous
                        anonymousExpenses += expense.amount
                    }
                }
            }
            
            // Convert to DepartmentBudget objects
            let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .yellow, .mint]
            var budgets = departmentBudgetDict.enumerated().map { index, entry in
                DepartmentBudget(
                    department: entry.key,
                    totalBudget: entry.value.total,
                    approvedBudget: entry.value.approved,
                    color: colors[index % colors.count]
                )
            }
            
            // Add anonymous department if there are expenses
            if anonymousExpenses > 0 {
                let anonymousBudget = DepartmentBudget(
                    department: "Other Expenses",
                    totalBudget: 0, // No allocated budget for anonymous expenses
                    approvedBudget: anonymousExpenses,
                    color: .gray
                )
                budgets.append(anonymousBudget)
            }
            
            await MainActor.run {
                self.departmentBudgets = budgets.sorted { $0.totalBudget > $1.totalBudget }
            }
            
        } catch {
            print("Error loading project: \(error)")
        }
    }
    
    private func loadNotifications() async {
        guard let customerId = customerId else {
            print("❌ Customer ID not found in loadNotifications")
            return
        }
        do {
            // Load pending expenses for approval
            let projectsSnapshot = try await FirebasePathHelper.shared
                .projectsCollection(customerId: customerId)
                .whereFilter(
                    Filter.orFilter([
                        Filter.whereField("managerIds", arrayContains: currentUserPhone),
                        Filter.whereField("tempApproverID", isEqualTo: currentUserPhone)
                    ])
                )
                .getDocuments()
            
            var notificationItems: [NotificationItem] = []
            
            for projectDoc in projectsSnapshot.documents {
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectDoc.documentID)
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
        
        // Use approved budget for calculation to include "Other Expenses"
        let totalBudget = departmentBudgets.reduce(0) { $0 + max($1.totalBudget, $1.approvedBudget) }
        let previousBudgets = departmentBudgets.prefix(index).reduce(0) { $0 + max($1.totalBudget, $1.approvedBudget) }
        
        return previousBudgets / totalBudget
    }
    
    func endAngle(for index: Int) -> CGFloat {
        guard !departmentBudgets.isEmpty else { return 0 }
        
        // Use approved budget for calculation to include "Other Expenses"
        let totalBudget = departmentBudgets.reduce(0) { $0 + max($1.totalBudget, $1.approvedBudget) }
        let currentAndPreviousBudgets = departmentBudgets.prefix(index + 1).reduce(0) { $0 + max($1.totalBudget, $1.approvedBudget) }
        
        return currentAndPreviousBudgets / totalBudget
    }
    func fetchProject(byId projectId: String) async throws -> Project? {
        guard let customerId = customerId else {
            throw NSError(domain: "DashboardViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Customer ID not found"])
        }
        let docRef = FirebasePathHelper.shared.projectDocument(customerId: customerId, projectId: projectId)
        let snapshot = try await docRef.getDocument()
        
        guard let project = try? snapshot.data(as: Project.self) else {
            print("⚠️ Could not decode project with ID: \(projectId)")
            return nil
        }
        return project
    }
} 
