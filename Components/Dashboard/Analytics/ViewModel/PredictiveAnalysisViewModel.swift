//
//  PredictiveAnalysisViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/8/25.
//

import FirebaseFirestore
import Foundation
import SwiftUI

@MainActor
class PredictiveAnalysisViewModel: ObservableObject {
    let monthsOfYear = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    @Published var expenses: [Expense] = []
    @Published var trends: [(category: String, percent: Double)] = []
    @Published var analytics: AnalyticsSummary?
    @Published var isLoading = false
    @Published var summaryText = "Loading analytics data..."
    @Published var monthlyData: [MonthlyData] = []
    @Published var customMonthlyData: [MonthlyData] = []
    
    // Chart data
    @Published var months: [String] = []
    @Published var perMonthBudget: [Double] = []
    @Published var actuals: [Double] = []
    @Published var forecast: [Double] = []
    
    private let project: Project
    
    init(project: Project) {
        self.project = project
        Task{
            await fetchData()
        }
    }
    
    func fetchData() async{
        guard let projectId = project.id else { 
            print("❌ Project ID is nil, cannot fetch data")
            isLoading = false
            return 
        }
        
        isLoading = true
        await fetchExpenses(for: projectId)
        fetchExpensesFromFirestore(projectId: projectId)
    }
    
    let db = Firestore.firestore()
    
    func fetchExpenses(for projectId: String) async {
        let currentDate = Date()
        let calendar = Calendar.current
        let defaultStartDate = calendar.date(byAdding: .month, value: -3, to: currentDate) ?? currentDate
        let defaultEndDate = calendar.date(byAdding: .month, value: 3, to: currentDate) ?? currentDate
        print("👉 Default date window:", defaultStartDate, "to", defaultEndDate)

        let fetchedDates = await fetchStartDate(projectId: projectId)
        let startDate = fetchedDates?.0 ?? defaultStartDate
        let endDate = fetchedDates?.1 ?? defaultEndDate
        print("✅ Using date window:", startDate, "to", endDate)

        let todayDate = Date()
        let todayMonthName = DateFormatter.monthFormatter.string(from: todayDate)
        let startMonthName = DateFormatter.monthFormatter.string(from: startDate)
        let endMonthName = DateFormatter.monthFormatter.string(from: endDate)

        // Helper: produce all months within window (handles wrap if needed)
        func generateMonthRange(from start: String, to end: String, monthsOfYear: [String]) -> [String] {
            guard let startIdx = monthsOfYear.firstIndex(of: start),
                  let endIdx = monthsOfYear.firstIndex(of: end) else { return [] }
            if startIdx <= endIdx {
                return Array(monthsOfYear[startIdx...endIdx])
            } else {
                // Wrap-around for calendar
                return Array(monthsOfYear[startIdx...]) + Array(monthsOfYear[...endIdx])
            }
        }

        do {
            let snapshot = try await db
                .collection("projects_ios")
                .document(projectId)
                .collection("expenses")
                .whereField("status", isEqualTo: "APPROVED")
                .getDocuments()
            print("📦 Number of expense documents fetched:", snapshot.documents.count)

            var monthlySums: [String: Double] = [:]
            for doc in snapshot.documents {
                guard
                    let amount = doc["amount"] as? Double,
                    let timestamp = doc["createdAt"] as? Timestamp
                else {
                    print("❓ Skipping doc with missing amount/timestamp:", doc.documentID)
                    continue
                }
                let expenseDate = timestamp.dateValue()
                if expenseDate >= startDate && expenseDate <= endDate {
                    let monthName = DateFormatter.monthFormatter.string(from: expenseDate)
                    monthlySums[monthName, default: 0] += amount
                    print("➕ Added ₹\(amount) to \(monthName)")
                }
            }
            print("📊 Monthly Sums before filling:", monthlySums)

            // Fill missing months in window with zero
            let allMonthsWindow = generateMonthRange(from: startMonthName, to: endMonthName, monthsOfYear: self.monthsOfYear)
            for month in allMonthsWindow {
                monthlySums[month] = monthlySums[month] ?? 0.0
            }
            print("📊 Monthly Sums after filling missing gaps:", monthlySums)

            let Remainingtotal = monthlySums.values.reduce(0, +)
            print("💰 Sum of all expenses in range:", Remainingtotal)

            // Use filled month range
            let sortedMonths = allMonthsWindow
            print("📅 Sorted Months:", sortedMonths)

            // Only months up to today's month (inclusive)
            let sortedTillToday: [String] = {
                if let idx = sortedMonths.firstIndex(of: todayMonthName) {
                    return Array(sortedMonths[...idx])
                } else {
                    return sortedMonths
                }
            }()
            print("📅 Till Today:", sortedTillToday)

            let (duration, budget) = await fetchProjectDurationAndMonthlyBudget(projectId: projectId) ?? (0, 0)
            print("📈 Monthly Budget:", budget)

            self.monthlyData = sortedTillToday.enumerated().map { index, month in
                let isLast = index == sortedTillToday.count - 1
                let amount = monthlySums[month] ?? 0
                print("🔹 MonthlyData for \(month): budget \(budget), actual \(amount), forecast: \(isLast ? "\(amount)" : "nil")")
                return MonthlyData(
                    month: month,
                    budget: budget,
                    actual: amount,
                    forecast: isLast ? amount : nil
                )
            }

            // Next months: from today's month to project end month
            let monthsOfYear = self.monthsOfYear
            var nextMonths: [String] = []
            if let startIdx = monthsOfYear.firstIndex(of: todayMonthName),
               let endIdx = monthsOfYear.firstIndex(of: endMonthName) {
                if endIdx >= startIdx {
                    nextMonths = Array(monthsOfYear[startIdx...endIdx])
                } else {
                    nextMonths = Array(monthsOfYear[startIdx...]) + Array(monthsOfYear[...endIdx])
                }
            }
            print("🔜 Next Months (forecast target):", nextMonths)

            // === Direct (non-average) forecast logic ===
            // Find remaining months (excluding months up to today)
            let remainingMonths = nextMonths.filter { !sortedTillToday.contains($0) }
            let alreadyUsedTotal = sortedTillToday.map { monthlySums[$0] ?? 0.0 }.reduce(0, +)
            let totalProjectBudget = budget * Double(duration)
            let remainingBudgetForForecast = max(totalProjectBudget - alreadyUsedTotal, 0)
            let perMonthForecast: Double = remainingMonths.count > 0 ? remainingBudgetForForecast / Double(remainingMonths.count) : 0.0

            var futureMonthlyData: [MonthlyData] = []
            for month in remainingMonths {
                print("🔮 Future Data for \(month): forecast \(perMonthForecast)")
                futureMonthlyData.append(MonthlyData(month: month, budget: budget, actual: nil, forecast: perMonthForecast))
            }

            // Custom window logic on sortedTillToday (filled)
            var customMonths: [String] = []
            if let todayIdx = sortedTillToday.firstIndex(of: todayMonthName) {
                if todayIdx == sortedTillToday.count - 1 {
                    let start = max(0, todayIdx - 5)
                    customMonths = Array(sortedTillToday[start...todayIdx])
                } else if todayIdx == 0 {
                    let end = min(sortedTillToday.count - 1, todayIdx + 5)
                    customMonths = Array(sortedTillToday[todayIdx...end])
                } else {
                    let start = max(0, todayIdx - 2)
                    let end = min(sortedTillToday.count - 1, todayIdx + 3)
                    customMonths = Array(sortedTillToday[start...end])
                }
            }
            print("✨ Custom Window Months:", customMonths)

            let customMonthlyData = customMonths.compactMap { month in
                self.monthlyData.first(where: { $0.month == month })
            }
            print("🗂️ customMonthlyData before forecast append:", customMonthlyData.map { "\($0.month): \($0.actual ?? 0)" })

            // Append up to 3 unique future forecast months, no duplicates
            let existingMonths = Set(customMonthlyData.map { $0.month })
            let uniqueFutureMonthlyData = futureMonthlyData.filter { !existingMonths.contains($0.month) }
            let futureToAdd: [MonthlyData]
            if uniqueFutureMonthlyData.count <= 3 {
                futureToAdd = uniqueFutureMonthlyData
            } else {
                futureToAdd = Array(uniqueFutureMonthlyData.prefix(3))
            }
            self.customMonthlyData = customMonthlyData + futureToAdd
            print("🗂️ Final customMonthlyData (actuals + up to 3 unique future forecasts):", self.customMonthlyData.map { "\($0.month): \($0.actual ?? $0.forecast ?? 0)" })

        } catch {
            print("❌ Error fetching expenses: \(error.localizedDescription)")
        }
    }




//    func movingAverageForecast(history: [MonthlyData], futureMonths: Int) -> [Double] {
//        var values = history.compactMap { $0.actual }
//        var result: [Double] = []
//        let window = 3
//        for _ in 0..<futureMonths {
//            let slice = values.suffix(window)
//            let avg = slice.reduce(0, +) / Double(slice.count)
//            result.append(avg)
//            values.append(avg)
//        }
//        return result
//    }
    
    func fetchStartDate(projectId: String) async -> (Date?, Date?)?{
        do{
            let doc = try await db.collection("projects_ios").document(projectId).getDocument()
            
            guard let data = doc.data() else {
                print("❌ No project data found.")
                return nil
            }
            
            var startDate: Date?
            var endDate: Date?
            

            // Handle Timestamp or String
            if let ts = data["startDate"] as? Timestamp {
                startDate = ts.dateValue()
            } else if let str = data["startDate"] as? String {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM/yyyy"
                startDate = formatter.date(from: str)
            }

            if let ts = data["endDate"] as? Timestamp {
                endDate = ts.dateValue()
            } else if let str = data["endDate"] as? String {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM/yyyy"
                endDate = formatter.date(from: str)
            }
            
            
            return (startDate, endDate)
            
            
        }catch{
            print("error")
            return nil
        }
    }

    
    func fetchProjectDurationAndMonthlyBudget(projectId: String) async -> (Int, Double)? {
        
        do {
            let doc = try await db.collection("projects_ios").document(projectId).getDocument()
            
            guard let data = doc.data() else {
                print("❌ No project data found.")
                return nil
            }
            
            let totalBudget = data["budget"] as? Double ?? 0.0
            
            var startDate: Date?
            var endDate: Date?
            

            // Handle Timestamp or String
            if let ts = data["startDate"] as? Timestamp {
                startDate = ts.dateValue()
            } else if let str = data["startDate"] as? String {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM/yyyy"
                startDate = formatter.date(from: str)
            }

            if let ts = data["endDate"] as? Timestamp {
                endDate = ts.dateValue()
            } else if let str = data["endDate"] as? String {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM/yyyy"
                endDate = formatter.date(from: str)
            }
            
            // Calculate duration in months (default 12)
            var months = 12
            if let start = startDate, let end = endDate {
                let comps = Calendar.current.dateComponents([.month], from: start, to: end)
                let diff = (comps.month ?? 0) + 1
                months = diff > 0 ? diff : 12
            }
            
            // Calculate monthly budget
            let monthlyBudget = totalBudget / Double(months)
            
            return (months, monthlyBudget)
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            return nil
        }
    }

    
    
    private func fetchExpensesFromFirestore(projectId: String) {
        db.collection("projects_ios").document(projectId).collection("expenses")
            .getDocuments { [weak self] (snapshot, error) in
            DispatchQueue.main.async {
                self?.isLoading = false
            }
            
            if let error = error {
                print("❌ Error fetching expenses: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.expenses = []
                    self?.processData()
                }
                return
            }
            
            guard let docs = snapshot?.documents, !docs.isEmpty else { 
                print("📊 No expenses found for project: \(projectId)")
                DispatchQueue.main.async {
                    self?.expenses = []
                    self?.processData()
                }
                return
            }
            
            let fetchedExpenses = docs.compactMap { doc -> Expense? in
                try? doc.data(as: Expense.self)
            }
            
            DispatchQueue.main.async {
                self?.expenses = fetchedExpenses
                self?.processData()
            }
        }
    }
    
    private func processData() {
        // Generate forecast data based on expenses
        generateForecastData()
        generateTrendsData()
        generateSummary()
    }
    
    private func generateForecastData() {
        // Generate data for the actual project timeline only
        guard let startDateString = project.startDate,
              let endDateString = project.endDate else {
            // Fallback to 6 months if dates not available
            generateFallbackForecastData()
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        
        guard let startDate = formatter.date(from: startDateString),
              let endDate = formatter.date(from: endDateString) else {
            generateFallbackForecastData()
            return
        }
        
        months = []
        perMonthBudget = []
        actuals = []
        forecast = []
        
        // Calculate project duration and monthly budget
        let projectDuration = calculateProjectDuration()
        let monthlyBudget = project.budget / Double(projectDuration)
        
        // Generate months for the actual project timeline
        let calendar = Calendar.current
        var currentDate = startDate
        
        while currentDate <= endDate {
            let monthIndex = calendar.component(.month, from: currentDate)
            let monthName = calendar.shortMonthSymbols[monthIndex - 1]
            months.append(monthName)
            perMonthBudget.append(monthlyBudget) // Same budget for all months
            
            // Get actual expenses for this month
            let actual = getActualExpenseForMonth(monthIndex: monthIndex)
            actuals.append(actual)
            
            // Generate forecast for this month
            let isCurrentOrPast = currentDate <= Date()
            if isCurrentOrPast {
                // For current and past months, forecast = actual
                forecast.append(actual)
            } else {
                // For future months, generate ML-based forecast
                let forecastValue = generateMLForecast(monthlyBudget: monthlyBudget, monthIndex: months.count - 1)
                forecast.append(forecastValue)
            }
            
            // Move to next month
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? endDate
        }
    }
    
    private func generateFallbackForecastData() {
        // Fallback to 6 months if project dates not available
        let currentDate = Date()
        let currentMonth = Calendar.current.component(.month, from: currentDate)
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        
        months = []
        perMonthBudget = []
        actuals = []
        forecast = []
        
        // Calculate project duration and monthly budget (same for all months)
        let projectDuration = calculateProjectDuration()
        let monthlyBudget = project.budget / Double(max(projectDuration, 12))
        
        // Generate 6 months: 3 historical + current + 2 future
        for i in 0..<6 {
            let monthIndex = (currentMonth - 1 - 3 + i + 12) % 12 // Ensure positive index
            let monthName = monthNames[monthIndex]
            months.append(monthName)
            perMonthBudget.append(monthlyBudget) // Same budget for all months
            
            // Determine if this is historical, current, or future month
            let isHistorical = i < 3
            let isCurrent = i == 3
            _ = i > 3
            
            if isHistorical || isCurrent {
                // For historical and current months, get actual data from expenses
                let actual = getActualExpenseForMonth(monthIndex: monthIndex + 1) // Convert to 1-based
                actuals.append(actual)
                
                if isCurrent {
                    // For current month, generate forecast based on actual so far
                    let forecastValue = generateCurrentMonthForecast(actual: actual, monthlyBudget: monthlyBudget)
                    forecast.append(forecastValue)
                } else {
                    // For historical months, forecast = actual (what was predicted)
                    forecast.append(actual)
                }
            } else {
                // For future months, no actual data yet
                actuals.append(0)
                
                // Generate ML-based forecast using historical spending patterns
                let forecastValue = generateMLForecast(monthlyBudget: monthlyBudget, monthIndex: i)
                forecast.append(forecastValue)
            }
        }
    }
    
    private func getActualExpenseForMonth(monthIndex: Int) -> Double {
        // Get actual expenses for the specific month from Firestore data
        // Only include APPROVED expenses, not pending or rejected
        let monthExpenses = expenses.filter { expense in
            let expenseMonth = getMonthFromDateString(expense.date)
            return expenseMonth == monthIndex && expense.status == .approved
        }
        
        return monthExpenses.reduce(0) { $0 + $1.amount }
    }
    
    private func generateCurrentMonthForecast(actual: Double, monthlyBudget: Double) -> Double {
        // For current month, forecast is based on actual spending so far
        if actual > 0 {
            // If we have actual data, project the rest of the month
            let daysInMonth = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
            let currentDay = Calendar.current.component(.day, from: Date())
            let remainingDays = daysInMonth - currentDay
            
            if remainingDays > 0 {
                let dailyAverage = actual / Double(currentDay)
                let projectedRemaining = dailyAverage * Double(remainingDays)
                return actual + projectedRemaining
            } else {
                return actual
            }
        } else {
            // No actual data yet, use ML-based forecast
            return generateMLForecast(monthlyBudget: monthlyBudget, monthIndex: 3) // Current month index
        }
    }
    
    private func generateMLForecast(monthlyBudget: Double, monthIndex: Int) -> Double {
        // ML-based forecasting using historical expense patterns
        let historicalActuals = actuals.filter { $0 > 0 }
        
        if historicalActuals.count < 2 {
            // Not enough data for ML, use simple average
            return monthlyBudget
        }
        
        // Calculate trend using linear regression
        let trend = calculateLinearTrend(data: historicalActuals)
        
        // Calculate seasonal patterns (if we have enough data)
        let seasonalFactor = calculateSeasonalFactor(monthIndex: monthIndex)
        
        // Calculate moving average with trend
        let movingAverage = historicalActuals.suffix(3).reduce(0, +) / Double(min(3, historicalActuals.count))
        
        // Apply trend and seasonal adjustments
        let baseForecast = movingAverage + (trend * Double(monthIndex - 2)) // Adjust for future months
        let seasonalAdjustedForecast = baseForecast * seasonalFactor
        
        // Ensure forecast is reasonable (not negative, not too far from budget)
        let minForecast = monthlyBudget * 0.5
        let maxForecast = monthlyBudget * 2.0
        
        return max(minForecast, min(maxForecast, seasonalAdjustedForecast))
    }
    
    private func calculateLinearTrend(data: [Double]) -> Double {
        // Simple linear regression to find trend
        guard data.count >= 2 else { return 0.0 }
        
        let n = Double(data.count)
        let xValues = Array(0..<data.count).map { Double($0) }
        
        let sumX = xValues.reduce(0, +)
        let sumY = data.reduce(0, +)
        let sumXY = zip(xValues, data).map { $0 * $1 }.reduce(0, +)
        let sumXX = xValues.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        return slope
    }
    
    private func calculateSeasonalFactor(monthIndex: Int) -> Double {
        // Calculate seasonal factors based on historical data
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let currentMonthName = monthNames[monthIndex]
        
        // Group expenses by month to find seasonal patterns
        var monthlyTotals: [String: Double] = [:]
        var monthlyCounts: [String: Int] = [:]
        
        for expense in expenses {
            let expenseMonth = getMonthFromDateString(expense.date)
            if expenseMonth > 0 && expenseMonth <= 12 {
                let monthName = monthNames[expenseMonth - 1]
                monthlyTotals[monthName, default: 0] += expense.amount
                monthlyCounts[monthName, default: 0] += 1
            }
        }
        
        // Calculate average spending per month
        let totalSpending = monthlyTotals.values.reduce(0, +)
        let totalMonths = monthlyCounts.values.reduce(0, +)
        let averageSpending = totalMonths > 0 ? totalSpending / Double(totalMonths) : 0
        
        // Calculate seasonal factor for current month
        if let monthTotal = monthlyTotals[currentMonthName], let monthCount = monthlyCounts[currentMonthName], monthCount > 0 {
            let monthAverage = monthTotal / Double(monthCount)
            return averageSpending > 0 ? monthAverage / averageSpending : 1.0
        }
        
        return 1.0 // Default to no seasonal adjustment
    }
    
    private func calculateProjectDuration() -> Int {
        guard let startDateString = project.startDate,
              let endDateString = project.endDate else {
            return 12 // Default to 12 months if dates not available
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        
        guard let startDate = formatter.date(from: startDateString),
              let endDate = formatter.date(from: endDateString) else {
            return 12
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: startDate, to: endDate)
        // Add 1 to include both start and end months (e.g., Jul to Nov = 5 months)
        return max(1, (components.month ?? 0) + 1)
    }
    
    
    private func getMonthFromDateString(_ dateString: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        guard let date = formatter.date(from: dateString) else { return 0 }
        return Calendar.current.component(.month, from: date)
    }
    
    private func generateTrendsData() {
        // Calculate trends from expenses
        var categoryTotals: [String: Double] = [:]
        var totalAmount: Double = 0
        
        for expense in expenses {
            // Use department as the main category
            let category = expense.department
            categoryTotals[category, default: 0] += expense.amount
            totalAmount += expense.amount
            
            // Also add individual categories from the categories array
            for subCategory in expense.categories {
                categoryTotals[subCategory, default: 0] += expense.amount / Double(expense.categories.count)
            }
        }
        
        // Only use real data - no sample data fallback
        if totalAmount == 0 {
            trends = []
            return
        }
        
        // Convert to percentages and take top 5 categories
        trends = categoryTotals.map { (category, amount) in
            (category: category, percent: (amount / totalAmount) * 100)
        }.sorted { $0.percent > $1.percent }
        .prefix(5)
        .map { $0 }
    }
    
    private func generateSummary() {
        // Use actual data from the graphs
        let actualData = customMonthlyData.filter { $0.actual != nil }
        let monthlyBudget = actualData.first?.budget ?? 0
        let totalSpent = actualData.map { $0.actual ?? 0 }.reduce(0, +)
        let averageMonthlySpending = actualData.isEmpty ? 0 : totalSpent / Double(actualData.count)
        let spendingVariance = monthlyBudget > 0 ? ((averageMonthlySpending - monthlyBudget) / monthlyBudget) * 100 : 0
        
        // Generate short and sweet summary
        var summary = ""
        
        if spendingVariance > 10 {
            let excess = averageMonthlySpending - monthlyBudget
            summary = "⚠️ OVERSPENDING: ₹\(String(format: "%.0f", excess)) above budget monthly. Need cost controls."
        } else if spendingVariance < -10 {
            let savings = monthlyBudget - averageMonthlySpending
            summary = "💰 UNDERSPENDING: ₹\(String(format: "%.0f", savings)) savings monthly. Consider expanding scope."
        } else {
            summary = "✅ ON TRACK: Spending aligns with ₹\(String(format: "%.0f", monthlyBudget)) monthly budget."
        }
        
        summary += "\n📊 Total: ₹\(String(format: "%.0f", totalSpent)) spent across \(actualData.count) months"
        summary += "\n📈 Top category: \(trends.first?.category ?? "N/A")"
        
        summaryText = summary
    }
    
    private func calculateSpendingTrend(actualData: [MonthlyData]) -> Double {
        guard actualData.count >= 2 else { return 0 }
        
        let amounts = actualData.map { $0.actual ?? 0 }
        var sumX = 0.0
        var sumY = 0.0
        var sumXY = 0.0
        var sumXX = 0.0
        
        for (index, amount) in amounts.enumerated() {
            let x = Double(index)
            let y = amount
            sumX += x
            sumY += y
            sumXY += x * y
            sumXX += x * x
        }
        
        let n = Double(amounts.count)
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        return slope
    }
    
    private func calculateAverageVariance(actuals: [Double], budgets: [Double]) -> Double {
        guard actuals.count == budgets.count && !actuals.isEmpty else { return 0 }
        
        var totalVariance = 0.0
        for i in 0..<actuals.count {
            if budgets[i] > 0 {
                let variance = ((actuals[i] - budgets[i]) / budgets[i]) * 100
                totalVariance += variance
            }
        }
        return totalVariance / Double(actuals.count)
    }
    
    private func getTrendDescription() -> String {
        let historicalActuals = actuals.filter { $0 > 0 }
        guard historicalActuals.count >= 2 else {
            return "Insufficient data for trend analysis"
        }
        
        let trend = calculateLinearTrend(data: historicalActuals)
        
        if trend > 1000 {
            return "📈 Increasing spending trend (+₹\(String(format: "%.0f", trend))/month)"
        } else if trend < -1000 {
            return "📉 Decreasing spending trend (₹\(String(format: "%.0f", abs(trend)))/month)"
        } else {
            return "📊 Stable spending pattern"
        }
    }
    
    private func getRecommendation(historicalVariance: Double, forecastVariance: Double) -> String {
        if forecastVariance > 15 {
            return "Immediate budget controls needed - high risk of overruns"
        } else if forecastVariance < -15 {
            return "Consider accelerating planned activities - significant savings predicted"
        } else if historicalVariance > 10 {
            return "Review spending patterns - consistently over budget"
        } else if historicalVariance < -10 {
            return "Excellent budget management - consider optimizing resource allocation"
        } else {
            return "Continue current spending patterns - on track"
        }
    }
    
}



extension DateFormatter {
    // simple month like "Aug"
    static let monthFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "MMM"
        return df
    }()
    // canonical key for grouping: "yyyy-MM" (keeps year info!)
    static let monthYearFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM"
        return df
    }()
    // display label for chart: "Aug 2025" or "Aug"
    static let displayMonthFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "MMM yyyy"
        return df
    }()
}

fileprivate extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: self.dateComponents([.year, .month], from: date)) ?? date
    }
}

// returns ordered first-of-month dates from (centerDate - monthsBefore) to (centerDate + monthsAfter)
func monthsRange(centerDate: Date = Date(), monthsBefore: Int, monthsAfter: Int, calendar: Calendar = .current) -> [Date] {
    guard let start = calendar.date(byAdding: .month, value: -monthsBefore, to: centerDate) else {
        return []
    }
    let startMonth = calendar.startOfMonth(for: start)
    let total = monthsBefore + monthsAfter + 1
    return (0..<total).compactMap { calendar.date(byAdding: .month, value: $0, to: startMonth) }
}
