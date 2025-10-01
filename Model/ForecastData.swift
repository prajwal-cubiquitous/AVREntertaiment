import Foundation
import FirebaseFirestore

struct ForecastData {
    let month: String   // "Jan", "Feb", ...
    let budget: Double
    let actual: Double
    let forecast: Double
}

func fetchForecastData(for projectId: String, completion: @escaping ([ForecastData]) -> Void) {
    let db = Firestore.firestore()
    let projectRef = db.collection("projects_ios").document(projectId)
    
    projectRef.getDocument { projectDoc, error in
        guard let projectData = projectDoc?.data(),
              let budget = projectData["budget"] as? Double else { return }
        
        // Fetch expenses
        projectRef.collection("expenses").getDocuments { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            
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
            var forecastData: [ForecastData] = []
            for month in ["Jan","Feb","Mar","Apr","May"] {
                let actual = monthlyActuals[month] ?? 0
                let forecast = actual * 1.05  // placeholder: +5%
                forecastData.append(ForecastData(month: month,
                                                 budget: budget,
                                                 actual: actual,
                                                 forecast: forecast))
            }
            
            completion(forecastData)
        }
    }
}
