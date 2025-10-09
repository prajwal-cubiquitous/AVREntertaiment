//
//  MonthlyData.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/9/25.
//
import Foundation

struct MonthlyData: Identifiable, Equatable {
    let id = UUID()
    let month: String
    let budget: Double
    let actual: Double?
    let forecast: Double?

}

extension MonthlyData {
    static let sampleData: [MonthlyData] = [
        .init(month: "Jul", budget: 10000, actual: 9500, forecast: 10200),
        .init(month: "Aug", budget: 10000, actual: 10500, forecast: 9800),
        .init(month: "Sep", budget: 10000, actual: 9700, forecast: 10100),
        .init(month: "Oct", budget: 10000, actual: 11000, forecast: 10800),
        .init(month: "Nov", budget: 10000, actual: nil, forecast: 11200),
        .init(month: "Dec", budget: 10000, actual: nil, forecast: 11500)
    ]
}

