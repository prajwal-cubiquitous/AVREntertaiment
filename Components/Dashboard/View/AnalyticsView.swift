import SwiftUI

struct AnalyticsView: View {
    let project: Project
    
    var body: some View {
        AnalysisView(
            projectId: project.id ?? "",
            reportData: generateReportData(from: project)
        )
    }
    
    // MARK: - Helper Methods
    
    private func generateReportData(from project: Project) -> ReportData {
        // Calculate total spent from project data
        let totalSpent = project.departments.values.reduce(0, +) // Using department budgets as spent for demo
        let totalBudget = project.budget
        let budgetUsagePercentage = totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0
        
        // Generate expenses by department
        let expensesByDepartment = project.departments
        
        // Generate sample expenses by category
        let expensesByCategory: [String: Double] = [
            "Travel": totalSpent * 0.35,
            "Meals": totalSpent * 0.25,
            "Equipment": totalSpent * 0.20,
            "Miscellaneous": totalSpent * 0.20
        ]
        
        return ReportData(
            totalSpent: totalSpent,
            totalBudget: totalBudget,
            budgetUsagePercentage: budgetUsagePercentage,
            expensesByCategory: expensesByCategory,
            expensesByDepartment: expensesByDepartment
        )
    }
}
