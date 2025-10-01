//
//  AnalysisViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/1/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AnalysisViewModel: ObservableObject {
    @Published var analysisResults: AnalysisResults?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTab = 0
    
    private let analysisManager = AnalysisManager()
    private var cancellables = Set<AnyCancellable>()
    
    let tabs = ["Forecast", "Variance", "Trends"]
    
    // MARK: - Public Methods
    
    func loadAnalysis(for reportData: ReportData) {
        isLoading = true
        errorMessage = nil
        
        // Simulate async processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                let forecastData = self.analysisManager.generateForecastData(from: reportData)
                let varianceData = self.analysisManager.generateVarianceData(from: reportData)
                let trendsData = self.analysisManager.generateTrendsData(from: reportData)
                
                self.analysisResults = AnalysisResults(
                    forecastData: forecastData,
                    varianceData: varianceData,
                    trendsData: trendsData,
                    totalSpent: reportData.totalSpent,
                    totalBudget: reportData.totalBudget,
                    budgetUsagePercentage: reportData.budgetUsagePercentage
                )
                
                self.isLoading = false
            } catch {
                self.errorMessage = "Failed to generate analysis: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func refreshAnalysis(for reportData: ReportData) {
        loadAnalysis(for: reportData)
    }
    
    func selectTab(_ index: Int) {
        selectedTab = index
    }
}
