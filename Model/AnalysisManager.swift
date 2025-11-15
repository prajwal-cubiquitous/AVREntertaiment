//
//  AnalysisManager.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/1/25.
//

import Foundation
import SwiftUI
import Charts

// MARK: - Analysis Manager
@MainActor
class AnalysisManager: ObservableObject {
    
    // MARK: - Public Methods
    
    /// Generates forecast data based on project report data
    func generateForecastData(from reportData: ReportData) -> ForecastData {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        
        // Generate 6 months starting from current month
        let months = (0..<6).map { monthOffset in
            let targetMonth = ((currentMonth - 1 + monthOffset) % 12) + 1
            return monthName(for: targetMonth)
        }
        
        let totalBudget = reportData.totalBudget
        let totalSpent = reportData.totalSpent
        
        // Calculate spending velocity based on actual data
        let historicalMonths = 6.0
        let monthlyAverage = totalSpent > 0 ? totalSpent / historicalMonths : totalBudget / 12.0
        
        // Generate budget data (linear distribution based on project timeline)
        let budgetData = months.enumerated().map { index, _ in
            totalBudget * Double(index + 1) / Double(months.count)
        }
        
        // Generate actual data based on real spending patterns
        let actualData = months.enumerated().map { index, _ in
            if index < 3 {
                // Historical data (first 3 months) - distribute actual spending
                return totalSpent * Double(index + 1) / 3.0
            } else {
                // Projected actual data based on current spending rate
                return totalSpent + (monthlyAverage * Double(index - 2))
            }
        }
        
        // Generate forecast data based on spending velocity and remaining budget
        let remainingBudget = totalBudget - totalSpent
        let remainingMonths = Double(months.count) - 3.0
        let forecastMonthlySpend = remainingMonths > 0 ? remainingBudget / remainingMonths : 0.0
        
        let forecastData = months.enumerated().map { index, _ in
            if index < 3 {
                // Historical actual data
                return actualData[index]
            } else {
                // Forecast based on remaining budget and spending velocity
                let projectedSpend = totalSpent + (forecastMonthlySpend * Double(index - 2))
                return min(projectedSpend, totalBudget) // Cap at total budget
            }
        }
        
        let forecastTotal = forecastData.last ?? 0.0
        
        return ForecastData(
            months: months,
            budgetData: budgetData,
            actualData: actualData,
            forecastData: forecastData,
            forecastTotal: forecastTotal
        )
    }
    
    /// Generates variance analysis data
    func generateVarianceData(from reportData: ReportData) -> VarianceData {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        
        // Generate 5 months starting from current month
        let months = (0..<5).map { monthOffset in
            let targetMonth = ((currentMonth - 1 + monthOffset) % 12) + 1
            return monthName(for: targetMonth)
        }
        
        let totalBudget = reportData.totalBudget
        let totalSpent = reportData.totalSpent
        
        // Calculate spending velocity based on actual data
        let historicalMonths = 5.0
        let monthlyAverage = totalSpent > 0 ? totalSpent / historicalMonths : totalBudget / 12.0
        
        // Generate budget data (linear distribution based on project timeline)
        let budgetData = months.enumerated().map { index, _ in
            totalBudget * Double(index + 1) / Double(months.count)
        }
        
        // Generate actual data based on real spending patterns
        let actualData = months.enumerated().map { index, _ in
            if index < 3 {
                // Historical data (first 3 months) - distribute actual spending
                return totalSpent * Double(index + 1) / 3.0
            } else {
                // Projected actual data based on current spending rate
                return totalSpent + (monthlyAverage * Double(index - 2))
            }
        }
        
        // Generate forecast data based on spending velocity and remaining budget
        let remainingBudget = totalBudget - totalSpent
        let remainingMonths = Double(months.count) - 3.0
        let forecastMonthlySpend = remainingMonths > 0 ? remainingBudget / remainingMonths : 0.0
        
        let forecastData = months.enumerated().map { index, _ in
            if index < 3 {
                // Historical actual data
                return actualData[index]
            } else {
                // Forecast based on remaining budget and spending velocity
                let projectedSpend = totalSpent + (forecastMonthlySpend * Double(index - 2))
                return min(projectedSpend, totalBudget) // Cap at total budget
            }
        }
        
        let forecastTotal = forecastData.last ?? 0.0
        
        return VarianceData(
            months: months,
            budgetData: budgetData,
            actualData: actualData,
            forecastData: forecastData,
            forecastTotal: forecastTotal
        )
    }
    
    /// Generates trends analysis data for pie charts
    func generateTrendsData(from reportData: ReportData) -> [PieChartItem] {
        let totalSpent = reportData.totalSpent
        let expensesByCategory = reportData.expensesByCategory
        let expensesByDepartment = reportData.expensesByDepartment
        
        // If we have category data, use it; otherwise fall back to department data
        let dataSource: [String: Double]
        if !expensesByCategory.isEmpty {
            dataSource = expensesByCategory
        } else if !expensesByDepartment.isEmpty {
            dataSource = expensesByDepartment
        } else {
            // Fallback to default categories if no data
            dataSource = [
                "Travel": totalSpent * 0.45,
                "Meals": totalSpent * 0.30,
                "Misc": totalSpent * 0.25
            ]
        }
        
        // Convert to pie chart items with dynamic colors
        let pieChartItems = dataSource.enumerated().map { index, element in
            let (name, amount) = element
            let percentage = totalSpent > 0 ? (amount / totalSpent) * 100 : 0.0
            let color = getDynamicColor(for: name, at: index)
            
            return PieChartItem(
                label: name,
                percentage: percentage,
                color: color
            )
        }.sorted { $0.percentage > $1.percentage }
        
        // If we have more than 5 categories, group smaller ones into "Others"
        if pieChartItems.count > 5 {
            let topItems = Array(pieChartItems.prefix(4))
            let othersItems = Array(pieChartItems.dropFirst(4))
            let othersTotal = othersItems.reduce(0) { $0 + $1.percentage }
            
            var finalItems = topItems
            if othersTotal > 0 {
                finalItems.append(PieChartItem(
                    label: "Others",
                    percentage: othersTotal,
                    color: Color.gray
                ))
            }
            return finalItems
        }
        
        return pieChartItems
    }
    
    // MARK: - Private Helper Methods
    
    private func monthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let date = Calendar.current.date(from: DateComponents(month: month)) ?? Date()
        return formatter.string(from: date)
    }
    
    private func getDynamicColor(for name: String, at index: Int) -> Color {
        let colorPalette: [Color] = [
            .blue, .green, .orange, .red, .purple,
            .brown, .pink, .cyan, .mint, .indigo,
            .teal, .yellow, .gray, .primary, .secondary
        ]
        
        let colorIndex = index % colorPalette.count
        return colorPalette[colorIndex]
    }
}