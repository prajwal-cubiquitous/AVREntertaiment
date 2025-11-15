//
//  MainReportViewModel.swift
//  AVREntertainment
//
//  Created by Auto on 1/1/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
class MainReportViewModel: ObservableObject {
    // Filter selections
    @Published var selectedProject: String = "All Projects" {
        didSet {
            Task {
                await loadStagesForProject()
                updateDataBasedOnFilters()
            }
        }
    }
    @Published var selectedStage: String = "All Stages" {
        didSet {
            Task {
                await loadDepartmentsForStage()
                updateDataBasedOnFilters()
            }
        }
    }
    @Published var selectedDepartment: String = "All Departments" {
        didSet {
            updateDataBasedOnFilters()
        }
    }
    @Published var selectedProjectStatuses: Set<String> = ["ACTIVE", "COMPLETED", "MAINTENANCE", "ARCHIVE", "SUSPENDED"] {
        didSet {
            Task {
                await loadProjects()
                updateDataBasedOnFilters()
            }
        }
    }
    @Published var startDate: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date() {
        didSet {
            Task {
                await loadProjects()
                updateDataBasedOnFilters()
            }
        }
    }
    @Published var endDate: Date = Date() {
        didSet {
            if endDate < startDate {
                // Auto-adjust start date if end date is before it
                startDate = endDate
            }
            Task {
                await loadProjects()
                updateDataBasedOnFilters()
            }
        }
    }
    
    // Filter options
    @Published var projectOptions: [String] = ["All Projects"]
    @Published var stageOptions: [String] = ["All Stages"]
    @Published var departmentOptions: [String] = ["All Departments"]
    @Published var projectStatusOptions: [String] = ["ACTIVE", "COMPLETED", "MAINTENANCE", "ARCHIVE", "SUSPENDED"]
    
    // Computed property for display text
    var selectedStatusesDisplayText: String {
        if selectedProjectStatuses.count == projectStatusOptions.count {
            return "ALL Status"
        } else if selectedProjectStatuses.isEmpty {
            return "No Status"
        } else if selectedProjectStatuses.count == 1 {
            return selectedProjectStatuses.first ?? "No Status"
        } else {
            return "\(selectedProjectStatuses.count) Selected"
        }
    }
    
    // Internal data storage
    @Published var projects: [Project] = []
    @Published var phases: [Phase] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var customerId: String?
    
    // Project ID mapping (project name -> project ID)
    private var projectIdMap: [String: String] = [:]
    
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
    
    // MARK: - Data Loading
    
    /// Load all projects and populate the project dropdown
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch customer ID
            customerId = try await FirebasePathHelper.shared.fetchEffectiveUserID()
            
            // Load projects
            await loadProjects()
            
            // Load sample chart data (for now)
            loadSampleChartData()
            
        } catch {
            print("Error loading data: \(error)")
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Load projects from Firestore with status and date filtering
    private func loadProjects() async {
        guard let customerId = customerId else {
            print("Error: Customer ID not available")
            return
        }
        
        do {
            let snapshot = try await FirebasePathHelper.shared
                .projectsCollection(customerId: customerId)
                .getDocuments()
            
            var projectsList: [Project] = []
            var projectNames: [String] = ["All Projects"]
            var projectMap: [String: String] = [:]
            
            // Date formatter for parsing project dates
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            
            // Calendar for date comparisons
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: startDate)
            let endOfDay = calendar.startOfDay(for: endDate)
            
            for doc in snapshot.documents {
                if var project = try? doc.data(as: Project.self) {
                    project.id = doc.documentID
                    
                    // Filter by status - check if project status is in selected statuses
                    // Handle SUSPENDED status: check both status field and isSuspended flag
                    var statusMatches = false
                    
                    // Check if project's status field matches any selected status
                    if selectedProjectStatuses.contains(project.status) {
                        statusMatches = true
                    }
                    
                    // Special handling for SUSPENDED: check isSuspended flag
                    // A project can be suspended regardless of its status field
                    // If SUSPENDED is selected, include all suspended projects
                    if selectedProjectStatuses.contains("SUSPENDED") && project.isSuspended == true {
                        statusMatches = true
                    }
                    
                    if !statusMatches {
                        continue
                    }
                    
                    // Filter by date range (check if plannedDate or maintenanceDate falls within range)
                    var dateMatches = false
                    
                    // Check plannedDate
                    if let plannedDateStr = project.plannedDate,
                       let plannedDate = dateFormatter.date(from: plannedDateStr) {
                        let plannedStartOfDay = calendar.startOfDay(for: plannedDate)
                        if plannedStartOfDay >= startOfDay && plannedStartOfDay <= endOfDay {
                            dateMatches = true
                        }
                    }
                    
                    // Check maintenanceDate
                    if !dateMatches, let maintenanceDateStr = project.maintenanceDate,
                       let maintenanceDate = dateFormatter.date(from: maintenanceDateStr) {
                        let maintenanceStartOfDay = calendar.startOfDay(for: maintenanceDate)
                        if maintenanceStartOfDay >= startOfDay && maintenanceStartOfDay <= endOfDay {
                            dateMatches = true
                        }
                    }
                    
                    // If no dates match, skip this project
                    if !dateMatches {
                        continue
                    }
                    
                    projectsList.append(project)
                    projectNames.append(project.name)
                    projectMap[project.name] = doc.documentID
                }
            }
            
            await MainActor.run {
                self.projects = projectsList
                self.projectOptions = projectNames
                self.projectIdMap = projectMap
                
                // Reset project selection if current selection is not in the filtered list
                if !projectNames.contains(selectedProject) {
                    self.selectedProject = "All Projects"
                } else {
                    // Reload stages for the currently selected project
                    Task {
                        await loadStagesForProject()
                    }
                }
            }
        } catch {
            print("Error loading projects: \(error)")
            errorMessage = "Failed to load projects"
        }
    }
    
    /// Load stages (phases) for the selected project
    private func loadStagesForProject() async {
        guard let customerId = customerId else { return }
        
        do {
            var allPhases: [Phase] = []
            var uniqueStageNames: Set<String> = []
            
            if selectedProject == "All Projects" {
                // Load phases from all projects
                for project in projects {
                    guard let projectId = project.id else { continue }
                    
                    let snapshot = try await FirebasePathHelper.shared
                        .phasesCollection(customerId: customerId, projectId: projectId)
                        .order(by: "phaseNumber")
                        .getDocuments()
                    
                    for doc in snapshot.documents {
                        if let phase = try? doc.data(as: Phase.self) {
                            allPhases.append(phase)
                            uniqueStageNames.insert(phase.phaseName)
                        }
                    }
                }
            } else {
                // Load phases from selected project only
                guard let projectId = projectIdMap[selectedProject] else {
                    print("Error: Project ID not found for \(selectedProject)")
                    return
                }
                
                let snapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .order(by: "phaseNumber")
                    .getDocuments()
                
                for doc in snapshot.documents {
                    if let phase = try? doc.data(as: Phase.self) {
                        allPhases.append(phase)
                        uniqueStageNames.insert(phase.phaseName)
                    }
                }
            }
            
            // Convert Set to sorted array and add "All Stages" at the beginning
            var stageNames = Array(uniqueStageNames).sorted()
            stageNames.insert("All Stages", at: 0)
            
            await MainActor.run {
                self.phases = allPhases
                self.stageOptions = stageNames
                // Reset stage selection if current stage is not in the new list
                if !stageNames.contains(selectedStage) {
                    self.selectedStage = "All Stages"
                }
            }
        } catch {
            print("Error loading stages: \(error)")
            errorMessage = "Failed to load stages"
        }
    }
    
    /// Load departments for the selected stage
    private func loadDepartmentsForStage() async {
        // Extract department names from phases
        var uniqueDepartmentNames: Set<String> = []
        
        if selectedStage == "All Stages" {
            // Extract departments from all phases
            for phase in phases {
                for deptKey in phase.departments.keys {
                    let displayName: String
                    if let underscoreIndex = deptKey.firstIndex(of: "_") {
                        // New format: remove "phaseId_" prefix
                        displayName = String(deptKey[deptKey.index(after: underscoreIndex)...])
                    } else {
                        // Old format: use as is
                        displayName = deptKey
                    }
                    uniqueDepartmentNames.insert(displayName)
                }
            }
        } else {
            // Extract departments from selected stage only
            let selectedPhases = phases.filter { $0.phaseName == selectedStage }
            
            for phase in selectedPhases {
                for deptKey in phase.departments.keys {
                    let displayName: String
                    if let underscoreIndex = deptKey.firstIndex(of: "_") {
                        // New format: remove "phaseId_" prefix
                        displayName = String(deptKey[deptKey.index(after: underscoreIndex)...])
                    } else {
                        // Old format: use as is
                        displayName = deptKey
                    }
                    uniqueDepartmentNames.insert(displayName)
                }
            }
        }
        
        // Convert Set to sorted array and add "All Departments" at the beginning
        var sortedDepartments = Array(uniqueDepartmentNames).sorted()
        sortedDepartments.insert("All Departments", at: 0)
        
        await MainActor.run {
            self.departmentOptions = sortedDepartments
            // Reset department selection if current department is not in the new list
            if !sortedDepartments.contains(selectedDepartment) {
                self.selectedDepartment = "All Departments"
            }
        }
    }
    
    /// Load sample chart data (to be replaced with real data later)
    private func loadSampleChartData() {
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

