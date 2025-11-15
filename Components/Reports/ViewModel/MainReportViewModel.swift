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
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var customerId: String?
    
    // Project ID mapping (project name -> project ID)
    private var projectIdMap: [String: String] = [:]
    
    // KPI values (will be calculated based on filters)
    @Published var totalBudget: Double = 0.0
    @Published var totalSpent: Double = 0.0
    @Published var remaining: Double = 0.0
    
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
    
    // Computed property to check if date range is greater than 6 months
    var isDateRangeGreaterThan6Months: Bool {
        let calendar = Calendar.current
        let months = calendar.dateComponents([.month], from: startDate, to: endDate).month ?? 0
        return months > 6
    }
    
    // Helper function to format currency with appropriate units
    // 1-999: actual numbers
    // 1000-99999: thousands (k) with 2 decimals
    // 100000-9999999: lakhs with 2 decimals
    // 10000000+: crores (Cr) with 2 decimals
    private func formatCr(_ value: Double) -> String {
        let absValue = abs(value)
        
        if absValue < 1000 {
            // 1 to 999: show actual numbers
            return "₹\(String(format: "%.0f", value))"
        } else if absValue < 100000 {
            // 1000 to 99999: show in thousands (k) with 2 decimals
            let thousands = value / 1000.0
            return "₹\(String(format: "%.2f", thousands))k"
        } else if absValue < 10000000 {
            // 100000 to 9999999: show in lakhs with 2 decimals
            let lakhs = value / 100000.0
            return "₹\(String(format: "%.2f", lakhs)) lakhs"
        } else {
            // 10000000+: show in crores (Cr) with 2 decimals
            let crores = value / 10000000.0
            return "₹\(String(format: "%.2f", crores)) Cr"
        }
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
            
            // Calculate initial budget metrics
            await calculateBudgetMetrics()
            
            // Calculate initial cost trend
            await calculateCostTrend()
            
            // Calculate initial stage budget vs actual
            await calculateStageBudgetVsActual()
            
            // Calculate initial project-wise budget vs actual
            await calculateProjectWiseBudgetVsActual()
            
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
                    
                    // IMPORTANT: If a project is suspended (isSuspended == true),
                    // it should ONLY show if "SUSPENDED" is selected, regardless of status field
                    if project.isSuspended == true {
                        // Project is suspended - only show if SUSPENDED is selected
                        if selectedProjectStatuses.contains("SUSPENDED") {
                            statusMatches = true
                        }
                        // If SUSPENDED is not selected, statusMatches remains false
                    } else {
                        // Project is not suspended - check if status field matches selected statuses
                        // Also handle case where status field is "SUSPENDED" but isSuspended is false
                        if project.status == "SUSPENDED" {
                            // Status field is SUSPENDED - only show if SUSPENDED is selected
                            if selectedProjectStatuses.contains("SUSPENDED") {
                                statusMatches = true
                            }
                        } else {
                            // Normal status check
                            if selectedProjectStatuses.contains(project.status) {
                                statusMatches = true
                            }
                        }
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
    
    /// Calculate cost trend data based on selected filters
    private func calculateCostTrend() async {
        guard let customerId = customerId else {
            await MainActor.run {
                costTrendData = []
            }
            return
        }
        
        // Determine which projects to include
        let projectsToProcess: [Project]
        if selectedProject == "All Projects" {
            projectsToProcess = projects
        } else {
            projectsToProcess = projects.filter { $0.name == selectedProject }
        }
        
        // Date formatter for parsing expense dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        // Month formatter for grouping
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM" // Short month name (Jan, Feb, etc.)
        
        // Year-month formatter for multi-year ranges
        let yearMonthFormatter = DateFormatter()
        yearMonthFormatter.dateFormat = "MMM yyyy"
        
        let calendar = Calendar.current
        
        // Determine if we need year in the format
        let needsYear = calendar.component(.year, from: startDate) != calendar.component(.year, from: endDate)
        let formatterToUse = needsYear ? yearMonthFormatter : monthFormatter
        
        var monthlyTotals: [String: Double] = [:]
        
        // Process each project
        for project in projectsToProcess {
            guard let projectId = project.id else { continue }
            
            do {
                // Load expenses for this project
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .getDocuments()
                
                // Process each approved expense
                for expenseDoc in expensesSnapshot.documents {
                    guard let expense = try? expenseDoc.data(as: Expense.self) else { continue }
                    
                    // Parse expense date
                    guard let expenseDate = dateFormatter.date(from: expense.date) else { continue }
                    
                    // Filter by date range
                    let expenseStartOfDay = calendar.startOfDay(for: expenseDate)
                    let startOfDay = calendar.startOfDay(for: startDate)
                    let endOfDay = calendar.startOfDay(for: endDate)
                    
                    if expenseStartOfDay < startOfDay || expenseStartOfDay > endOfDay {
                        continue
                    }
                    
                    // Filter by stage (phase name)
                    if selectedStage != "All Stages" {
                        if let expensePhaseName = expense.phaseName {
                            if expensePhaseName != selectedStage {
                                continue
                            }
                        } else {
                            continue
                        }
                    }
                    
                    // Extract department name from expense
                    let expenseDepartmentName: String
                    if let underscoreIndex = expense.department.firstIndex(of: "_") {
                        expenseDepartmentName = String(expense.department[expense.department.index(after: underscoreIndex)...])
                    } else {
                        expenseDepartmentName = expense.department
                    }
                    
                    // Filter by department
                    if selectedDepartment != "All Departments" && expenseDepartmentName != selectedDepartment {
                        continue
                    }
                    
                    // Group by month using the same formatter as we'll use for display
                    let monthKey = formatterToUse.string(from: expenseDate)
                    monthlyTotals[monthKey, default: 0] += expense.amount
                }
            } catch {
                print("Error calculating cost trend for project \(projectId): \(error)")
            }
        }
        
        // Generate all months in the date range (with year if needed for clarity)
        var allMonths: [String] = []
        var currentDate = calendar.startOfDay(for: startDate)
        let endDateDay = calendar.startOfDay(for: endDate)
        
        while currentDate <= endDateDay {
            let monthKey = formatterToUse.string(from: currentDate)
            if !allMonths.contains(monthKey) {
                allMonths.append(monthKey)
            }
            // Move to first day of next month
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) {
                currentDate = calendar.startOfDay(for: nextMonth)
            } else {
                break
            }
        }
        
        // Create cost trend data array with all months (including zeros for months with no expenses)
        let trendData = allMonths.map { month in
            let value = monthlyTotals[month] ?? 0.0
            return CostTrendData(month: month, value: value)
        }
        
        // Debug: Print the data to verify values
        print("📊 Cost Trend Data:")
        for data in trendData {
            print("  \(data.month): ₹\(data.value)")
        }
        
        await MainActor.run {
            costTrendData = trendData
        }
    }
    
    /// Load sample chart data (to be replaced with real data later)
    private func loadSampleChartData() {
        // Sample data for other charts (cost trend and stage budget vs actual are now calculated from real data)
        
        // stageBudgetData is now calculated from real data in calculateStageBudgetVsActual()
        // projectWiseData is now calculated from real data in calculateProjectWiseBudgetVsActual()
        
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
    
    /// Calculate and update KPI values (Total Budget, Total Spent, Remaining) based on selected filters
    private func updateKPIs() {
        Task {
            await calculateBudgetMetrics()
        }
    }
    
    /// Calculate budget metrics based on selected project, stage, and department filters
    private func calculateBudgetMetrics() async {
        guard let customerId = customerId else {
            await MainActor.run {
                totalBudget = 0
                totalSpent = 0
                remaining = 0
            }
            return
        }
        
        // Determine which projects to include
        let projectsToProcess: [Project]
        if selectedProject == "All Projects" {
            projectsToProcess = projects
        } else {
            // Find the selected project
            projectsToProcess = projects.filter { $0.name == selectedProject }
        }
        
        var calculatedBudget: Double = 0
        var calculatedSpent: Double = 0
        
        // Process each project
        for project in projectsToProcess {
            guard let projectId = project.id else { continue }
            
            // Load phases for this project
            do {
                let phasesSnapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .getDocuments()
                
                // Process each phase
                for phaseDoc in phasesSnapshot.documents {
                    guard let phase = try? phaseDoc.data(as: Phase.self) else { continue }
                    let phaseId = phaseDoc.documentID
                    
                    // Filter by stage (phase name)
                    if selectedStage != "All Stages" && phase.phaseName != selectedStage {
                        continue
                    }
                    
                    // Process departments in this phase
                    for (deptKey, budgetAmount) in phase.departments {
                        // Extract department name (handle both "phaseId_departmentName" and "departmentName" formats)
                        let departmentName: String
                        if let underscoreIndex = deptKey.firstIndex(of: "_") {
                            // New format: remove "phaseId_" prefix
                            departmentName = String(deptKey[deptKey.index(after: underscoreIndex)...])
                        } else {
                            // Old format: use as is
                            departmentName = deptKey
                        }
                        
                        // Filter by department
                        if selectedDepartment != "All Departments" && departmentName != selectedDepartment {
                            continue
                        }
                        
                        // Add to total budget
                        calculatedBudget += budgetAmount
                    }
                }
                
                // Load expenses for this project
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .getDocuments()
                
                // Process each approved expense
                for expenseDoc in expensesSnapshot.documents {
                    guard let expense = try? expenseDoc.data(as: Expense.self) else { continue }
                    
                    // Filter by stage (phase name) - use phaseName from expense if available
                    if selectedStage != "All Stages" {
                        // Use phaseName from expense if available, otherwise skip if stage filter is active
                        if let expensePhaseName = expense.phaseName {
                            if expensePhaseName != selectedStage {
                                continue
                            }
                        } else {
                            // If expense doesn't have phaseName and stage filter is active, skip it
                            continue
                        }
                    }
                    
                    // Extract department name from expense
                    let expenseDepartmentName: String
                    if let underscoreIndex = expense.department.firstIndex(of: "_") {
                        // New format: remove "phaseId_" prefix
                        expenseDepartmentName = String(expense.department[expense.department.index(after: underscoreIndex)...])
                    } else {
                        // Old format: use as is
                        expenseDepartmentName = expense.department
                    }
                    
                    // Filter by department
                    if selectedDepartment != "All Departments" && expenseDepartmentName != selectedDepartment {
                        continue
                    }
                    
                    // Add to total spent
                    calculatedSpent += expense.amount
                }
            } catch {
                print("Error calculating budget metrics for project \(projectId): \(error)")
            }
        }
        
        // Update published properties on main thread
        // Store values in actual currency (rupees), not crores
        await MainActor.run {
            totalBudget = calculatedBudget
            totalSpent = calculatedSpent
            remaining = max(totalBudget - totalSpent, 0)
        }
    }
    
    /// Calculate stage budget vs actual data based on selected filters
    private func calculateStageBudgetVsActual() async {
        guard let customerId = customerId else {
            await MainActor.run {
                stageBudgetData = []
            }
            return
        }
        
        // Determine which projects to include
        let projectsToProcess: [Project]
        if selectedProject == "All Projects" {
            projectsToProcess = projects
        } else {
            projectsToProcess = projects.filter { $0.name == selectedProject }
        }
        
        // Date formatter for parsing expense dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        let calendar = Calendar.current
        var phaseDataMap: [String: (budget: Double, actual: Double)] = [:] // phaseName -> (budget, actual)
        
        // Process each project
        for project in projectsToProcess {
            guard let projectId = project.id else { continue }
            
            do {
                // Load phases for this project
                let phasesSnapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .getDocuments()
                
                // Process each phase
                for phaseDoc in phasesSnapshot.documents {
                    guard let phase = try? phaseDoc.data(as: Phase.self) else { continue }
                    let phaseId = phaseDoc.documentID
                    let phaseName = phase.phaseName
                    
                    // Filter by stage (phase name) - if a specific stage is selected, only include that
                    if selectedStage != "All Stages" && phaseName != selectedStage {
                        continue
                    }
                    
                    // Calculate budget for this phase (sum of all departments)
                    var phaseBudget: Double = 0
                    for (deptKey, budgetAmount) in phase.departments {
                        // Filter by department if specific department is selected
                        if selectedDepartment != "All Departments" {
                            let departmentName: String
                            if let underscoreIndex = deptKey.firstIndex(of: "_") {
                                departmentName = String(deptKey[deptKey.index(after: underscoreIndex)...])
                            } else {
                                departmentName = deptKey
                            }
                            
                            if departmentName != selectedDepartment {
                                continue
                            }
                        }
                        phaseBudget += budgetAmount
                    }
                    
                    // Load expenses for this phase
                    let expensesSnapshot = try await FirebasePathHelper.shared
                        .expensesCollection(customerId: customerId, projectId: projectId)
                        .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                        .getDocuments()
                    
                    var phaseActual: Double = 0
                    
                    // Process each approved expense
                    for expenseDoc in expensesSnapshot.documents {
                        guard let expense = try? expenseDoc.data(as: Expense.self) else { continue }
                        
                        // Filter by phase
                        if expense.phaseId != phaseId {
                            continue
                        }
                        
                        // Parse expense date and filter by date range
                        guard let expenseDate = dateFormatter.date(from: expense.date) else { continue }
                        let expenseStartOfDay = calendar.startOfDay(for: expenseDate)
                        let startOfDay = calendar.startOfDay(for: startDate)
                        let endOfDay = calendar.startOfDay(for: endDate)
                        
                        if expenseStartOfDay < startOfDay || expenseStartOfDay > endOfDay {
                            continue
                        }
                        
                        // Filter by department
                        if selectedDepartment != "All Departments" {
                            let expenseDepartmentName: String
                            if let underscoreIndex = expense.department.firstIndex(of: "_") {
                                expenseDepartmentName = String(expense.department[expense.department.index(after: underscoreIndex)...])
                            } else {
                                expenseDepartmentName = expense.department
                            }
                            
                            if expenseDepartmentName != selectedDepartment {
                                continue
                            }
                        }
                        
                        phaseActual += expense.amount
                    }
                    
                    // Accumulate data for this phase (handle same phase names across projects)
                    if let existing = phaseDataMap[phaseName] {
                        phaseDataMap[phaseName] = (
                            budget: existing.budget + phaseBudget,
                            actual: existing.actual + phaseActual
                        )
                    } else {
                        phaseDataMap[phaseName] = (budget: phaseBudget, actual: phaseActual)
                    }
                }
            } catch {
                print("Error calculating stage budget vs actual for project \(projectId): \(error)")
            }
        }
        
        // Convert to array and only show if more than 1 phase
        let stageData = phaseDataMap.map { phaseName, values in
            StageBudgetData(stage: phaseName, budget: values.budget, actual: values.actual)
        }.sorted { $0.stage < $1.stage }
        
        await MainActor.run {
            // Only show data if there are more than 1 phase
            if stageData.count > 1 {
                stageBudgetData = stageData
            } else {
                stageBudgetData = []
            }
        }
    }
    
    private func updateDataBasedOnFilters() {
        // Update chart data based on selected filters
        updateKPIs()
        
        // Calculate cost trend based on filters
        Task {
            await calculateCostTrend()
            await calculateStageBudgetVsActual()
            await calculateProjectWiseBudgetVsActual()
        }
        
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
    
    /// Calculate project-wise budget vs actual data based on selected filters
    private func calculateProjectWiseBudgetVsActual() async {
        guard let customerId = customerId else {
            await MainActor.run {
                projectWiseData = []
            }
            return
        }
        
        // Determine which projects to include
        let projectsToProcess: [Project]
        if selectedProject == "All Projects" {
            projectsToProcess = projects
        } else {
            // If a specific project is selected, only show that one (but we need > 1 to show chart)
            projectsToProcess = projects.filter { $0.name == selectedProject }
        }
        
        // Only calculate if we have more than 1 project
        guard projectsToProcess.count > 1 else {
            await MainActor.run {
                projectWiseData = []
            }
            return
        }
        
        // Date formatter for parsing expense dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        let calendar = Calendar.current
        var projectDataMap: [String: (budget: Double, actual: Double)] = [:] // projectName -> (budget, actual)
        
        // Process each project
        for project in projectsToProcess {
            guard let projectId = project.id else { continue }
            let projectName = project.name
            
            do {
                // Load phases for this project
                let phasesSnapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .getDocuments()
                
                var projectBudget: Double = 0
                
                // Process each phase
                for phaseDoc in phasesSnapshot.documents {
                    guard let phase = try? phaseDoc.data(as: Phase.self) else { continue }
                    let phaseId = phaseDoc.documentID
                    let phaseName = phase.phaseName
                    
                    // Filter by stage (phase name) - if a specific stage is selected, only include that
                    if selectedStage != "All Stages" && phaseName != selectedStage {
                        continue
                    }
                    
                    // Calculate budget for this phase (sum of all departments)
                    for (deptKey, budgetAmount) in phase.departments {
                        // Filter by department if specific department is selected
                        if selectedDepartment != "All Departments" {
                            let departmentName: String
                            if let underscoreIndex = deptKey.firstIndex(of: "_") {
                                departmentName = String(deptKey[deptKey.index(after: underscoreIndex)...])
                            } else {
                                departmentName = deptKey
                            }
                            
                            if departmentName != selectedDepartment {
                                continue
                            }
                        }
                        projectBudget += budgetAmount
                    }
                }
                
                // Load expenses for this project
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .getDocuments()
                
                var projectActual: Double = 0
                
                // Process each approved expense
                for expenseDoc in expensesSnapshot.documents {
                    guard let expense = try? expenseDoc.data(as: Expense.self) else { continue }
                    
                    // Filter by stage (phase name) - use phaseName from expense if available
                    if selectedStage != "All Stages" {
                        if let expensePhaseName = expense.phaseName {
                            if expensePhaseName != selectedStage {
                                continue
                            }
                        } else {
                            continue
                        }
                    }
                    
                    // Parse expense date and filter by date range
                    guard let expenseDate = dateFormatter.date(from: expense.date) else { continue }
                    let expenseStartOfDay = calendar.startOfDay(for: expenseDate)
                    let startOfDay = calendar.startOfDay(for: startDate)
                    let endOfDay = calendar.startOfDay(for: endDate)
                    
                    if expenseStartOfDay < startOfDay || expenseStartOfDay > endOfDay {
                        continue
                    }
                    
                    // Extract department name from expense
                    let expenseDepartmentName: String
                    if let underscoreIndex = expense.department.firstIndex(of: "_") {
                        expenseDepartmentName = String(expense.department[expense.department.index(after: underscoreIndex)...])
                    } else {
                        expenseDepartmentName = expense.department
                    }
                    
                    // Filter by department
                    if selectedDepartment != "All Departments" && expenseDepartmentName != selectedDepartment {
                        continue
                    }
                    
                    projectActual += expense.amount
                }
                
                // Store data for this project
                projectDataMap[projectName] = (budget: projectBudget, actual: projectActual)
            } catch {
                print("Error calculating project-wise budget vs actual for project \(projectId): \(error)")
            }
        }
        
        // Convert to array
        let projectData = projectDataMap.map { projectName, values in
            ProjectWiseData(project: projectName, budget: values.budget, actual: values.actual)
        }.sorted { $0.project < $1.project }
        
        await MainActor.run {
            // Only show data if there are more than 1 project
            if projectData.count > 1 {
                projectWiseData = projectData
            } else {
                projectWiseData = []
            }
        }
    }
}

