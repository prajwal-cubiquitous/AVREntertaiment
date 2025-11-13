//
//  ReportViewModel.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 7/10/25.
//
import Foundation
import FirebaseFirestore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
class ReportViewModel: ObservableObject {
    @Published var departmentBudgets: [DepartmentBudget] = []
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var departmentNames: [String] = []
    @Published var phases: [PhaseInfo] = []
    
    // Filter properties
    @Published var selectedDateRange: DateRange = .thisMonth
    @Published var selectedDepartment: String = "All"
    @Published var selectedPhase: PhaseInfo? = nil
    
    private let db = Firestore.firestore()
    private var customerId: String?
    private var projectId: String?
    
    // Date formatter for phase dates
    private let phaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    // MARK: - Date Range Enum
    enum DateRange: String, CaseIterable, CustomStringConvertible {
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case thisQuarter = "This Quarter"
        case thisYear = "This Year"
        case custom = "Custom"
        
        var description: String {
            return self.rawValue
        }
        
        var dateInterval: DateInterval {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .thisMonth:
                let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
                return DateInterval(start: startOfMonth, end: endOfMonth)
                
            case .lastMonth:
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                let startOfMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start ?? now
                let endOfMonth = calendar.dateInterval(of: .month, for: lastMonth)?.end ?? now
                return DateInterval(start: startOfMonth, end: endOfMonth)
                
            case .thisQuarter:
                let quarter = calendar.component(.quarter, from: now)
                let year = calendar.component(.year, from: now)
                let startMonth = (quarter - 1) * 3 + 1
                let startOfQuarter = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)) ?? now
                let endOfQuarter = calendar.date(byAdding: DateComponents(month: 3, day: -1), to: startOfQuarter) ?? now
                return DateInterval(start: startOfQuarter, end: endOfQuarter)
                
            case .thisYear:
                let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
                let endOfYear = calendar.dateInterval(of: .year, for: now)?.end ?? now
                return DateInterval(start: startOfYear, end: endOfYear)
                
            case .custom:
                return DateInterval(start: now, end: now)
            }
        }
    }
    
    // MARK: - Initialization
    func initialize(projectId: String, customerId: String) {
        self.projectId = projectId
        self.customerId = customerId
    }
    
    func fetchDepartmentNames(from documentID: String) async throws {
        guard let customerId = try? await FirebasePathHelper.shared.fetchEffectiveUserID() else {
            print("Error: Could not fetch customer ID")
            return
        }
        
        do {
            let projectDoc = try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: documentID)
                .getDocument()
            
            guard let data = projectDoc.data(),
                  let departments = data["departments"] as? [String: Any] else {
                print("Departments field missing or wrong type.")
                return
            }
            
            var keys = Array(departments.keys).sorted()
            keys.insert("All", at: 0) // Add "All" at the beginning
            
            // Check if there are any anonymous expenses (Other Expenses)
            let expensesSnapshot = try await FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: documentID)
                .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                .getDocuments()
            
            let validDepartments = Set(departments.keys)
            var hasAnonymousExpenses = false
            
            for expenseDoc in expensesSnapshot.documents {
                if let expense = try? expenseDoc.data(as: Expense.self) {
                    if !validDepartments.contains(expense.department) {
                        hasAnonymousExpenses = true
                        break
                    }
                }
            }
            
            if hasAnonymousExpenses {
                keys.append("Other Expenses")
            }
            
            await MainActor.run {
                self.departmentNames = keys
            }
        } catch {
            print("Error fetching department names: \(error)")
        }
    }
    
    // MARK: - Load Phases
    func loadPhases(projectId: String) async {
        guard let customerId = try? await FirebasePathHelper.shared.fetchEffectiveUserID() else {
            print("Error: Could not fetch customer ID")
            return
        }
        
        do {
            let snapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .order(by: "phaseNumber")
                .getDocuments()
            
            var phasesList: [PhaseInfo] = []
            
            for doc in snapshot.documents {
                if let phase = try? doc.data(as: Phase.self) {
                    let startDate = phase.startDate.flatMap { phaseDateFormatter.date(from: $0) }
                    let endDate = phase.endDate.flatMap { phaseDateFormatter.date(from: $0) }
                    
                    phasesList.append(PhaseInfo(
                        id: doc.documentID,
                        name: phase.phaseName,
                        start: startDate,
                        end: endDate,
                        departments: phase.departments
                    ))
                }
            }
            
            await MainActor.run {
                self.phases = phasesList
                // Reset department selection if current department is not in the newly selected phase
                if let selectedPhase = self.selectedPhase {
                    let phaseDepartments = selectedPhase.departments.keys.map { deptKey in
                        if let underscoreIndex = deptKey.firstIndex(of: "_") {
                            return String(deptKey[deptKey.index(after: underscoreIndex)...])
                        } else {
                            return deptKey
                        }
                    }
                    if self.selectedDepartment != "All" && 
                       self.selectedDepartment != "Other Expenses" &&
                       !phaseDepartments.contains(self.selectedDepartment) {
                        self.selectedDepartment = "All"
                    }
                }
            }
        } catch {
            print("Error loading phases: \(error)")
        }
    }
    
    // MARK: - Phase Info Model
    struct PhaseInfo: Identifiable, Hashable, CustomStringConvertible {
        let id: String
        let name: String
        let start: Date?
        let end: Date?
        let departments: [String: Double]
        
        var description: String {
            return name
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: PhaseInfo, rhs: PhaseInfo) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    // Computed property to get filtered department names based on selected phase
    var filteredDepartmentNames: [String] {
        var departments: [String] = []
        
        if let selectedPhase = selectedPhase {
            // Extract department names from phase departments dictionary
            // Handle both "phaseId_departmentName" and "departmentName" formats
            for deptKey in selectedPhase.departments.keys {
                let displayName: String
                if let underscoreIndex = deptKey.firstIndex(of: "_") {
                    // New format: remove "phaseId_" prefix
                    displayName = String(deptKey[deptKey.index(after: underscoreIndex)...])
                } else {
                    // Old format: use as is
                    displayName = deptKey
                }
                departments.append(displayName)
            }
            
            // Sort and add "All" at the beginning
            departments = departments.sorted()
            departments.insert("All", at: 0)
            
            // Check for "Other Expenses" in the phase's expenses
            // This would require checking expenses, but for now we'll keep it simple
            // and add "Other Expenses" if it exists in the original departmentNames
            if departmentNames.contains("Other Expenses") {
                departments.append("Other Expenses")
            }
        } else {
            // No phase selected, show all departments
            departments = departmentNames
        }
        
        return departments
    }
    
    var filteredExpenses: [Expense] {
        let dateInterval = selectedDateRange.dateInterval
        var filtered = expenses
        
        // Filter by date range (using expense date, not createdAt)
        filtered = filtered.filter { expense in
            let expenseDateStr = expense.date
            let expenseDate = phaseDateFormatter.date(from: expenseDateStr) ?? expense.createdAt.dateValue()
            return dateInterval.contains(expenseDate)
        }
        
        // Filter by phase timeline
        if let selectedPhase = selectedPhase {
            filtered = filtered.filter { expense in
                // Check if expense belongs to the selected phase
                if let expensePhaseId = expense.phaseId {
                    return expensePhaseId == selectedPhase.id
                }
                // If expense has no phaseId, check if expense date falls within phase timeline
                if let phaseStart = selectedPhase.start, let phaseEnd = selectedPhase.end {
                    let expenseDateStr = expense.date
                    if let expenseDate = phaseDateFormatter.date(from: expenseDateStr) {
                        let calendar = Calendar.current
                        let startOfDay = calendar.startOfDay(for: phaseStart)
                        let endOfDay = calendar.startOfDay(for: phaseEnd)
                        let expenseStartOfDay = calendar.startOfDay(for: expenseDate)
                        return expenseStartOfDay >= startOfDay && expenseStartOfDay <= endOfDay
                    }
                }
                return false
            }
        }
        
        // Filter by department
        if selectedDepartment != "All" {
            if selectedDepartment == "Other Expenses" {
                // Filter for expenses not in valid departments
                let validDepartments = Set(filteredDepartmentNames.filter { $0 != "All" && $0 != "Other Expenses" })
                filtered = filtered.filter { !validDepartments.contains($0.department) }
            } else {
                filtered = filtered.filter { $0.department == selectedDepartment }
            }
        }
        
        return filtered
    }
    
    // Bar chart data for expense categories
    var expenseCategories: [ExpenseCategory] {
        let categories = Dictionary(grouping: filteredExpenses) { expense in
            // Use the first category from the categories array, or "Other" if empty
            expense.categories.first ?? "Other"
        }
        return categories.map { category, expenses in
            ExpenseCategory(
                name: category,
                amount: expenses.reduce(0) { $0 + $1.amount }
            )
        }.sorted { $0.amount > $1.amount }
    }
    
    func loadApprovedExpenses(projectId: String) async {
        guard let customerId = try? await FirebasePathHelper.shared.fetchEffectiveUserID() else {
            print("Error: Could not fetch customer ID")
            return
        }
        
        do {
            let expenseCollectionRef = FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: projectId)
            
            let snapshot: QuerySnapshot
            if selectedDepartment != "All" && selectedDepartment != "Other Expenses" {
                snapshot = try await expenseCollectionRef
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .whereField("department", isEqualTo: selectedDepartment)
                    .getDocuments()
            } else {
                snapshot = try await expenseCollectionRef
                    .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                    .getDocuments()
            }
            
            var loadedExpenses: [Expense] = []
            for doc in snapshot.documents {
                if let expense = try? doc.data(as: Expense.self) {
                    loadedExpenses.append(expense)
                }
            }
            
            // Filter for "Other Expenses" if selected
            if selectedDepartment == "Other Expenses" {
                // Get valid departments from project
                let projectDoc = try await FirebasePathHelper.shared
                    .projectDocument(customerId: customerId, projectId: projectId)
                    .getDocument()
                
                guard let projectData = projectDoc.data(),
                      let departments = projectData["departments"] as? [String: Double] else {
                    await MainActor.run {
                        self.expenses = []
                    }
                    return
                }
                
                let validDepartments = Set(departments.keys)
                loadedExpenses = loadedExpenses.filter { expense in
                    !validDepartments.contains(expense.department)
                }
            }
            
            // Filter by phase if selected
            if let selectedPhase = selectedPhase {
                loadedExpenses = loadedExpenses.filter { expense in
                    // Check if expense belongs to the selected phase
                    if let expensePhaseId = expense.phaseId {
                        return expensePhaseId == selectedPhase.id
                    }
                    // If expense has no phaseId, check if expense date falls within phase timeline
                    if let phaseStart = selectedPhase.start, let phaseEnd = selectedPhase.end {
                        let expenseDateStr = expense.date
                        if let expenseDate = phaseDateFormatter.date(from: expenseDateStr) {
                            let calendar = Calendar.current
                            let startOfDay = calendar.startOfDay(for: phaseStart)
                            let endOfDay = calendar.startOfDay(for: phaseEnd)
                            let expenseStartOfDay = calendar.startOfDay(for: expenseDate)
                            return expenseStartOfDay >= startOfDay && expenseStartOfDay <= endOfDay
                        }
                    }
                    return false
                }
            }
            
            // Assign to your published expenses list on the main thread
            await MainActor.run {
                self.expenses = loadedExpenses
            }
        } catch {
            print("Failed to load approved expenses: \(error)")
        }
    }
    
    func loadDepartmentBudgets(projectId: String) async {
        guard let customerId = try? await FirebasePathHelper.shared.fetchEffectiveUserID() else {
            print("Error: Could not fetch customer ID")
            return
        }
        
        do {
            // Get the project document
            let projectDoc = try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .getDocument()
            
            guard let projectData = projectDoc.data(),
                  let departments = projectData["departments"] as? [String: Double] else {
                print("No departments found in project")
                return
            }
            
            // Calculate approved expenses for each department
            var departmentBudgetDict: [String: (total: Double, approved: Double)] = [:]
            var anonymousExpenses: Double = 0
            
            // If phase is selected, use phase budgets; otherwise use project budgets
            if let selectedPhase = selectedPhase {
                // Use phase-specific department budgets
                for (department, amount) in selectedPhase.departments {
                    departmentBudgetDict[department] = (total: amount, approved: 0)
                }
            } else {
                // Initialize with project department budgets
                for (department, amount) in departments {
                    departmentBudgetDict[department] = (total: amount, approved: 0)
                }
            }
            
            // Get approved expenses for this project (filtered by phase if selected)
            let expensesSnapshot = try await FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: projectId)
                .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                .getDocuments()
            
            let validDepartments = Set(departments.keys)
            let dateInterval = selectedDateRange.dateInterval
            
            // Calculate approved amounts per department (using filtered expenses)
            for expenseDoc in expensesSnapshot.documents {
                if let expense = try? expenseDoc.data(as: Expense.self) {
                    // Filter by date range
                    let expenseDateStr = expense.date
                    let expenseDate = phaseDateFormatter.date(from: expenseDateStr) ?? expense.createdAt.dateValue()
                    guard dateInterval.contains(expenseDate) else { continue }
                    
                    // Filter by phase if selected
                    if let selectedPhase = selectedPhase {
                        if let expensePhaseId = expense.phaseId {
                            guard expensePhaseId == selectedPhase.id else { continue }
                        } else {
                            // Check if expense date falls within phase timeline
                            if let phaseStart = selectedPhase.start, let phaseEnd = selectedPhase.end {
                                let calendar = Calendar.current
                                let startOfDay = calendar.startOfDay(for: phaseStart)
                                let endOfDay = calendar.startOfDay(for: phaseEnd)
                                let expenseStartOfDay = calendar.startOfDay(for: expenseDate)
                                guard expenseStartOfDay >= startOfDay && expenseStartOfDay <= endOfDay else { continue }
                            } else {
                                continue
                            }
                        }
                    }
                    
                    // Filter by department if selected
                    if selectedDepartment != "All" {
                        if selectedDepartment == "Other Expenses" {
                            guard !validDepartments.contains(expense.department) else { continue }
                        } else {
                            guard expense.department == selectedDepartment else { continue }
                        }
                    }
                    
                    let department = expense.department
                    
                    if validDepartments.contains(department) {
                        // Department exists in project, add to normal spending
                        if var current = departmentBudgetDict[department] {
                            current.approved += expense.amount
                            departmentBudgetDict[department] = current
                        }
                    } else {
                        // Department doesn't exist in project, add to anonymous
                        anonymousExpenses += expense.amount
                    }
                }
            }
            
            // Convert to DepartmentBudget objects
            let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .yellow, .mint]
            var budgets = departmentBudgetDict.enumerated().map { index, entry in
                DepartmentBudget(
                    department: entry.key,
                    totalBudget: entry.value.total,
                    approvedBudget: entry.value.approved,
                    color: colors[index % colors.count]
                )
            }
            
            // Add anonymous department if there are expenses
            if anonymousExpenses > 0 {
                let anonymousBudget = DepartmentBudget(
                    department: "Other Expenses",
                    totalBudget: 0, // No allocated budget for anonymous expenses
                    approvedBudget: anonymousExpenses,
                    color: .gray
                )
                budgets.append(anonymousBudget)
            }
            
            await MainActor.run {
                self.departmentBudgets = budgets.sorted { $0.totalBudget > $1.totalBudget }
            }
            
        } catch {
            print("Failed to load department budgets: \(error)")
            // Load sample data if Firebase fails
            await loadSampleDepartmentBudgets()
        }
    }
    
    private func loadSampleDepartmentBudgets() async {
        let sampleBudgets = [
            DepartmentBudget(
                department: "Set Design",
                totalBudget: 300000,
                approvedBudget: 210000,
                color: .blue
            ),
            DepartmentBudget(
                department: "Costumes",
                totalBudget: 100000,
                approvedBudget: 55000,
                color: .green
            ),
            DepartmentBudget(
                department: "Miscellaneous",
                totalBudget: 50000,
                approvedBudget: 20000,
                color: .purple
            )
        ]
        
        await MainActor.run {
            self.departmentBudgets = sampleBudgets
        }
    }
    
    // MARK: - Export Functions
    func exportToPDF() {
        Task {
            do {
                let pdfData = try await generatePDFReport()
                let fileName = "AVR_Entertainment_Report_\(Date().formatted(.dateTime.day().month().year())).pdf"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                try pdfData.write(to: tempURL)
                await presentShareSheet(url: tempURL)
                
                HapticManager.notification(.success)
            } catch {
                print("Failed to generate PDF: \(error)")
                HapticManager.notification(.error)
            }
        }
    }
    
    func exportToExcel() {
        Task {
            do {
                let csvData = try await generateExcelReport()
                let fileName = "AVR_Entertainment_Report_\(Date().formatted(.dateTime.day().month().year())).csv"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                try csvData.write(to: tempURL, atomically: true, encoding: .utf8)
                await presentShareSheet(url: tempURL)
                
                HapticManager.notification(.success)
            } catch {
                print("Failed to generate Excel: \(error)")
                HapticManager.notification(.error)
            }
        }
    }
    
    // MARK: - PDF Generation
    private func generatePDFReport() async throws -> Data {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)) // A4 size
        
        let pdfData = pdfRenderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 40
            let leftMargin: CGFloat = 50
            let rightMargin: CGFloat = 545
            let contentWidth: CGFloat = rightMargin - leftMargin
            
            // MARK: - Header Section with Brand Identity
            // Company Logo Area
            let logoRect = CGRect(x: leftMargin, y: yPosition, width: 40, height: 40)
            UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0).setFill() // Strong blue
            UIBezierPath(roundedRect: logoRect, cornerRadius: 8).fill()
            
            // Add "AVR" text as logo
            let logoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.white
            ]
            "".draw(in: logoRect, withAttributes: logoAttributes)
            
            // Company Header
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor.black
            ]
            "".draw(at: CGPoint(x: leftMargin + 50, y: yPosition), withAttributes: headerAttributes)
            
            let subHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
            ]
            "Project Financial Report".draw(at: CGPoint(x: leftMargin + 50, y: yPosition + 30), withAttributes: subHeaderAttributes)
            
            yPosition += 70
            
            // MARK: - Report Metadata Section
            drawSectionDivider(yPosition: &yPosition, leftMargin: leftMargin, rightMargin: rightMargin)
            
            let metaBoxY = yPosition
            let metaBoxHeight: CGFloat = 80
            
            // Background for metadata - darker gray
            UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0).setFill() // Dark gray
            UIBezierPath(roundedRect: CGRect(x: leftMargin, y: metaBoxY, width: contentWidth, height: metaBoxHeight), cornerRadius: 8).fill()
            
            let metaLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.white
            ]
            let metaValueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
            ]
            
            // Left column metadata
            "Report Generated:".draw(at: CGPoint(x: leftMargin + 15, y: metaBoxY + 15), withAttributes: metaLabelAttributes)
            Date().formatted(.dateTime.day().month().year().hour().minute()).draw(at: CGPoint(x: leftMargin + 15, y: metaBoxY + 35), withAttributes: metaValueAttributes)
            
            "System Version:".draw(at: CGPoint(x: leftMargin + 15, y: metaBoxY + 50), withAttributes: metaLabelAttributes)
            "v1.0.2".draw(at: CGPoint(x: leftMargin + 15, y: metaBoxY + 65), withAttributes: metaValueAttributes)
            
            // Right column metadata
            "Report Period:".draw(at: CGPoint(x: leftMargin + 250, y: metaBoxY + 15), withAttributes: metaLabelAttributes)
            selectedDateRange.description.draw(at: CGPoint(x: leftMargin + 250, y: metaBoxY + 35), withAttributes: metaValueAttributes)
            
            "Department Filter:".draw(at: CGPoint(x: leftMargin + 250, y: metaBoxY + 50), withAttributes: metaLabelAttributes)
            selectedDepartment.draw(at: CGPoint(x: leftMargin + 250, y: metaBoxY + 65), withAttributes: metaValueAttributes)
            
            // Phase information if selected
            if let selectedPhase = selectedPhase {
                let phaseInfoY = metaBoxY + 80
                let extendedHeight: CGFloat = 40
                // Extend metadata box
                UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0).setFill()
                UIBezierPath(roundedRect: CGRect(x: leftMargin, y: metaBoxY, width: contentWidth, height: metaBoxHeight + extendedHeight), cornerRadius: 8).fill()
                
                "Phase Filter:".draw(at: CGPoint(x: leftMargin + 15, y: phaseInfoY + 15), withAttributes: metaLabelAttributes)
                selectedPhase.name.draw(at: CGPoint(x: leftMargin + 15, y: phaseInfoY + 35), withAttributes: metaValueAttributes)
                
                if let phaseStart = selectedPhase.start, let phaseEnd = selectedPhase.end {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "dd/MM/yyyy"
                    let phaseRange = "\(dateFormatter.string(from: phaseStart)) - \(dateFormatter.string(from: phaseEnd))"
                    "Phase Timeline:".draw(at: CGPoint(x: leftMargin + 250, y: phaseInfoY + 15), withAttributes: metaLabelAttributes)
                    phaseRange.draw(at: CGPoint(x: leftMargin + 250, y: phaseInfoY + 35), withAttributes: metaValueAttributes)
                }
                
                yPosition += extendedHeight
            }
            
            yPosition += metaBoxHeight + 30
            
            // MARK: - Executive Summary Section
            drawSectionHeader(title: "Executive Summary", yPosition: &yPosition, leftMargin: leftMargin, icon: "📊")
            
            let totalExpenses = filteredExpenses.reduce(0) { $0 + $1.amount }
            let totalBudget = departmentBudgets.reduce(0) { $0 + $1.totalBudget }
            let totalSpent = departmentBudgets.reduce(0) { $0 + $1.approvedBudget }
            let remainingBudget = totalBudget - totalSpent
            let utilizationPercentage = totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0
            
            // Summary cards with darker colors
            let cardWidth: CGFloat = (contentWidth - 20) / 3
            let cardHeight: CGFloat = 60
            
            // Total Expenses Card
            drawSummaryCard(
                title: "Total Expenses",
                value: "₹\(Int(totalExpenses).formatted())",
                x: leftMargin,
                y: yPosition,
                width: cardWidth,
                height: cardHeight,
                color: UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0) // Strong blue
            )
            
            // Budget Utilization Card
            drawSummaryCard(
                title: "Budget Utilization",
                value: "\(Int(utilizationPercentage))%",
                x: leftMargin + cardWidth + 10,
                y: yPosition,
                width: cardWidth,
                height: cardHeight,
                color: utilizationPercentage > 80 ? UIColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 1.0) : UIColor(red: 0.0, green: 0.667, blue: 0.0, alpha: 1.0) // Orange or Green
            )
            
            // Remaining Budget Card
            drawSummaryCard(
                title: "Remaining Budget",
                value: "₹\(Int(remainingBudget).formatted())",
                x: leftMargin + (cardWidth + 10) * 2,
                y: yPosition,
                width: cardWidth,
                height: cardHeight,
                color: remainingBudget < 0 ? UIColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1.0) : UIColor(red: 0.0, green: 0.667, blue: 0.0, alpha: 1.0) // Red or Green
            )
            
            yPosition += cardHeight + 30
            
            // MARK: - Expense Categories Section
            drawSectionHeader(title: "Expense Categories Breakdown", yPosition: &yPosition, leftMargin: leftMargin, icon: "📈")
            
            if !expenseCategories.isEmpty {
                // Draw bar chart visualization
                drawBarChart(yPosition: &yPosition, leftMargin: leftMargin, contentWidth: contentWidth)
                
                let tableY = yPosition
                let rowHeight: CGFloat = 25
                let headerHeight: CGFloat = 30
                
                // Table header background - darker
                UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0).setFill() // Dark gray
                UIBezierPath(rect: CGRect(x: leftMargin, y: tableY, width: contentWidth, height: headerHeight)).fill()
                
                let tableHeaderAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 12),
                    .foregroundColor: UIColor.white
                ]
                
                "Category".draw(at: CGPoint(x: leftMargin + 10, y: tableY + 8), withAttributes: tableHeaderAttributes)
                "Amount".draw(at: CGPoint(x: leftMargin + 200, y: tableY + 8), withAttributes: tableHeaderAttributes)
                "Percentage".draw(at: CGPoint(x: leftMargin + 320, y: tableY + 8), withAttributes: tableHeaderAttributes)
                "Visual".draw(at: CGPoint(x: leftMargin + 420, y: tableY + 8), withAttributes: tableHeaderAttributes)
                
                yPosition += headerHeight
                
                let tableRowAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.black
                ]
                
                for (index, category) in expenseCategories.enumerated() {
                    let rowY = yPosition + CGFloat(index) * rowHeight
                    let percentage = totalExpenses > 0 ? (category.amount / totalExpenses) * 100 : 0
                    
                    // Alternating row background - light gray
                    if index % 2 == 0 {
                        UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0).setFill()
                        UIBezierPath(rect: CGRect(x: leftMargin, y: rowY, width: contentWidth, height: rowHeight)).fill()
                    }
                    
                    category.name.draw(at: CGPoint(x: leftMargin + 10, y: rowY + 6), withAttributes: tableRowAttributes)
                    category.formattedAmount.draw(at: CGPoint(x: leftMargin + 200, y: rowY + 6), withAttributes: tableRowAttributes)
                    "\(Int(percentage))%".draw(at: CGPoint(x: leftMargin + 320, y: rowY + 6), withAttributes: tableRowAttributes)
                    
                    // Visual percentage bar - darker blue
                    let barWidth = contentWidth * 0.15 * (percentage / 100)
                    let barRect = CGRect(x: leftMargin + 420, y: rowY + 8, width: barWidth, height: 8)
                    UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0).setFill()
                    UIBezierPath(roundedRect: barRect, cornerRadius: 4).fill()
                }
                
                yPosition += CGFloat(expenseCategories.count) * rowHeight + 20
            }
            
            // MARK: - Department Budget Analysis
            drawSectionHeader(title: "Department Budget Analysis", yPosition: &yPosition, leftMargin: leftMargin, icon: "🏢")
            
            if !departmentBudgets.isEmpty {
                let tableY = yPosition
                let rowHeight: CGFloat = 30
                let headerHeight: CGFloat = 35
                
                // Enhanced table header - darker
                UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 0.2).setFill()
                UIBezierPath(rect: CGRect(x: leftMargin, y: tableY, width: contentWidth, height: headerHeight)).fill()
                
                let tableHeaderAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 12),
                    .foregroundColor: UIColor.black
                ]
                
                "Department".draw(at: CGPoint(x: leftMargin + 10, y: tableY + 10), withAttributes: tableHeaderAttributes)
                "Budget".draw(at: CGPoint(x: leftMargin + 150, y: tableY + 10), withAttributes: tableHeaderAttributes)
                "Spent".draw(at: CGPoint(x: leftMargin + 250, y: tableY + 10), withAttributes: tableHeaderAttributes)
                "Remaining".draw(at: CGPoint(x: leftMargin + 350, y: tableY + 10), withAttributes: tableHeaderAttributes)
                "Status".draw(at: CGPoint(x: leftMargin + 450, y: tableY + 10), withAttributes: tableHeaderAttributes)
                
                yPosition += headerHeight
                
                let tableRowAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.black
                ]
                
                for (index, budget) in departmentBudgets.enumerated() {
                    let rowY = yPosition + CGFloat(index) * rowHeight
                    let remaining = budget.totalBudget - budget.approvedBudget
                    let utilization = budget.totalBudget > 0 ? (budget.approvedBudget / budget.totalBudget) : 0
                    
                    // Special handling for "Other Expenses"
                    let displayAmount = budget.department == "Other Expenses" ? budget.approvedBudget : remaining
                    let displayColor = budget.department == "Other Expenses" ? UIColor(red: 0.0, green: 0.667, blue: 0.0, alpha: 1.0) : (remaining < 0 ? UIColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1.0) : UIColor(red: 0.0, green: 0.667, blue: 0.0, alpha: 1.0))
                    
                    // Row background with borders - white with dark border
                    UIColor.white.setFill()
                    UIBezierPath(rect: CGRect(x: leftMargin, y: rowY, width: contentWidth, height: rowHeight)).fill()
                    
                    UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0).setStroke()
                    let borderPath = UIBezierPath(rect: CGRect(x: leftMargin, y: rowY, width: contentWidth, height: rowHeight))
                    borderPath.lineWidth = 0.5
                    borderPath.stroke()
                    
                    budget.department.draw(at: CGPoint(x: leftMargin + 10, y: rowY + 8), withAttributes: tableRowAttributes)
                    "₹\(Int(budget.totalBudget).formatted())".draw(at: CGPoint(x: leftMargin + 150, y: rowY + 8), withAttributes: tableRowAttributes)
                    "₹\(Int(budget.approvedBudget).formatted())".draw(at: CGPoint(x: leftMargin + 250, y: rowY + 8), withAttributes: tableRowAttributes)
                    
                    // Color-coded remaining amount - darker colors
                    let remainingAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11),
                        .foregroundColor: displayColor
                    ]
                    "₹\(Int(displayAmount).formatted())".draw(at: CGPoint(x: leftMargin + 350, y: rowY + 8), withAttributes: remainingAttributes)
                    
                    // Status indicator with darker colors
                    let statusText: String
                    let statusColor: UIColor
                    if budget.department == "Other Expenses" {
                        statusText = "📊 Other Expenses"
                        statusColor = UIColor(red: 0.0, green: 0.667, blue: 0.0, alpha: 1.0)
                    } else if utilization >= 1.0 {
                        statusText = "⚠️ Over Budget"
                        statusColor = UIColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1.0)
                    } else if utilization >= 0.8 {
                        statusText = "⚡ High Usage"
                        statusColor = UIColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 1.0)
                    } else {
                        statusText = "✅ On Track"
                        statusColor = UIColor(red: 0.0, green: 0.667, blue: 0.0, alpha: 1.0)
                    }
                    
                    let statusAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 10),
                        .foregroundColor: statusColor
                    ]
                    statusText.draw(at: CGPoint(x: leftMargin + 450, y: rowY + 10), withAttributes: statusAttributes)
                }
                
                yPosition += CGFloat(departmentBudgets.count) * rowHeight + 30
            }
            
            // MARK: - Detailed Expense Table
            if !filteredExpenses.isEmpty && yPosition < 750 {
                drawSectionHeader(title: "Detailed Expense List", yPosition: &yPosition, leftMargin: leftMargin, icon: "📋")
                
                let sortedExpenses = filteredExpenses.sorted { expense1, expense2 in
                    let date1 = phaseDateFormatter.date(from: expense1.date) ?? expense1.createdAt.dateValue()
                    let date2 = phaseDateFormatter.date(from: expense2.date) ?? expense2.createdAt.dateValue()
                    return date1 < date2
                }
                
                let expenseTableY = yPosition
                let expenseRowHeight: CGFloat = 20
                let expenseHeaderHeight: CGFloat = 25
                
                // Table header
                UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0).setFill()
                UIBezierPath(rect: CGRect(x: leftMargin, y: expenseTableY, width: contentWidth, height: expenseHeaderHeight)).fill()
                
                let expenseHeaderAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 9),
                    .foregroundColor: UIColor.white
                ]
                
                "Date".draw(at: CGPoint(x: leftMargin + 5, y: expenseTableY + 8), withAttributes: expenseHeaderAttributes)
                "Phase".draw(at: CGPoint(x: leftMargin + 60, y: expenseTableY + 8), withAttributes: expenseHeaderAttributes)
                "Dept".draw(at: CGPoint(x: leftMargin + 120, y: expenseTableY + 8), withAttributes: expenseHeaderAttributes)
                "Amount".draw(at: CGPoint(x: leftMargin + 180, y: expenseTableY + 8), withAttributes: expenseHeaderAttributes)
                "Category".draw(at: CGPoint(x: leftMargin + 240, y: expenseTableY + 8), withAttributes: expenseHeaderAttributes)
                "Payment".draw(at: CGPoint(x: leftMargin + 320, y: expenseTableY + 8), withAttributes: expenseHeaderAttributes)
                
                yPosition += expenseHeaderHeight
                
                let expenseRowAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8),
                    .foregroundColor: UIColor.black
                ]
                
                // Limit to 15 expenses to fit on page
                let displayExpenses = Array(sortedExpenses.prefix(15))
                for (index, expense) in displayExpenses.enumerated() {
                    let rowY = yPosition + CGFloat(index) * expenseRowHeight
                    
                    // Alternating row background
                    if index % 2 == 0 {
                        UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0).setFill()
                        UIBezierPath(rect: CGRect(x: leftMargin, y: rowY, width: contentWidth, height: expenseRowHeight)).fill()
                    }
                    
                    let dateStr = expense.date
                    let phaseStr = expense.phaseName ?? "N/A"
                    let deptStr = expense.department.count > 8 ? String(expense.department.prefix(8)) + "..." : expense.department
                    let amountStr = "₹\(Int(expense.amount).formatted())"
                    let categoryStr = (expense.categories.first ?? "Other").count > 10 ? String((expense.categories.first ?? "Other").prefix(10)) + "..." : (expense.categories.first ?? "Other")
                    let paymentStr = expense.modeOfPayment.rawValue.count > 8 ? String(expense.modeOfPayment.rawValue.prefix(8)) : expense.modeOfPayment.rawValue
                    
                    dateStr.draw(at: CGPoint(x: leftMargin + 5, y: rowY + 6), withAttributes: expenseRowAttributes)
                    phaseStr.draw(at: CGPoint(x: leftMargin + 60, y: rowY + 6), withAttributes: expenseRowAttributes)
                    deptStr.draw(at: CGPoint(x: leftMargin + 120, y: rowY + 6), withAttributes: expenseRowAttributes)
                    amountStr.draw(at: CGPoint(x: leftMargin + 180, y: rowY + 6), withAttributes: expenseRowAttributes)
                    categoryStr.draw(at: CGPoint(x: leftMargin + 240, y: rowY + 6), withAttributes: expenseRowAttributes)
                    paymentStr.draw(at: CGPoint(x: leftMargin + 320, y: rowY + 6), withAttributes: expenseRowAttributes)
                }
                
                yPosition += CGFloat(displayExpenses.count) * expenseRowHeight + 10
                
                if sortedExpenses.count > 15 {
                    let moreText = "Note: Showing first 15 of \(sortedExpenses.count) expenses. See Excel export for complete list."
                    let noteAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.italicSystemFont(ofSize: 8),
                        .foregroundColor: UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
                    ]
                    moreText.draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: noteAttributes)
                    yPosition += 15
                }
            }
            
            // MARK: - Footer Section
            yPosition = min(yPosition, 780) // Adjust footer position
            if yPosition < 780 {
                yPosition = 780
            }
            drawSectionDivider(yPosition: &yPosition, leftMargin: leftMargin, rightMargin: rightMargin)
            
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            ]
            
            "© 2024 Management System • Confidential Financial Report".draw(at: CGPoint(x: leftMargin, y: yPosition + 10), withAttributes: footerAttributes)
            "Generated on \(Date().formatted(.dateTime.day().month().year())) • For authorized personnel only".draw(at: CGPoint(x: leftMargin, y: yPosition + 25), withAttributes: footerAttributes)
            
            // Contact info (right aligned)
            let contactText = "support@avrentertainment.com • +91-XXXX-XXXXXX"
            let contactSize = contactText.size(withAttributes: footerAttributes)
            contactText.draw(at: CGPoint(x: rightMargin - contactSize.width, y: yPosition + 10), withAttributes: footerAttributes)
        }
        
        return pdfData
    }
    
    // MARK: - PDF Helper Functions
    private func drawSectionHeader(title: String, yPosition: inout CGFloat, leftMargin: CGFloat, icon: String) {
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        
        "\(icon) \(title)".draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: headerAttributes)
        yPosition += 25
        
        // Underline - darker blue
        UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0).setStroke()
        let underlinePath = UIBezierPath()
        underlinePath.move(to: CGPoint(x: leftMargin, y: yPosition))
        underlinePath.addLine(to: CGPoint(x: leftMargin + 200, y: yPosition))
        underlinePath.lineWidth = 2
        underlinePath.stroke()
        yPosition += 15
    }
    
    private func drawSectionDivider(yPosition: inout CGFloat, leftMargin: CGFloat, rightMargin: CGFloat) {
        UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0).setStroke()
        let dividerPath = UIBezierPath()
        dividerPath.move(to: CGPoint(x: leftMargin, y: yPosition))
        dividerPath.addLine(to: CGPoint(x: rightMargin, y: yPosition))
        dividerPath.lineWidth = 1
        dividerPath.stroke()
        yPosition += 15
    }
    
    private func drawSummaryCard(title: String, value: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: UIColor) {
        // Card background - lighter version of color
        color.withAlphaComponent(0.15).setFill()
        UIBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: 8).fill()
        
        // Card border - solid color
        color.setStroke()
        let borderPath = UIBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: 8)
        borderPath.lineWidth = 1.5
        borderPath.stroke()
        
        // Title - dark gray
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        ]
        title.draw(at: CGPoint(x: x + 10, y: y + 8), withAttributes: titleAttributes)
        
        // Value - solid color
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: color
        ]
        value.draw(at: CGPoint(x: x + 10, y: y + 25), withAttributes: valueAttributes)
    }
    
    private func drawBarChart(yPosition: inout CGFloat, leftMargin: CGFloat, contentWidth: CGFloat) {
        let chartHeight: CGFloat = 120
        let chartY = yPosition
        let barWidth: CGFloat = 30
        let barSpacing: CGFloat = 10
        let maxBarHeight: CGFloat = 80
        
        // Chart background
        UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0).setFill()
        UIBezierPath(roundedRect: CGRect(x: leftMargin, y: chartY, width: contentWidth, height: chartHeight), cornerRadius: 8).fill()
        
        // Chart border
        UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0).setStroke()
        let borderPath = UIBezierPath(roundedRect: CGRect(x: leftMargin, y: chartY, width: contentWidth, height: chartHeight), cornerRadius: 8)
        borderPath.lineWidth = 1
        borderPath.stroke()
        
        // Chart title
        let chartTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        "Expense Categories Chart".draw(at: CGPoint(x: leftMargin + 10, y: chartY + 10), withAttributes: chartTitleAttributes)
        
        // Calculate max amount for scaling
        let maxAmount = expenseCategories.map(\.amount).max() ?? 1
        
        // Draw bars
        let startX = leftMargin + 20
        let startY = chartY + 40
        let availableWidth = contentWidth - 40
        let totalBarWidth = CGFloat(expenseCategories.count) * barWidth + CGFloat(expenseCategories.count - 1) * barSpacing
        let chartStartX = startX + (availableWidth - totalBarWidth) / 2
        
        for (index, category) in expenseCategories.enumerated() {
            let barX = chartStartX + CGFloat(index) * (barWidth + barSpacing)
            let barHeight = maxAmount > 0 ? (category.amount / maxAmount) * maxBarHeight : 0
            let barY = startY + maxBarHeight - barHeight
            
            // Bar background
            UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 0.2).setFill()
            UIBezierPath(roundedRect: CGRect(x: barX, y: startY, width: barWidth, height: maxBarHeight), cornerRadius: 2).fill()
            
            // Bar fill
            UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 0.8).setFill()
            UIBezierPath(roundedRect: CGRect(x: barX, y: barY, width: barWidth, height: barHeight), cornerRadius: 2).fill()
            
            // Bar border
            UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0).setStroke()
            let barPath = UIBezierPath(roundedRect: CGRect(x: barX, y: barY, width: barWidth, height: barHeight), cornerRadius: 2)
            barPath.lineWidth = 0.5
            barPath.stroke()
            
            // Amount label on top of bar
            if barHeight > 15 {
                let amountAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8),
                    .foregroundColor: UIColor.black
                ]
                let amountText = "₹\(Int(category.amount).formatted())"
                let amountSize = amountText.size(withAttributes: amountAttributes)
                amountText.draw(at: CGPoint(x: barX + (barWidth - amountSize.width) / 2, y: barY - 12), withAttributes: amountAttributes)
            }
            
            // Category name below bar
            let categoryAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.black
            ]
            let categoryText = category.name
            let categorySize = categoryText.size(withAttributes: categoryAttributes)
            categoryText.draw(at: CGPoint(x: barX + (barWidth - categorySize.width) / 2, y: startY + maxBarHeight + 5), withAttributes: categoryAttributes)
        }
        
        yPosition += chartHeight + 20
    }
    
    // MARK: - Enhanced Excel (CSV) Generation
    private func generateExcelReport() async throws -> String {
        var csvContent = ""
        
        // MARK: - Report Header
        csvContent += "PROJECT FINANCIAL REPORT\n"
        csvContent += "Report Generated: \(Date().formatted(.dateTime.day().month().year().hour().minute()))\n"
        csvContent += "Filter Period: \(selectedDateRange.description)\n"
        csvContent += "Department: \(selectedDepartment)\n"
        if let selectedPhase = selectedPhase {
            csvContent += "Phase: \(selectedPhase.name)\n"
            if let phaseStart = selectedPhase.start, let phaseEnd = selectedPhase.end {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd/MM/yyyy"
                csvContent += "Phase Timeline: \(dateFormatter.string(from: phaseStart)) - \(dateFormatter.string(from: phaseEnd))\n"
            }
        } else {
            csvContent += "Phase: All Phases\n"
        }
        csvContent += "\n"
        
        // MARK: - Executive Summary
        let totalExpenses = filteredExpenses.reduce(0) { $0 + $1.amount }
        let totalBudget = departmentBudgets.reduce(0) { $0 + $1.totalBudget }
        let totalSpent = departmentBudgets.reduce(0) { $0 + $1.approvedBudget }
        let remainingBudget = totalBudget - totalSpent
        let utilizationPercentage = totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0
        
        csvContent += "EXECUTIVE SUMMARY\n"
        csvContent += "Metric,Amount,Percentage,Status\n"
        csvContent += "Total Budget Allocated,\(String(format: "%.0f", totalBudget)),100%,Baseline\n"
        csvContent += "Total Amount Spent,\(String(format: "%.0f", totalSpent)),\(String(format: "%.1f", utilizationPercentage))%,\(utilizationPercentage > 80 ? "High Usage" : "Normal")\n"
        csvContent += "Remaining Budget,\(String(format: "%.0f", remainingBudget)),\(String(format: "%.1f", 100 - utilizationPercentage))%,\(remainingBudget < 0 ? "Over Budget" : "Available")\n\n"
        
        // MARK: - Expense Categories (Chart Ready)
        csvContent += "EXPENSE CATEGORIES - CHART DATA\n"
        csvContent += "Category,Amount,Percentage,Transaction Count,Bar Height (0-100),Color Code\n"
        
        let maxAmount = expenseCategories.map(\.amount).max() ?? 1
        
        for category in expenseCategories {
            let categoryExpenses = filteredExpenses.filter { expense in
                expense.categories.first ?? "Other" == category.name
            }
            let percentage = totalExpenses > 0 ? (category.amount / totalExpenses) * 100 : 0
            let barHeight = maxAmount > 0 ? (category.amount / maxAmount) * 100 : 0
            
            csvContent += "\(category.name),\(String(format: "%.0f", category.amount)),\(String(format: "%.1f", percentage))%,\(categoryExpenses.count),\(String(format: "%.1f", barHeight)),Blue\n"
        }
        
        csvContent += "\n"
        
        // MARK: - Chart Instructions
        csvContent += "CHART CREATION INSTRUCTIONS\n"
        csvContent += "Step,Description\n"
        csvContent += "1,Select the Category and Amount columns (A1:B\(expenseCategories.count + 1))\n"
        csvContent += "2,Insert a Bar Chart (2D Column Chart)\n"
        csvContent += "3,Set Category names as X-axis labels\n"
        csvContent += "4,Set Amount as Y-axis values\n"
        csvContent += "5,Use Bar Height column for proportional scaling\n"
        csvContent += "6,Apply blue color scheme (#007AFF)\n"
        csvContent += "7,Add data labels showing amounts\n"
        csvContent += "8,Title: 'Expense Categories Breakdown'\n"
        csvContent += "\n"
        
        // MARK: - Department Analysis (Chart Ready)
        csvContent += "DEPARTMENT BUDGET ANALYSIS\n"
        csvContent += "Department,Allocated Budget,Amount Spent,Remaining Budget,Utilization %,Status\n"
        
        for budget in departmentBudgets {
            let remaining = budget.totalBudget - budget.approvedBudget
            let utilization = budget.totalBudget > 0 ? (budget.approvedBudget / budget.totalBudget) * 100 : 0
            
            // Special handling for "Other Expenses"
            let displayAmount = budget.department == "Other Expenses" ? budget.approvedBudget : remaining
            
            let status: String
            if budget.department == "Other Expenses" {
                status = "Other Expenses"
            } else if utilization >= 100 {
                status = "Over Budget"
            } else if utilization >= 80 {
                status = "High Usage"
            } else if utilization >= 50 {
                status = "Normal Usage"
            } else {
                status = "Low Usage"
            }
            
            csvContent += "\(budget.department),\(String(format: "%.0f", budget.totalBudget)),\(String(format: "%.0f", budget.approvedBudget)),\(String(format: "%.0f", displayAmount)),\(String(format: "%.1f", utilization))%,\(status)\n"
        }
        
        csvContent += "\n"
        
        // MARK: - Expense Details (Filterable Data)
        csvContent += "EXPENSE DETAILS\n"
        csvContent += "Date,Phase,Department,Category,Amount,Mode of Payment,Description,Status,Submitted By\n"
        
        let sortedExpenses = filteredExpenses.sorted { expense1, expense2 in
            let date1 = phaseDateFormatter.date(from: expense1.date) ?? expense1.createdAt.dateValue()
            let date2 = phaseDateFormatter.date(from: expense2.date) ?? expense2.createdAt.dateValue()
            return date1 < date2
        }
        
        for expense in sortedExpenses {
            let dateString = expense.date // Use expense date, not createdAt
            let phaseName = expense.phaseName ?? "N/A"
            let category = expense.categories.first ?? "Other"
            let description = expense.description.replacingOccurrences(of: ",", with: ";") // Handle commas in description
            let modeOfPayment = expense.modeOfPayment.rawValue
            
            csvContent += "\(dateString),\(phaseName),\(expense.department),\(category),\(String(format: "%.2f", expense.amount)),\(modeOfPayment),\(description),\(expense.status.rawValue),\(expense.submittedBy)\n"
        }
        
        csvContent += "\n"
        
        // MARK: - Monthly Trend Data (Chart Ready)
        csvContent += "MONTHLY EXPENSE TREND\n"
        csvContent += "Month,Total Expenses,Transaction Count,Average Transaction\n"
        
        let calendar = Calendar.current
        let monthlyData = Dictionary(grouping: sortedExpenses) { expense in
            let date = expense.createdAt.dateValue()
            return calendar.dateInterval(of: .month, for: date)?.start ?? date
        }
        
        for (month, expenses) in monthlyData.sorted(by: { $0.key < $1.key }) {
            let monthString = month.formatted(.dateTime.month(.wide).year())
            let totalAmount = expenses.reduce(0) { $0 + $1.amount }
            let averageAmount = expenses.count > 0 ? totalAmount / Double(expenses.count) : 0
            
            csvContent += "\(monthString),\(String(format: "%.0f", totalAmount)),\(expenses.count),\(String(format: "%.0f", averageAmount))\n"
        }
        
        return csvContent
    }
    
    // MARK: - Share Sheet Presentation
    private func presentShareSheet(url: URL) async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
        }
        
        await MainActor.run {
            rootViewController.present(activityVC, animated: true)
        }
    }



}

// MARK: - Supporting Models
struct ExpenseCategory {
    let name: String
    let amount: Double
    
    var formattedAmount: String {
        "₹\(Int(amount).formatted())"
    }
}
