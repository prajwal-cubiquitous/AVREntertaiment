//
//  MainReportViewModel.swift
//  AVREntertainment
//
//  Created by Auto on 1/1/25.
//

import Foundation
import SwiftUI

@MainActor
class MainReportViewModel: ObservableObject {
    // Filter selections
    @Published var selectedProject: String = "All Projects" {
        didSet {
            updateDataBasedOnFilters()
        }
    }
    @Published var selectedStage: String = "All Stages" {
        didSet {
            updateDataBasedOnFilters()
        }
    }
    @Published var selectedDepartment: String = "All Departments" {
        didSet {
            updateDataBasedOnFilters()
        }
    }
    
    // Filter options
    @Published var projectOptions: [String] = ["All Projects"]
    @Published var stageOptions: [String] = ["All Stages", "Excavation", "Sub-structure", "Super-structure", "Finishing", "External Works"]
    @Published var departmentOptions: [String] = ["All Departments", "Civil", "MEP", "Finishes", "Services"]
    
    // KPI values
    @Published var totalBudget: Double = 120.0
    @Published var totalSpent: Double = 95.0
    @Published var remaining: Double = 25.0
    
    // Chart data models
    struct CostTrendData: Identifiable {
        let id = UUID()
        let month: String
        let value: Double
    }
    
    struct StageBudgetData: Identifiable {
        let id = UUID()
        let stage: String
        let budget: Double
        let actual: Double
    }
    
    struct ProjectWiseData: Identifiable {
        let id = UUID()
        let project: String
        let budget: Double
        let actual: Double
    }
    
    struct StageAcrossProjectsData: Identifiable {
        let id = UUID()
        let project: String
        let budget: Double
        let actual: Double
    }
    
    struct SubCategorySpendData: Identifiable {
        let id = UUID()
        let category: String
        let value: Double
    }
    
    struct StatusCostData: Identifiable {
        let id = UUID()
        let status: String
        let value: Double
    }
    
    struct OverrunData: Identifiable {
        let id = UUID()
        let stage: String
        let progress: Double
        let overrun: Double
    }
    
    struct BurnRateData: Identifiable {
        let id = UUID()
        let project: String
        let rate: Double
    }
    
    struct ActiveProjectsData: Identifiable {
        let id = UUID()
        let month: String
        let count: Int
    }
    
    struct StageProgressData: Identifiable {
        let id = UUID()
        let stage: String
        let inProgress: Double
        let handover: Double
        let delayed: Double
        let complete: Double
    }
    
    struct SubCategoryActivityData: Identifiable {
        let id = UUID()
        let category: String
        let count: Int
    }
    
    struct DelayCorrelationData: Identifiable {
        let id = UUID()
        let project: String
        let delayDays: Double
        let extraCost: Double
    }
    
    struct SuspensionReasonData: Identifiable {
        let id = UUID()
        let reason: String
        let count: Int
    }
    
    // Published chart data
    @Published var costTrendData: [CostTrendData] = []
    @Published var stageBudgetData: [StageBudgetData] = []
    @Published var projectWiseData: [ProjectWiseData] = []
    @Published var stageAcrossProjectsData: [StageAcrossProjectsData] = []
    @Published var subCategorySpendData: [SubCategorySpendData] = []
    @Published var statusCostData: [StatusCostData] = []
    @Published var overrunData: [OverrunData] = []
    @Published var burnRateData: [BurnRateData] = []
    @Published var activeProjectsData: [ActiveProjectsData] = []
    @Published var stageProgressData: [StageProgressData] = []
    @Published var subCategoryActivityData: [SubCategoryActivityData] = []
    @Published var delayCorrelationData: [DelayCorrelationData] = []
    @Published var suspensionReasonData: [SuspensionReasonData] = []
    
    // Computed properties for formatted values
    var totalBudgetFormatted: String {
        formatCr(totalBudget)
    }
    
    var totalSpentFormatted: String {
        formatCr(totalSpent)
    }
    
    var remainingFormatted: String {
        formatCr(remaining)
    }
    
    var costTrendTotal: String {
        let total = costTrendData.reduce(0) { $0 + $1.value }
        return formatCr(total)
    }
    
    // Helper function to format currency in Cr (Crores)
    private func formatCr(_ value: Double) -> String {
        return "₹\(String(format: "%.1f", value)) Cr"
    }
    
    // Load data (sample data for now)
    func loadData() async {
        // Sample data matching the HTML structure
        costTrendData = [
            CostTrendData(month: "Apr", value: 12.4),
            CostTrendData(month: "May", value: 14.2),
            CostTrendData(month: "Jun", value: 13.8),
            CostTrendData(month: "Jul", value: 15.6),
            CostTrendData(month: "Aug", value: 17.1),
            CostTrendData(month: "Sep", value: 18.9)
        ]
        
        stageBudgetData = [
            StageBudgetData(stage: "Excavation", budget: 6.0, actual: 5.4),
            StageBudgetData(stage: "Sub-structure", budget: 18.0, actual: 19.2),
            StageBudgetData(stage: "Super-structure", budget: 40.0, actual: 38.5),
            StageBudgetData(stage: "Finishing", budget: 22.0, actual: 23.1),
            StageBudgetData(stage: "External Works", budget: 10.0, actual: 11.4)
        ]
        
        projectWiseData = [
            ProjectWiseData(project: "Aurum Heights", budget: 35.0, actual: 34.0),
            ProjectWiseData(project: "Tracura Residency", budget: 27.0, actual: 26.5),
            ProjectWiseData(project: "Lotus Enclave", budget: 33.0, actual: 34.5)
        ]
        
        stageAcrossProjectsData = []
        
        subCategorySpendData = [
            SubCategorySpendData(category: "Civil Works", value: 58.0),
            SubCategorySpendData(category: "Labour", value: 34.0),
            SubCategorySpendData(category: "Steel", value: 28.0),
            SubCategorySpendData(category: "Cement", value: 24.0),
            SubCategorySpendData(category: "MEP", value: 19.0)
        ]
        
        statusCostData = [
            StatusCostData(status: "Active", value: 72.0),
            StatusCostData(status: "On Hold", value: 18.0),
            StatusCostData(status: "Delayed", value: 26.0),
            StatusCostData(status: "Completed", value: 40.0)
        ]
        
        overrunData = [
            OverrunData(stage: "Excavation", progress: 25.0, overrun: -5.0),
            OverrunData(stage: "Sub-structure", progress: 55.0, overrun: 8.0),
            OverrunData(stage: "Super-structure", progress: 70.0, overrun: 12.0),
            OverrunData(stage: "Finishing", progress: 40.0, overrun: 3.0),
            OverrunData(stage: "External Works", progress: 15.0, overrun: 15.0)
        ]
        
        burnRateData = [
            BurnRateData(project: "Aurum Heights", rate: 0.58),
            BurnRateData(project: "Tracura Residency", rate: 0.42),
            BurnRateData(project: "Lotus Enclave", rate: 0.37)
        ]
        
        activeProjectsData = [
            ActiveProjectsData(month: "Apr", count: 4),
            ActiveProjectsData(month: "May", count: 6),
            ActiveProjectsData(month: "Jun", count: 7),
            ActiveProjectsData(month: "Jul", count: 9),
            ActiveProjectsData(month: "Aug", count: 10),
            ActiveProjectsData(month: "Sep", count: 12)
        ]
        
        stageProgressData = [
            StageProgressData(stage: "In Progress", inProgress: 60.0, handover: 10.0, delayed: 10.0, complete: 20.0),
            StageProgressData(stage: "HandOver", inProgress: 40.0, handover: 20.0, delayed: 10.0, complete: 30.0),
            StageProgressData(stage: "Planned", inProgress: 10.0, handover: 0.0, delayed: 0.0, complete: 90.0),
            StageProgressData(stage: "Complete", inProgress: 0.0, handover: 0.0, delayed: 0.0, complete: 100.0)
        ]
        
        subCategoryActivityData = [
            SubCategoryActivityData(category: "Labour", count: 84),
            SubCategoryActivityData(category: "MEP Works", count: 52),
            SubCategoryActivityData(category: "Equipment", count: 31),
            SubCategoryActivityData(category: "Finishes", count: 40)
        ]
        
        delayCorrelationData = [
            DelayCorrelationData(project: "Aurum Heights", delayDays: 18.0, extraCost: 1.8),
            DelayCorrelationData(project: "Tracura Residency", delayDays: 24.0, extraCost: 2.2),
            DelayCorrelationData(project: "Lotus Enclave", delayDays: 10.0, extraCost: 0.7)
        ]
        
        suspensionReasonData = [
            SuspensionReasonData(reason: "Payment Milestone Delay", count: 5),
            SuspensionReasonData(reason: "Design Change", count: 3),
            SuspensionReasonData(reason: "Material Shortage", count: 4),
            SuspensionReasonData(reason: "Approval Pending", count: 2)
        ]
        
        // Update KPI values based on filters
        updateKPIs()
    }
    
    private func updateKPIs() {
        // This would calculate KPIs based on selected filters
        // For now, using sample data
        totalBudget = 120.0
        totalSpent = 95.0
        remaining = max(totalBudget - totalSpent, 0)
    }
    
    private func updateDataBasedOnFilters() {
        // Update chart data based on selected filters
        // This would filter the data based on project, stage, and department selections
        // For now, keeping sample data structure
        updateKPIs()
        
        // Update stage across projects data when stage is selected
        if selectedStage != "All Stages" {
            stageAcrossProjectsData = [
                StageAcrossProjectsData(project: "Aurum Heights", budget: 2.0, actual: 1.8),
                StageAcrossProjectsData(project: "Tracura Residency", budget: 1.5, actual: 1.6),
                StageAcrossProjectsData(project: "Lotus Enclave", budget: 2.5, actual: 2.0)
            ]
        } else {
            stageAcrossProjectsData = []
        }
    }
}

