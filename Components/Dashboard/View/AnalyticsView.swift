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
        // Departments are now stored per phase; this lightweight wrapper sends
        // a minimal seed while AnalysisView loads actual data.
        let totalSpent: Double = 0
        let totalBudget = project.budget
        let budgetUsagePercentage = 0.0
        let expensesByDepartment: [String: Double] = [:]
        
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
