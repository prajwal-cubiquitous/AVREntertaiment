//
//  ForecastEntry.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/8/25.
//
import Foundation

struct CategoryTrend: Codable {
    var name: String
    var value: Double
}
struct ForecastEntry: Codable, Identifiable {
    var id: String { month }
    var month: String
    var budget: Double
    var actual: Double
    var forecast: Double
}
struct AnalyticsSummary: Codable {
    var summaryText: String
    var forecast: [ForecastEntry]
    var variance: [String: String]
    var trends: [CategoryTrend]
}

// MARK: - API Request Models
struct AnalyticsRequest: Codable {
    var forecast: [ForecastEntry]
    var trends: [CategoryTrend]
}

