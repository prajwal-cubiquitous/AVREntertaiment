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
    // Filter selections - now using Set for multiple selection
    @Published var selectedProjects: Set<String> = [] {
        didSet {
            Task {
                await loadStagesForProject()
                updateDataBasedOnFilters()
            }
        }
    }
    @Published var selectedStages: Set<String> = [] {
        didSet {
            Task {
                await loadDepartmentsForStage()
                updateDataBasedOnFilters()
            }
        }
    }
    @Published var selectedDepartments: Set<String> = [] {
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
    
    // Computed properties for display text
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
    
    var selectedProjectsDisplayText: String {
        if selectedProjects.isEmpty {
            return "All Projects"
        } else if selectedProjects.count == 1 {
            return selectedProjects.first ?? "All Projects"
        } else {
            return "\(selectedProjects.count) Selected"
        }
    }
    
    var selectedStagesDisplayText: String {
        if selectedStages.isEmpty {
            return "All Stages"
        } else if selectedStages.count == 1 {
            return selectedStages.first ?? "All Stages"
        } else {
            return "\(selectedStages.count) Selected"
        }
    }
    
    var selectedDepartmentsDisplayText: String {
        if selectedDepartments.isEmpty {
            return "All Departments"
        } else if selectedDepartments.count == 1 {
            return selectedDepartments.first ?? "All Departments"
        } else {
            return "\(selectedDepartments.count) Selected"
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
            
            // Calculate initial active projects and stage progress
            await calculateActiveProjects()
            await calculateStageProgressStatus()
            
            // Calculate initial sub-category activity
            await calculateSubCategoryActivity()
            
            // Calculate initial sub-category spend
            await calculateSubCategorySpend()
            
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
                
                // Remove any selected projects that are no longer in the filtered list
                self.selectedProjects = self.selectedProjects.filter { projectNames.contains($0) }
                
                // Reload stages for the currently selected projects
                Task {
                    await loadStagesForProject()
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
            
            if selectedProjects.isEmpty {
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
                // Load phases from selected projects only
                for selectedProjectName in selectedProjects {
                    guard let projectId = projectIdMap[selectedProjectName] else {
                        print("Error: Project ID not found for \(selectedProjectName)")
                        continue
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
            }
            
            // Convert Set to sorted array and add "All Stages" at the beginning
            var stageNames = Array(uniqueStageNames).sorted()
            stageNames.insert("All Stages", at: 0)
            
            await MainActor.run {
                self.phases = allPhases
                self.stageOptions = stageNames
                // Remove any selected stages that are no longer in the filtered list
                self.selectedStages = self.selectedStages.filter { stageNames.contains($0) }
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
        
        if selectedStages.isEmpty {
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
            // Extract departments from selected stages only
            let selectedPhases = phases.filter { selectedStages.contains($0.phaseName) }
            
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
            // Remove any selected departments that are no longer in the filtered list
            self.selectedDepartments = self.selectedDepartments.filter { sortedDepartments.contains($0) }
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
        if selectedProjects.isEmpty {
            projectsToProcess = projects
        } else {
            projectsToProcess = projects.filter { selectedProjects.contains($0.name) }
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
                    if !selectedStages.isEmpty {
                        if let expensePhaseName = expense.phaseName {
                            if !selectedStages.contains(expensePhaseName) {
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
                    if !selectedDepartments.isEmpty && !selectedDepartments.contains(expenseDepartmentName) {
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
        
        // subCategorySpendData is now calculated from real data in calculateSubCategorySpend()
        
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
        
        // activeProjectsData is now calculated from real data in calculateActiveProjects()
        // stageProgressData is now calculated from real data in calculateStageProgressStatus()
        // subCategoryActivityData is now calculated from real data in calculateSubCategoryActivity()
        
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
        if selectedProjects.isEmpty {
            projectsToProcess = projects
        } else {
            projectsToProcess = projects.filter { selectedProjects.contains($0.name) }
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
                    if !selectedStages.isEmpty && !selectedStages.contains(phase.phaseName) {
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
                        if !selectedDepartments.isEmpty && !selectedDepartments.contains(departmentName) {
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
                    if !selectedStages.isEmpty {
                        // Use phaseName from expense if available, otherwise skip if stage filter is active
                        if let expensePhaseName = expense.phaseName {
                            if !selectedStages.contains(expensePhaseName) {
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
                    if !selectedDepartments.isEmpty && !selectedDepartments.contains(expenseDepartmentName) {
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
        if selectedProjects.isEmpty {
            projectsToProcess = projects
        } else {
            projectsToProcess = projects.filter { selectedProjects.contains($0.name) }
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
                    if !selectedStages.isEmpty && !selectedStages.contains(phaseName) {
                        continue
                    }
                    
                    // Calculate budget for this phase (sum of all departments)
                    var phaseBudget: Double = 0
                    for (deptKey, budgetAmount) in phase.departments {
                        // Filter by department if specific department is selected
                        if !selectedDepartments.isEmpty {
                            let departmentName: String
                            if let underscoreIndex = deptKey.firstIndex(of: "_") {
                                departmentName = String(deptKey[deptKey.index(after: underscoreIndex)...])
                            } else {
                                departmentName = deptKey
                            }
                            
                            if !selectedDepartments.contains(departmentName) {
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
                        if !selectedDepartments.isEmpty {
                            let expenseDepartmentName: String
                            if let underscoreIndex = expense.department.firstIndex(of: "_") {
                                expenseDepartmentName = String(expense.department[expense.department.index(after: underscoreIndex)...])
                            } else {
                                expenseDepartmentName = expense.department
                            }
                            
                            if !selectedDepartments.contains(expenseDepartmentName) {
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
            await calculateActiveProjects()
            await calculateStageProgressStatus()
            await calculateSubCategoryActivity()
            await calculateSubCategorySpend()
        }
        
        // Update stage across projects data when stage is selected
        if !selectedStages.isEmpty {
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
        if selectedProjects.isEmpty {
            projectsToProcess = projects
        } else {
            projectsToProcess = projects.filter { selectedProjects.contains($0.name) }
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
                    if !selectedStages.isEmpty && !selectedStages.contains(phaseName) {
                        continue
                    }
                    
                    // Calculate budget for this phase (sum of all departments)
                    for (deptKey, budgetAmount) in phase.departments {
                        // Filter by department if specific department is selected
                        if !selectedDepartments.isEmpty {
                            let departmentName: String
                            if let underscoreIndex = deptKey.firstIndex(of: "_") {
                                departmentName = String(deptKey[deptKey.index(after: underscoreIndex)...])
                            } else {
                                departmentName = deptKey
                            }
                            
                            if !selectedDepartments.contains(departmentName) {
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
                    if !selectedStages.isEmpty {
                        if let expensePhaseName = expense.phaseName {
                            if !selectedStages.contains(expensePhaseName) {
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
                    if !selectedDepartments.isEmpty && !selectedDepartments.contains(expenseDepartmentName) {
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
    
    /// Calculate active projects count per month for the last 6 months
    private func calculateActiveProjects() async {
        guard let customerId = customerId else {
            await MainActor.run {
                activeProjectsData = []
            }
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Get last 6 months
        var monthlyCounts: [String: Int] = [:]
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM" // Short month name (Jan, Feb, etc.)
        
        // Generate last 6 months
        for i in 0..<6 {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let monthKey = monthFormatter.string(from: monthDate)
            monthlyCounts[monthKey] = 0
        }
        
        // Process all projects
        for project in projects {
            // Filter by project status if needed
            if selectedProjectStatuses.count < projectStatusOptions.count {
                // Check if project matches selected statuses
                var statusMatches = false
                if project.isSuspended == true {
                    if selectedProjectStatuses.contains("SUSPENDED") {
                        statusMatches = true
                    }
                } else {
                    if project.status == "SUSPENDED" {
                        if selectedProjectStatuses.contains("SUSPENDED") {
                            statusMatches = true
                        }
                    } else {
                        if selectedProjectStatuses.contains(project.status) {
                            statusMatches = true
                        }
                    }
                }
                if !statusMatches {
                    continue
                }
            }
            
            // Check if project was active in each month
            let projectStartDate: Date?
            let projectEndDate: Date?
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            
            if let plannedDateStr = project.plannedDate,
               let plannedDate = dateFormatter.date(from: plannedDateStr) {
                projectStartDate = plannedDate
            } else if let startDateStr = project.startDate,
                      let startDate = dateFormatter.date(from: startDateStr) {
                projectStartDate = startDate
            } else {
                projectStartDate = nil
            }
            
            if let maintenanceDateStr = project.maintenanceDate,
               let maintenanceDate = dateFormatter.date(from: maintenanceDateStr) {
                projectEndDate = maintenanceDate
            } else if let endDateStr = project.endDate,
                      let endDate = dateFormatter.date(from: endDateStr) {
                projectEndDate = endDate
            } else {
                projectEndDate = nil
            }
            
            // Check each month
            for i in 0..<6 {
                guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
                let monthKey = monthFormatter.string(from: monthDate)
                
                // Get first and last day of the month
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
                let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
                
                // Check if project was active during this month
                // A project is active if:
                // 1. Status is ACTIVE (or was ACTIVE during this month)
                // 2. Project start date is before or during this month
                // 3. Project end date is after or during this month (or nil)
                
                var wasActive = false
                
                // Check if project status is ACTIVE
                if project.status == "ACTIVE" && project.isSuspended != true {
                    // Check if project dates overlap with this month
                    if let startDate = projectStartDate {
                        if startDate <= monthEnd {
                            if let endDate = projectEndDate {
                                if endDate >= monthStart {
                                    wasActive = true
                                }
                            } else {
                                // No end date, project is ongoing
                                wasActive = true
                            }
                        }
                    } else {
                        // No start date, assume it's active if status is ACTIVE
                        wasActive = true
                    }
                }
                
                if wasActive {
                    monthlyCounts[monthKey, default: 0] += 1
                }
            }
        }
        
        // Convert to array and sort by month (chronological order - oldest to newest)
        // Build array of month dates first, then sort
        var monthDates: [(month: String, date: Date)] = []
        for i in 0..<6 {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let monthKey = monthFormatter.string(from: monthDate)
            monthDates.append((month: monthKey, date: monthDate))
        }
        
        // Sort by date (oldest first)
        monthDates.sort { $0.date < $1.date }
        
        // Create data array in chronological order
        let activeData = monthDates.map { monthDate in
            ActiveProjectsData(month: monthDate.month, count: monthlyCounts[monthDate.month] ?? 0)
        }
        
        await MainActor.run {
            activeProjectsData = activeData
        }
    }
    
    /// Calculate stage progress status - current status count of projects
    private func calculateStageProgressStatus() async {
        // Categorize projects by their current status
        var inProgressCount = 0
        var handoverCount = 0
        var plannedCount = 0
        var completeCount = 0
        var delayedCount = 0
        var totalCount = 0
        
        for project in projects {
            // Filter by project status if needed
            if selectedProjectStatuses.count < projectStatusOptions.count {
                var statusMatches = false
                if project.isSuspended == true {
                    if selectedProjectStatuses.contains("SUSPENDED") {
                        statusMatches = true
                    }
                } else {
                    if project.status == "SUSPENDED" {
                        if selectedProjectStatuses.contains("SUSPENDED") {
                            statusMatches = true
                        }
                    } else {
                        if selectedProjectStatuses.contains(project.status) {
                            statusMatches = true
                        }
                    }
                }
                if !statusMatches {
                    continue
                }
            }
            
            totalCount += 1
            
            // Categorize by status
            if project.isSuspended == true {
                // Suspended projects might be considered delayed
                delayedCount += 1
            } else {
                switch project.status {
                case "ACTIVE":
                    inProgressCount += 1
                case "HANDOVER":
                    handoverCount += 1
                case "LOCKED", "IN_REVIEW":
                    plannedCount += 1
                case "COMPLETED", "ARCHIVE":
                    completeCount += 1
                case "MAINTENANCE":
                    // Maintenance could be considered complete or handover
                    completeCount += 1
                default:
                    // Other statuses might be delayed
                    delayedCount += 1
                }
            }
        }
        
        // Calculate percentages
        let total = Double(totalCount)
        guard total > 0 else {
            await MainActor.run {
                stageProgressData = []
            }
            return
        }
        
        let inProgressPercent = (Double(inProgressCount) / total) * 100
        let handoverPercent = (Double(handoverCount) / total) * 100
        let plannedPercent = (Double(plannedCount) / total) * 100
        let completePercent = (Double(completeCount) / total) * 100
        let delayedPercent = (Double(delayedCount) / total) * 100
        
        // Create data showing the distribution of project statuses
        // Each row represents a category, showing the percentage share of each status type
        let progressData = [
            StageProgressData(
                stage: "In Progress",
                inProgress: inProgressPercent,
                handover: handoverPercent,
                delayed: delayedPercent,
                complete: completePercent
            ),
            StageProgressData(
                stage: "HandOver",
                inProgress: inProgressPercent,
                handover: handoverPercent,
                delayed: delayedPercent,
                complete: completePercent
            ),
            StageProgressData(
                stage: "Planned",
                inProgress: 0,
                handover: 0,
                delayed: 0,
                complete: plannedPercent
            ),
            StageProgressData(
                stage: "Complete",
                inProgress: 0,
                handover: 0,
                delayed: 0,
                complete: completePercent
            )
        ]
        
        await MainActor.run {
            stageProgressData = progressData
        }
    }
    
    /// Calculate sub-category activity - count expenses by category for last 30 days
    private func calculateSubCategoryActivity() async {
        guard let customerId = customerId else {
            await MainActor.run {
                subCategoryActivityData = []
            }
            return
        }
        
        // Determine which projects to include
        let projectsToProcess: [Project]
        if selectedProjects.isEmpty {
            projectsToProcess = projects
        } else {
            projectsToProcess = projects.filter { selectedProjects.contains($0.name) }
        }
        
        // Date formatter for parsing expense dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        let calendar = Calendar.current
        let now = Date()
        // Get date 30 days ago
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else {
            await MainActor.run {
                subCategoryActivityData = []
            }
            return
        }
        
        var categoryCounts: [String: Int] = [:]
        
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
                    
                    // Parse expense date and filter by last 30 days
                    guard let expenseDate = dateFormatter.date(from: expense.date) else { continue }
                    let expenseStartOfDay = calendar.startOfDay(for: expenseDate)
                    let thirtyDaysAgoStartOfDay = calendar.startOfDay(for: thirtyDaysAgo)
                    
                    if expenseStartOfDay < thirtyDaysAgoStartOfDay {
                        continue
                    }
                    
                    // Filter by stage (phase name) - use phaseName from expense if available
                    if !selectedStages.isEmpty {
                        if let expensePhaseName = expense.phaseName {
                            if !selectedStages.contains(expensePhaseName) {
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
                    if !selectedDepartments.isEmpty && !selectedDepartments.contains(expenseDepartmentName) {
                        continue
                    }
                    
                    // Extract categories from expense (categories is a list, but typically has one value)
                    for category in expense.categories {
                        categoryCounts[category, default: 0] += 1
                    }
                }
            } catch {
                print("Error calculating sub-category activity for project \(projectId): \(error)")
            }
        }
        
        // Get top 5 categories sorted by count (descending)
        let topCategories = categoryCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { SubCategoryActivityData(category: $0.key, count: $0.value) }
        
        await MainActor.run {
            subCategoryActivityData = Array(topCategories)
        }
    }
    
    /// Calculate sub-category spend - sum expense amounts by category
    private func calculateSubCategorySpend() async {
        guard let customerId = customerId else {
            await MainActor.run {
                subCategorySpendData = []
            }
            return
        }
        
        // Determine which projects to include
        let projectsToProcess: [Project]
        if selectedProjects.isEmpty {
            projectsToProcess = projects
        } else {
            projectsToProcess = projects.filter { selectedProjects.contains($0.name) }
        }
        
        var categorySpend: [String: Double] = [:]
        
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
                    
                    // Filter by stage (phase name) - use phaseName from expense if available
                    if !selectedStages.isEmpty {
                        if let expensePhaseName = expense.phaseName {
                            if !selectedStages.contains(expensePhaseName) {
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
                    if !selectedDepartments.isEmpty && !selectedDepartments.contains(expenseDepartmentName) {
                        continue
                    }
                    
                    // Extract categories from expense and sum amounts
                    for category in expense.categories {
                        categorySpend[category, default: 0] += expense.amount
                    }
                }
            } catch {
                print("Error calculating sub-category spend for project \(projectId): \(error)")
            }
        }
        
        // Convert to array and sort by spend (descending)
        let spendData = categorySpend
            .sorted { $0.value > $1.value }
            .map { SubCategorySpendData(category: $0.key, value: $0.value) }
        
        await MainActor.run {
            subCategorySpendData = Array(spendData)
        }
    }
}

