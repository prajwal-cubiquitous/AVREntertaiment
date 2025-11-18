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
                debouncedUpdateData()
            }
        }
    }
    @Published var selectedStages: Set<String> = [] {
        didSet {
            Task {
                await loadDepartmentsForStage()
                debouncedUpdateData()
            }
        }
    }
    @Published var selectedDepartments: Set<String> = [] {
        didSet {
            debouncedUpdateData()
        }
    }
    @Published var selectedProjectStatuses: Set<String> = ["ACTIVE", "COMPLETED", "MAINTENANCE", "ARCHIVE", "SUSPENDED"] {
        didSet {
            Task {
                await loadProjects()
                invalidateCache() // Invalidate cache when status changes
                debouncedUpdateData()
            }
        }
    }
    @Published var startDate: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date() {
        didSet {
            Task {
                await loadProjects()
                invalidateCache() // Invalidate cache when date range changes
                debouncedUpdateData()
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
                invalidateCache() // Invalidate cache when date range changes
                debouncedUpdateData()
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
    
    // Performance optimization: Data cache
    private var expensesCache: [String: [Expense]] = [:] // projectId -> expenses
    private var phasesCache: [String: [Phase]] = [:] // projectId -> phases
    private var cacheDateRange: (start: Date, end: Date)?
    private var isCacheValid: Bool = false
    
    // Debouncing for filter changes
    private var filterUpdateTask: Task<Void, Never>?
    private let debounceDelay: TimeInterval = 0.3 // 300ms debounce
    
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
        let totalSpend: Double // Total approved expenses in last 30 days (in ₹)
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
        let projectNames: [String] // List of unique project names that have expenses in this category
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
        let projectNames: [String] // List of unique project names that have this suspension reason
    }
    
    struct ProjectStatusPercentageData: Identifiable {
        let id = UUID()
        let status: String
        let percentage: Double
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
    @Published var projectStatusPercentageData: [ProjectStatusPercentageData] = []
    
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
        // Safety check to prevent crashes during initialization or concurrent access
        // Access the array count first to ensure it's safe to iterate
        let dataCount = costTrendData.count
        guard dataCount > 0 else {
            return formatCr(0)
        }
        // Use a local copy to avoid potential concurrent modification issues
        let data = costTrendData
        let total = data.reduce(0) { $0 + $1.value }
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
            return "₹\(String(format: "%.2f", lakhs)) L"
        } else {
            // 10000000+: show in crores (Cr) with 2 decimals
            let crores = value / 10000000.0
            return "₹\(String(format: "%.2f", crores)) Cr"
        }
    }
    
    // Helper function to format numbers for chart display (without currency symbol)
    // 1-999: actual numbers
    // 1000-99999: "1k" or "1.25k" format (removes .00 for whole numbers)
    // 100000-9999999: "1 lakhs" or "9.99 lakhs" format (removes .00 for whole numbers)
    // 10000000+: "1 cr" or "9.99 cr" format (removes .00 for whole numbers)
    func formatChartNumber(_ value: Double) -> String {
        let absValue = abs(value)
        
        if absValue < 1000 {
            // 1 to 999: show actual numbers
            return String(format: "%.0f", value)
        } else if absValue < 100000 {
            // 1000 to 99999: show in thousands (k)
            let thousands = value / 1000.0
            // Remove .00 if it's a whole number
            if thousands.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0fk", thousands)
            } else {
                return String(format: "%.2fk", thousands)
            }
        } else if absValue < 10000000 {
            // 100000 to 9999999: show in lakhs
            let lakhs = value / 100000.0
            // Remove .00 if it's a whole number
            if lakhs.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f lakhs", lakhs)
            } else {
                return String(format: "%.2f lakhs", lakhs)
            }
        } else {
            // 10000000+: show in crores (cr)
            let crores = value / 10000000.0
            // Remove .00 if it's a whole number
            if crores.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f cr", crores)
            } else {
                return String(format: "%.2f cr", crores)
            }
        }
    }
    
    // MARK: - Data Loading
    
    /// Debounced update to prevent excessive recalculations
    private func debouncedUpdateData() {
        filterUpdateTask?.cancel()
        filterUpdateTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            updateDataBasedOnFilters()
        }
    }
    
    /// Invalidate cache when filters change significantly
    private func invalidateCache() {
        isCacheValid = false
        expensesCache.removeAll()
        phasesCache.removeAll()
        cacheDateRange = nil
    }
    
    /// Load all projects and populate the project dropdown
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch customer ID
            customerId = try await FirebasePathHelper.shared.fetchEffectiveUserID()
            
            // Load projects
            await loadProjects()
            
            // Pre-load all expenses and phases in parallel for caching
            await preloadExpensesAndPhases()
            
            // Calculate all metrics in parallel using TaskGroup
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.calculateBudgetMetrics() }
                group.addTask { await self.calculateCostTrend() }
                group.addTask { await self.calculateDelayCorrelation() }
                group.addTask { await self.calculateStageBudgetVsActual() }
                group.addTask { await self.calculateProjectWiseBudgetVsActual() }
                group.addTask { await self.calculateActiveProjects() }
                group.addTask { await self.calculateProjectStatusPercentage() }
                group.addTask { await self.calculateSubCategoryActivity() }
                group.addTask { await self.calculateSubCategorySpend() }
                group.addTask { await self.calculateSuspensionReasons() }
            }
            
            // Load sample chart data (for now)
            loadSampleChartData()
            
        } catch {
            Swift.print("Error loading data: \(error)")
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Pre-load expenses and phases for all projects in parallel
    private func preloadExpensesAndPhases() async {
        guard let customerId = customerId else { return }
        
        // Check if cache is still valid
        if isCacheValid,
           let cachedRange = cacheDateRange,
           cachedRange.start == startDate,
           cachedRange.end == endDate {
            return // Cache is valid, skip reloading
        }
        
        // Clear old cache
        expensesCache.removeAll()
        phasesCache.removeAll()
        
        // Load expenses and phases in parallel for all projects
        await withTaskGroup(of: Void.self) { group in
            for project in projects {
                guard let projectId = project.id else { continue }
                
                group.addTask {
                    // Load expenses
                    do {
                        let expensesSnapshot = try await FirebasePathHelper.shared
                            .expensesCollection(customerId: customerId, projectId: projectId)
                            .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                            .getDocuments()
                        
                        let projectExpenses = expensesSnapshot.documents.compactMap { doc -> Expense? in
                            try? doc.data(as: Expense.self)
                        }
                        
                        await MainActor.run {
                            self.expensesCache[projectId] = projectExpenses
                        }
                    } catch {
                        Swift.print("Error loading expenses for project \(projectId): \(error)")
                    }
                    
                    // Load phases
                    do {
                        let phasesSnapshot = try await FirebasePathHelper.shared
                            .phasesCollection(customerId: customerId, projectId: projectId)
                            .getDocuments()
                        
                        let projectPhases = phasesSnapshot.documents.compactMap { doc -> Phase? in
                            try? doc.data(as: Phase.self)
                        }
                        
                        await MainActor.run {
                            self.phasesCache[projectId] = projectPhases
                        }
                    } catch {
                        Swift.print("Error loading phases for project \(projectId): \(error)")
                    }
                }
            }
        }
        
        // Mark cache as valid
        await MainActor.run {
            isCacheValid = true
            cacheDateRange = (start: startDate, end: endDate)
        }
    }
    
    /// Load projects from Firestore with status and date filtering
    private func loadProjects() async {
        guard let customerId = customerId else {
            Swift.print("Error: Customer ID not available")
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
                    
                    // Filter by date range (check if project timeline overlaps with selected date range)
                    // Project timeline: plannedDate (start) to maintenanceDate (end)
                    // Selected date range: startDate to endDate
                    // Two date ranges overlap if: projectStart <= selectedEnd AND projectEnd >= selectedStart
                    var dateMatches = false
                    
                    // Get project timeline dates
                    let projectStartDate: Date?
                    let projectEndDate: Date?
                    
                    if let plannedDateStr = project.plannedDate,
                       let plannedDate = dateFormatter.date(from: plannedDateStr) {
                        projectStartDate = plannedDate
                    } else {
                        projectStartDate = nil
                    }
                    
                    if let maintenanceDateStr = project.maintenanceDate,
                       let maintenanceDate = dateFormatter.date(from: maintenanceDateStr) {
                        projectEndDate = maintenanceDate
                    } else {
                        projectEndDate = nil
                    }
                    
                    // Check for overlap between project timeline and selected date range
                    if let projectStart = projectStartDate, let projectEnd = projectEndDate {
                        // Both dates available - check for range overlap
                        let projectStartOfDay = calendar.startOfDay(for: projectStart)
                        let projectEndOfDay = calendar.startOfDay(for: projectEnd)
                        
                        // Two date ranges overlap if: projectStart <= selectedEnd AND projectEnd >= selectedStart
                        if projectStartOfDay <= endOfDay && projectEndOfDay >= startOfDay {
                            dateMatches = true
                        }
                    } else if let projectStart = projectStartDate {
                        // Only start date available - check if it's within or overlaps the selected range
                        let projectStartOfDay = calendar.startOfDay(for: projectStart)
                        // If project starts before or on the selected end date, it might overlap
                        if projectStartOfDay <= endOfDay {
                            dateMatches = true
                        }
                    } else if let projectEnd = projectEndDate {
                        // Only end date available - check if it's within or overlaps the selected range
                        let projectEndOfDay = calendar.startOfDay(for: projectEnd)
                        // If project ends on or after the selected start date, it might overlap
                        if projectEndOfDay >= startOfDay {
                            dateMatches = true
                        }
                    } else {
                        // No dates available - exclude project
                        dateMatches = false
                    }
                    
                    // If no date overlap, skip this project
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
            Swift.print("Error loading projects: \(error)")
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
                        Swift.print("Error: Project ID not found for \(selectedProjectName)")
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
            Swift.print("Error loading stages: \(error)")
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
        
        // Process each project using cached expenses
        for project in projectsToProcess {
            guard let projectId = project.id else { continue }
            
            // Use cached expenses instead of querying Firestore
            let projectExpenses = expensesCache[projectId] ?? []
            
            // Process each approved expense
            for expense in projectExpenses {
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
        Swift.print("📊 Cost Trend Data:")
        for data in trendData {
            Swift.print("  \(data.month): ₹\(data.value)")
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
        
        // statusCostData is now calculated from real data in calculateStatusCost()
        
        // overrunData is now calculated from real data in calculateOverrunData()
        
        // burnRateData is now calculated from real data in calculateBurnRate()
        
        // activeProjectsData is now calculated from real data in calculateActiveProjects()
        // stageProgressData is now calculated from real data in calculateStageProgressStatus()
        // subCategoryActivityData is now calculated from real data in calculateSubCategoryActivity()
        
        // suspensionReasonData is now calculated from real data in calculateSuspensionReasons()
        
        // delayCorrelationData is now calculated from real data in calculateDelayCorrelation()
        
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
        
        // Process each project using cached data
        for project in projectsToProcess {
            guard let projectId = project.id else { continue }
            
            // Use cached phases instead of querying Firestore
            let projectPhases = phasesCache[projectId] ?? []
            
            // Process each phase
            for phase in projectPhases {
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
            
            // Use cached expenses instead of querying Firestore
            let projectExpenses = expensesCache[projectId] ?? []
            
            // Process each approved expense
            for expense in projectExpenses {
                    
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
        
        // Process each project using cached data
        for project in projectsToProcess {
            guard let projectId = project.id else { continue }
            
            // Use cached phases instead of querying Firestore
            let projectPhases = phasesCache[projectId] ?? []
            
            // Process each phase
            for phase in projectPhases {
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
                
                // Use cached expenses instead of querying Firestore
                let projectExpenses = expensesCache[projectId] ?? []
                
                var phaseActual: Double = 0
                
                // Process each approved expense
                for expense in projectExpenses {
                    // Filter by phase - match by phaseName since both have this field
                    if expense.phaseName != phaseName {
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
        
        // Re-validate cache if date range changed
        Task {
            if !isCacheValid || cacheDateRange?.start != startDate || cacheDateRange?.end != endDate {
                await preloadExpensesAndPhases()
            }
            
            // Calculate all metrics in parallel using TaskGroup
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.calculateCostTrend() }
                group.addTask { await self.calculateStageBudgetVsActual() }
                group.addTask { await self.calculateProjectWiseBudgetVsActual() }
                group.addTask { await self.calculateStageAcrossProjects() }
                group.addTask { await self.calculateStatusCost() }
                group.addTask { await self.calculateOverrunData() }
                group.addTask { await self.calculateBurnRate() }
                group.addTask { await self.calculateActiveProjects() }
                group.addTask { await self.calculateProjectStatusPercentage() }
                group.addTask { await self.calculateSubCategoryActivity() }
                group.addTask { await self.calculateSubCategorySpend() }
                group.addTask { await self.calculateSuspensionReasons() }
                group.addTask { await self.calculateDelayCorrelation() }
            }
        }
    }
    
    /// Calculate stage across projects data - shows budget vs actual for selected stage(s) across projects
    private func calculateStageAcrossProjects() async {
        guard let customerId = customerId else {
            await MainActor.run {
                stageAcrossProjectsData = []
            }
            return
        }
        
        // Only show data when exactly one stage is selected
        guard selectedStages.count == 1, let selectedStage = selectedStages.first else {
            await MainActor.run {
                stageAcrossProjectsData = []
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
        var projectDataMap: [String: (budget: Double, actual: Double)] = [:] // projectName -> (budget, actual)
        
        // Process each project
        for project in projectsToProcess {
            guard let projectId = project.id else { continue }
            let projectName = project.name
            
            // Use cached phases instead of querying Firestore
            let projectPhases = phasesCache[projectId] ?? []
            
            var stageBudget: Double = 0
            var hasSelectedStage = false
            
            // Find the selected stage in this project's phases
            for phase in projectPhases {
                let phaseName = phase.phaseName
                
                // Check if this phase matches the selected stage
                if phaseName == selectedStage {
                    hasSelectedStage = true
                    
                    // Calculate budget for this stage (sum of all departments)
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
                        stageBudget += budgetAmount
                    }
                    break // Found the stage, no need to continue
                }
            }
            
            // Only process expenses if this project has the selected stage
            guard hasSelectedStage else { continue }
            
            // Use cached expenses instead of querying Firestore
            let projectExpenses = expensesCache[projectId] ?? []
            
            var stageActual: Double = 0
            
            // Process each approved expense
            for expense in projectExpenses {
                // Filter by stage (phase name) - must match the selected stage
                if let expensePhaseName = expense.phaseName {
                    if expensePhaseName != selectedStage {
                        continue
                    }
                } else {
                    // If expense doesn't have phaseName, skip it
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
                    
                    stageActual += expense.amount
                }
                
                // Store data for this project (only if it has the selected stage)
                if hasSelectedStage {
                    projectDataMap[projectName] = (budget: stageBudget, actual: stageActual)
                }
        }
        
        // Convert to array and sort by project name
        let stageData = projectDataMap.map { projectName, values in
            StageAcrossProjectsData(project: projectName, budget: values.budget, actual: values.actual)
        }.sorted { $0.project < $1.project }
        
        await MainActor.run {
            stageAcrossProjectsData = stageData
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
            
            // Use cached phases instead of querying Firestore
            let projectPhases = phasesCache[projectId] ?? []
            
            var projectBudget: Double = 0
            
            // Process each phase
            for phase in projectPhases {
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
            
            // Use cached expenses instead of querying Firestore
            let projectExpenses = expensesCache[projectId] ?? []
            
            var projectActual: Double = 0
            
            // Process each approved expense
            for expense in projectExpenses {
                    
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
                case "LOCKED", "IN_REVIEW":
                    plannedCount += 1
                case "COMPLETED", "ARCHIVE":
                    completeCount += 1
                case "MAINTENANCE":
                    // Maintenance could be considered complete
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
        let plannedPercent = (Double(plannedCount) / total) * 100
        let completePercent = (Double(completeCount) / total) * 100
        let delayedPercent = (Double(delayedCount) / total) * 100
        
        // Create data showing the distribution of project statuses
        // Each row represents a category, showing the percentage share of each status type
        let progressData = [
            StageProgressData(
                stage: "In Progress",
                inProgress: inProgressPercent,
                handover: 0,
                delayed: delayedPercent,
                complete: completePercent
            ),
            StageProgressData(
                stage: "Planned",
                inProgress: inProgressPercent,
                handover: 0,
                delayed: delayedPercent,
                complete: completePercent
            ),
            StageProgressData(
                stage: "Delayed",
                inProgress: inProgressPercent,
                handover: 0,
                delayed: delayedPercent,
                complete: completePercent
            ),
            StageProgressData(
                stage: "Complete",
                inProgress: inProgressPercent,
                handover: 0,
                delayed: delayedPercent,
                complete: completePercent
            )
        ]
        
        await MainActor.run {
            stageProgressData = progressData
        }
    }
    
    /// Calculate project status percentage - percentage of projects by status
    private func calculateProjectStatusPercentage() async {
        // Count projects by status
        var statusCounts: [String: Int] = [:]
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
            
            // Use the actual status name (will be mapped to colors in the view)
            let status: String
            if project.isSuspended == true {
                status = "SUSPENDED"
            } else {
                status = project.status
            }
            
            statusCounts[status, default: 0] += 1
        }
        
        // Calculate percentages
        guard totalCount > 0 else {
            await MainActor.run {
                projectStatusPercentageData = []
            }
            return
        }
        
        // Create data array with percentages
        let percentageData = statusCounts.map { (status, count) in
            ProjectStatusPercentageData(
                status: status,
                percentage: (Double(count) / Double(totalCount)) * 100.0,
                count: count
            )
        }.sorted { $0.percentage > $1.percentage } // Sort by percentage descending
        
        await MainActor.run {
            projectStatusPercentageData = percentageData
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
        var categoryProjects: [String: Set<String>] = [:] // Track unique project names per category
        
        // Process each project using cached expenses
        for project in projectsToProcess {
            guard let projectId = project.id else { continue }
            let projectName = project.name
            
            // Use cached expenses instead of querying Firestore
            let projectExpenses = expensesCache[projectId] ?? []
            
            // Process each approved expense
            for expense in projectExpenses {
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
                    categoryProjects[category, default: Set<String>()].insert(projectName)
                }
            }
        }
        
        // Get top 5 categories sorted by count (descending)
        let topCategories = categoryCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { category, count in
                let projectNames = Array(categoryProjects[category] ?? Set<String>()).sorted()
                return SubCategoryActivityData(
                    category: category,
                    count: count,
                    projectNames: projectNames
                )
            }
        
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
        
        // Process each project using cached expenses
        for project in projectsToProcess {
            guard let projectId = project.id else { continue }
            
            // Use cached expenses instead of querying Firestore
            let projectExpenses = expensesCache[projectId] ?? []
            
            // Process each approved expense
            for expense in projectExpenses {
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
        }
        
        // Convert to array and sort by spend (descending)
        let spendData = categorySpend
            .sorted { $0.value > $1.value }
            .map { SubCategorySpendData(category: $0.key, value: $0.value) }
        
        await MainActor.run {
            subCategorySpendData = Array(spendData)
        }
    }
    
    /// Calculate cost by project status - shows total spend for each selected status
    private func calculateStatusCost() async {
        guard let customerId = customerId else {
            await MainActor.run {
                statusCostData = []
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
        var statusCostMap: [String: Double] = [:] // status -> total cost
        
        // Process each project
        for project in projectsToProcess {
            guard let projectId = project.id else { continue }
            
            // Determine the project's status for filtering
            var projectStatus: String? = nil
            
            // Handle SUSPENDED status: check both status field and isSuspended flag
            if project.isSuspended == true {
                projectStatus = "SUSPENDED"
            } else {
                projectStatus = project.status
            }
            
            // Only process if this project's status is in the selected statuses
            guard let status = projectStatus, selectedProjectStatuses.contains(status) else {
                continue
            }
            
            do {
                // Load expenses for this project
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .getDocuments()
                
                // Process each approved expense
                for expenseDoc in expensesSnapshot.documents {
                    guard let expense = try? expenseDoc.data(as: Expense.self) else { continue }
                    
                    // Parse expense date and filter by date range
                    guard let expenseDate = dateFormatter.date(from: expense.date) else { continue }
                    let expenseStartOfDay = calendar.startOfDay(for: expenseDate)
                    let startOfDay = calendar.startOfDay(for: startDate)
                    let endOfDay = calendar.startOfDay(for: endDate)
                    
                    if expenseStartOfDay < startOfDay || expenseStartOfDay > endOfDay {
                        continue
                    }
                    
                    // Filter by stage if specific stages are selected
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
                    
                    // Filter by department if specific departments are selected
                    if !selectedDepartments.isEmpty && !selectedDepartments.contains(expenseDepartmentName) {
                        continue
                    }
                    
                    // Add to total cost for this status
                    statusCostMap[status, default: 0] += expense.amount
                }
            } catch {
                Swift.print("Error calculating status cost for project \(projectId): \(error)")
            }
        }
        
        // Convert to array, include all selected statuses (even with 0 cost), and sort by status name
        let statusData = selectedProjectStatuses.map { status -> StatusCostData in
            let cost = statusCostMap[status] ?? 0.0
            // Map status names to display names
            let displayName: String
            switch status {
            case "ACTIVE":
                displayName = "Active"
            case "COMPLETED":
                displayName = "Completed"
            case "MAINTENANCE":
                displayName = "Maintenance"
            case "ARCHIVE":
                displayName = "Archive"
            case "SUSPENDED":
                displayName = "Suspended"
            default:
                displayName = status
            }
            return StatusCostData(status: displayName, value: cost)
        }.sorted { $0.status < $1.status }
        
        await MainActor.run {
            statusCostData = statusData
        }
    }
    
    /// Calculate cost overrun vs stage progress data
    /// X-axis: Progress % based on phase startDate and endDate timeline
    /// Y-axis: Overrun % based on approved expenses vs budget
    /// Shows data points when: 1) spent > budget, or 2) progress > 25% with no expenses (negative)
    private func calculateOverrunData() async {
        guard let customerId = customerId else {
            await MainActor.run {
                overrunData = []
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
        
        // Date formatter for parsing dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        let calendar = Calendar.current
        let currentDate = Date()
        var overrunDataMap: [String: (progress: Double, overrun: Double)] = [:] // phaseName -> (progress, overrun)
        
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
                    
                    // Filter by stage if specific stages are selected
                    if !selectedStages.isEmpty && !selectedStages.contains(phaseName) {
                        continue
                    }
                    
                    // Calculate phase budget (sum of all departments)
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
                    
                    // Calculate progress % based on startDate and endDate
                    var progress: Double = 0.0
                    var phaseStartDate: Date?
                    var phaseEndDate: Date?
                    
                    if let startDateStr = phase.startDate,
                       let endDateStr = phase.endDate,
                       let startDate = dateFormatter.date(from: startDateStr),
                       let endDate = dateFormatter.date(from: endDateStr) {
                        
                        phaseStartDate = startDate
                        phaseEndDate = endDate
                        
                        let totalDuration = endDate.timeIntervalSince(startDate)
                        guard totalDuration > 0 else { continue }
                        
                        let elapsed = currentDate.timeIntervalSince(startDate)
                        progress = (elapsed / totalDuration) * 100.0
                        
                        // Clamp progress between 0 and 100
                        progress = max(0, min(100, progress))
                    } else {
                        // If dates are not available, skip this phase
                        continue
                    }
                    
                    guard let startDate = phaseStartDate, let endDate = phaseEndDate else { continue }
                    
                    // Load expenses for this phase
                    let expensesSnapshot = try await FirebasePathHelper.shared
                        .expensesCollection(customerId: customerId, projectId: projectId)
                        .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                        .getDocuments()
                    
                    var phaseActual: Double = 0
                    var hasExpenses = false
                    
                    // Process each approved expense
                    for expenseDoc in expensesSnapshot.documents {
                        guard let expense = try? expenseDoc.data(as: Expense.self) else { continue }
                        
                        // Filter by phase
                        if expense.phaseId != phaseId {
                            continue
                        }
                        
                        // Parse expense date
                        guard let expenseDate = dateFormatter.date(from: expense.date) else { continue }
                        let expenseStartOfDay = calendar.startOfDay(for: expenseDate)
                        
                        // Filter by phase date range (expense must be within phase timeline)
                        let phaseStartOfDay = calendar.startOfDay(for: startDate)
                        let phaseEndOfDay = calendar.startOfDay(for: endDate)
                        
                        if expenseStartOfDay < phaseStartOfDay || expenseStartOfDay > phaseEndOfDay {
                            continue
                        }
                        
                        // Also filter by selected date range if applicable
                        let filterStartOfDay = calendar.startOfDay(for: self.startDate)
                        let filterEndOfDay = calendar.startOfDay(for: self.endDate)
                        
                        if expenseStartOfDay < filterStartOfDay || expenseStartOfDay > filterEndOfDay {
                            continue
                        }
                        
                        // Extract department name from expense
                        let expenseDepartmentName: String
                        if let underscoreIndex = expense.department.firstIndex(of: "_") {
                            expenseDepartmentName = String(expense.department[expense.department.index(after: underscoreIndex)...])
                        } else {
                            expenseDepartmentName = expense.department
                        }
                        
                        // Filter by department if specific departments are selected
                        if !selectedDepartments.isEmpty && !selectedDepartments.contains(expenseDepartmentName) {
                            continue
                        }
                        
                        phaseActual += expense.amount
                        hasExpenses = true
                    }
                    
                    // Calculate overrun %
                    var overrun: Double = 0.0
                    if phaseBudget > 0 {
                        overrun = ((phaseActual - phaseBudget) / phaseBudget) * 100.0
                    }
                    
                    // Condition 1: Show if spent exceeds budget (overrun > 0)
                    // Condition 2: Show if progress > 25% and no expenses (show negative)
                    let shouldShow: Bool
                    if overrun > 0 {
                        // Condition 1: Spent exceeds budget
                        shouldShow = true
                    } else if progress > 25.0 && !hasExpenses && phaseBudget > 0 {
                        // Condition 2: Progress > 25% with no expenses - show as negative
                        // Use a default negative value (e.g., -5% or calculate based on expected spend)
                        overrun = -5.0 // Default negative value as shown in the image
                        shouldShow = true
                    } else {
                        shouldShow = false
                    }
                    
                    if shouldShow {
                        // Handle same phase names across projects - use the one with higher overrun or later progress
                        if let existing = overrunDataMap[phaseName] {
                            // Keep the one with higher absolute overrun or higher progress
                            if abs(overrun) > abs(existing.overrun) || progress > existing.progress {
                                overrunDataMap[phaseName] = (progress: progress, overrun: overrun)
                            }
                        } else {
                            overrunDataMap[phaseName] = (progress: progress, overrun: overrun)
                        }
                    }
                }
            } catch {
                Swift.print("Error calculating overrun data for project \(projectId): \(error)")
            }
        }
        
        // Convert to array
        let overrunDataArray = overrunDataMap.map { phaseName, values in
            OverrunData(stage: phaseName, progress: values.progress, overrun: values.overrun)
        }
        
        await MainActor.run {
            overrunData = overrunDataArray
        }
    }
    
    /// Calculate total approved expenses by project for last 30 days
    /// Shows total spend amount, sorted by amount (highest on top, lowest on bottom)
    /// Only includes projects with totalSpend > 0
    private func calculateBurnRate() async {
        guard let customerId = customerId else {
            await MainActor.run {
                burnRateData = []
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
        
        let calendar = Calendar.current
        let now = Date()
        
        // Get date 30 days ago (using createdAt timestamp)
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else {
            await MainActor.run {
                burnRateData = []
            }
            return
        }
        
        let thirtyDaysAgoTimestamp = Timestamp(date: thirtyDaysAgo)
        
        var projectSpendMap: [String: Double] = [:] // projectName -> totalSpend
        
        // Process each project
        for project in projectsToProcess {
            guard let projectId = project.id else { continue }
            let projectName = project.name
            
            // Filter by project status
            var projectStatus: String? = nil
            if project.isSuspended == true {
                projectStatus = "SUSPENDED"
            } else {
                projectStatus = project.status
            }
            
            guard let status = projectStatus, selectedProjectStatuses.contains(status) else {
                continue
            }
            
            do {
                // Load expenses for this project that are APPROVED and created within last 30 days
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerId, projectId: projectId)
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .whereField("createdAt", isGreaterThanOrEqualTo: thirtyDaysAgoTimestamp)
                    .getDocuments()
                
                var totalSpend: Double = 0
                
                // Process each approved expense
                for expenseDoc in expensesSnapshot.documents {
                    guard let expense = try? expenseDoc.data(as: Expense.self) else { continue }
                    
                    // Double-check createdAt is within last 30 days (in case of timezone issues)
                    let expenseCreatedAt = expense.createdAt.dateValue()
                    if expenseCreatedAt < thirtyDaysAgo {
                        continue
                    }
                    
                    // Filter by stage if specific stages are selected
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
                    
                    // Filter by department if specific departments are selected
                    if !selectedDepartments.isEmpty && !selectedDepartments.contains(expenseDepartmentName) {
                        continue
                    }
                    
                    totalSpend += expense.amount
                }
                
                // Only include projects with totalSpend > 0
                if totalSpend > 0 {
                    projectSpendMap[projectName] = totalSpend
                }
            } catch {
                Swift.print("Error calculating burn rate for project \(projectId): \(error)")
            }
        }
        
        // Convert to array, sort by totalSpend (descending - highest on top, lowest on bottom)
        let burnRateArray = projectSpendMap.map { projectName, totalSpend in
            BurnRateData(project: projectName, totalSpend: totalSpend)
        }.sorted { $0.totalSpend > $1.totalSpend }
        
        await MainActor.run {
            burnRateData = burnRateArray
        }
    }
    
    /// Calculate suspended projects by reason - counts projects with isSuspended == true grouped by suspensionReason
    /// Sorted by count (highest on top)
    private func calculateSuspensionReasons() async {
        // Filter projects where isSuspended == true
        let suspendedProjects = projects.filter { $0.isSuspended == true }
        
        // Group by suspensionReason and count, also track project names
        var reasonCountMap: [String: Int] = [:]
        var reasonProjects: [String: Set<String>] = [:] // Track unique project names per reason
        
        for project in suspendedProjects {
            // Get suspension reason, use "Unknown" if nil or empty
            let reason = project.suspensionReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
            let finalReason = reason.isEmpty ? "Unknown" : reason
            
            reasonCountMap[finalReason, default: 0] += 1
            reasonProjects[finalReason, default: Set<String>()].insert(project.name)
        }
        
        // Convert to array and sort by count (descending - highest on top)
        let suspensionReasonArray = reasonCountMap.map { reason, count in
            let projectNames = Array(reasonProjects[reason] ?? Set<String>()).sorted()
            return SuspensionReasonData(
                reason: reason,
                count: count,
                projectNames: projectNames
            )
        }.sorted { $0.count > $1.count }
        
        await MainActor.run {
            suspensionReasonData = suspensionReasonArray
        }
    }
    
    /// Calculate delay correlation data (Extended Days vs Extra Cost)
    /// Shows projects that satisfy either:
    /// 1. budget > estimatedBudget (extra cost condition)
    /// 2. Has phases with extended keyword (extended days condition)
    private func calculateDelayCorrelation() async {
        guard let customerId = customerId else {
            await MainActor.run {
                delayCorrelationData = []
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
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        let calendar = Calendar.current
        
        var correlationData: [DelayCorrelationData] = []
        
        // Process each project
        for project in projectsToProcess {
            guard let projectId = project.id else { continue }
            
            var extendedDays: Double = 0.0
            var extraCost: Double = 0.0
            var hasCondition1 = false
            var hasCondition2 = false
            
            // Condition 1: Check if budget > estimatedBudget
            if let estimatedBudget = project.estimatedBudget, project.budget > estimatedBudget {
                extraCost = project.budget - estimatedBudget
                hasCondition1 = true
            }
            
            // Condition 2: Calculate extended days from phase requests with "extended" keyword
            do {
                // Load all phases for this project
                let phasesSnapshot = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .getDocuments()
                
                var totalExtendedDays: Double = 0.0
                
                // Process each phase
                for phaseDoc in phasesSnapshot.documents {
                    let phaseId = phaseDoc.documentID
                    
                    // Get phase end date (current end date, which might already be extended)
                    guard let phaseData = phaseDoc.data() as? [String: Any],
                          let phaseEndDateStr = phaseData["endDate"] as? String,
                          let phaseEndDate = dateFormatter.date(from: phaseEndDateStr) else {
                        continue
                    }
                    
                    // Query requests collection for approved requests with extendedDate
                    let requestsSnapshot = try await FirebasePathHelper.shared
                        .phasesCollection(customerId: customerId, projectId: projectId)
                        .document(phaseId)
                        .collection("requests")
                        .whereField("status", isEqualTo: "APPROVED")
                        .getDocuments()
                    
                    // Check if any approved request has extendedDate (indicates extension)
                    for requestDoc in requestsSnapshot.documents {
                        let requestData = requestDoc.data()
                        let requestId = requestDoc.documentID
                        
                        if let extendedDateStr = requestData["extendedDate"] as? String,
                           let extendedDate = dateFormatter.date(from: extendedDateStr) {
                            
                            // Try to get the original end date from PhaseTimelineChange
                            var originalEndDate: Date? = nil
                            
                            // Query PhaseTimelineChange collection for this phase
                            let changesSnapshot = try? await FirebasePathHelper.shared
                                .phasesCollection(customerId: customerId, projectId: projectId)
                                .document(phaseId)
                                .collection("changes")
                                .whereField("requestID", isEqualTo: requestId)
                                .order(by: "updatedAt", descending: false)
                                .limit(to: 1)
                                .getDocuments()
                            
                            if let changesSnapshot = changesSnapshot, !changesSnapshot.documents.isEmpty {
                                // Found a timeline change entry for this request
                                if let changeDoc = changesSnapshot.documents.first,
                                   let change = try? changeDoc.data(as: PhaseTimelineChange.self),
                                   let previousEndDateStr = change.previousEndDate,
                                   let previousEndDate = dateFormatter.date(from: previousEndDateStr) {
                                    originalEndDate = previousEndDate
                                }
                            }
                            
                            // Use original end date if found, otherwise use current phase end date as fallback
                            let baselineDate = originalEndDate ?? phaseEndDate
                            
                            // Calculate days extended (difference between extended date and original end date)
                            let daysExtended = calendar.dateComponents([.day], from: baselineDate, to: extendedDate).day ?? 0
                            if daysExtended > 0 {
                                totalExtendedDays += Double(daysExtended)
                                hasCondition2 = true
                            }
                        }
                    }
                }
                
                extendedDays = totalExtendedDays
            } catch {
                print("Error calculating extended days for project \(project.name): \(error)")
            }
            
            // Only include projects that satisfy at least one condition
            if hasCondition1 || hasCondition2 {
                correlationData.append(DelayCorrelationData(
                    project: project.name,
                    delayDays: extendedDays,
                    extraCost: extraCost
                ))
            }
        }
        
        await MainActor.run {
            delayCorrelationData = correlationData
        }
    }
}

