import Foundation
import FirebaseFirestore
import SwiftUI
import Charts

// MARK: - Analysis Data Models
struct ForecastData {
    let months: [String]
    let budgetData: [Double]
    let actualData: [Double]
    let forecastData: [Double]
    let forecastTotal: Double
}

struct VarianceData {
    let months: [String]
    let budgetData: [Double]
    let actualData: [Double]
    let forecastData: [Double]
    let forecastTotal: Double
}

struct PieChartItem: Identifiable {
    let id = UUID()
    let label: String
    let percentage: Double
    let color: Color
}

// MARK: - Analysis Results
struct AnalysisResults {
    let forecastData: ForecastData
    let varianceData: VarianceData
    let trendsData: [PieChartItem]
    let totalSpent: Double
    let totalBudget: Double
    let budgetUsagePercentage: Double
}

// MARK: - Report Data (for analysis input)
struct ReportData {
    let totalSpent: Double
    let totalBudget: Double
    let budgetUsagePercentage: Double
    let expensesByCategory: [String: Double]
    let expensesByDepartment: [String: Double]
}

func fetchForecastData(for projectId: String, completion: @escaping ([ForecastData]) -> Void) {
    let db = Firestore.firestore()
    let projectRef = db.collection("projects_ios").document(projectId)
    
    Task {
        do {
            let projectDoc = try await projectRef.getDocument()
            guard let projectData = projectDoc.data(),
                  let budget = projectData["budget"] as? Double else { return }
            
            // Fetch expenses
            let snapshot = try await projectRef.collection("expenses").getDocuments()
            let docs = snapshot.documents
            
            var monthlyActuals: [String: Double] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for doc in docs {
                if let dateStr = doc["date"] as? String,
                   let amount = doc["amount"] as? Double,
                   let date = dateFormatter.date(from: dateStr) {
                    
                    let monthFormatter = DateFormatter()
                    monthFormatter.dateFormat = "MMM"
                    let month = monthFormatter.string(from: date)
                    
                    monthlyActuals[month, default: 0] += amount
                }
            }
            
            // Example: Forecast = Actual + random adjustment
            let months = ["Jan","Feb","Mar","Apr","May"]
            let budgetData = months.map { _ in budget }
            let actualData = months.map { month in monthlyActuals[month] ?? 0 }
            let forecastData = actualData.map { $0 * 1.05 } // placeholder: +5%
            
            let forecastResult = ForecastData(
                months: months,
                budgetData: budgetData,
                actualData: actualData,
                forecastData: forecastData,
                forecastTotal: forecastData.last ?? 0
            )
            
            await MainActor.run {
                completion([forecastResult])
            }
        } catch {
            print("Error fetching forecast data: \(error)")
        }
    }
}
