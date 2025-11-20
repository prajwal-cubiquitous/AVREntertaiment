//
//  ProjectInsightsView.swift
//  AVREntertainment
//
//  Created by Auto on 1/1/25.
//

import SwiftUI
import Charts

struct ProjectInsightsView: View {
    @ObservedObject var viewModel: MainReportViewModel
    @Binding var expandedChartId: String?
    @Binding var searchTextBinding: String
    let isViewModelReady: Bool
    let dismissReports: () -> Void
    
    // MARK: - State Variables for Project Charts
    @State private var selectedMonth: String? = nil
    @State private var selectedStatusForPercentage: String? = nil
    @State private var selectedCategory: String? = nil
    @State private var categoryPressCounts: [String: Int] = [:]
    @State private var showingProjectModal: Bool = false
    @State private var selectedCategoryForModal: String? = nil
    @State private var lastTapTime: Date? = nil
    @State private var lastTappedCategory: String? = nil
    @State private var modalTimer: Timer? = nil
    @State private var selectedDelayCorrelationItem: MainReportViewModel.DelayCorrelationData? = nil
    @State private var lastSelectedX: Double? = nil
    @State private var lastSelectedY: Double? = nil
    @State private var selectedSuspensionReason: String? = nil
    @State private var suspensionReasonPressCounts: [String: Int] = [:]
    @State private var showingSuspensionProjectModal: Bool = false
    @State private var selectedSuspensionReasonForModal: String? = nil
    @State private var lastSuspensionTapTime: Date? = nil
    @State private var lastTappedSuspensionReason: String? = nil
    @State private var suspensionModalTimer: Timer? = nil
    
    var body: some View {
        // Check isViewModelReady FIRST before any ViewModel access
        // This prevents EXC_BAD_ACCESS crashes on older devices
        if !isViewModelReady {
            EmptyView()
        } else if viewModel.isLoading {
            EmptyView()
        } else if viewModel.activeProjectsData.count == 0 {
            EmptyView()
        } else {
            projectInsightsContentBody()
        }
    }
    
    @ViewBuilder
    private func projectInsightsContentBody() -> some View {
        // Ensure we're on main thread and ViewModel is ready before accessing properties
        if isViewModelReady && !viewModel.isLoading {
            VStack(spacing: DesignSystem.Spacing.medium) {
                // Active Projects (MoM)
                ReportChartCard(
                    title: "Active Projects (MoM)",
                    subtitle: "Count of active projects",
                    totalValue: nil,
                    chartId: "activeProjects",
                    expandedChartId: $expandedChartId
                ) {
                    activeProjectsChart
                }
                
                // Projects Percentage by Status
                ReportChartCard(
                    title: "Projects Percentage by Status",
                    subtitle: "% of projects by status",
                    totalValue: nil,
                    chartId: "projectStatusPercentage",
                    expandedChartId: $expandedChartId
                ) {
                    projectStatusPercentageChart
                }
                
                // Sub-Category Activity
                ReportChartCard(
                    title: "Sub-Category Activity",
                    subtitle: "# of expenses · last 30 days",
                    totalValue: nil,
                    chartId: "subCategoryActivity",
                    expandedChartId: $expandedChartId
                ) {
                    subCategoryActivityChart
                }
                
                // Extended Days vs Extra Cost
                ReportChartCard(
                    title: "Extended Days vs Extra Cost",
                    subtitle: "Project-level correlation",
                    totalValue: nil,
                    chartId: "delayCorrelation",
                    expandedChartId: $expandedChartId
                ) {
                    delayCorrelationChart
                }
                
                // Suspended Projects by Reason
                ReportChartCard(
                    title: "Suspended Projects by Reason",
                    subtitle: "Current FY",
                    totalValue: nil,
                    chartId: "suspensionReason",
                    expandedChartId: $expandedChartId
                ) {
                    suspensionReasonChart
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    // Helper function to format chart axis values
    private func formatChartValue(_ value: Double) -> String {
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
                return String(format: "%.0f L", lakhs)
            } else {
                return String(format: "%.2f L", lakhs)
            }
        } else {
            // 10000000+: show in crores (Cr)
            let crores = value / 10000000.0
            // Remove .00 if it's a whole number
            if crores.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0fCr", crores)
            } else {
                return String(format: "%.2fCr", crores)
            }
        }
    }
    
    // Helper function to truncate names consistently
    private func truncateName(_ name: String, maxLength: Int = 15) -> String {
        if name.count > maxLength {
            return String(name.prefix(maxLength)) + "..."
        }
        return name
    }
    
    // Helper function to calculate safe tooltip position that avoids screen edges
    // Follows Apple Charts guidelines for tooltip positioning
    private func calculateSafeTooltipPosition(
        preferredX: CGFloat,
        preferredY: CGFloat,
        tooltipWidth: CGFloat,
        tooltipHeight: CGFloat,
        containerWidth: CGFloat,
        containerHeight: CGFloat,
        padding: CGFloat = 16
    ) -> (x: CGFloat, y: CGFloat) {
        // Calculate safe boundaries with padding
        let minX = padding
        let maxX = containerWidth - tooltipWidth - padding
        let minY = padding
        let maxY = containerHeight - tooltipHeight - padding
        
        // Calculate preferred position (centered on preferredX)
        var safeX = preferredX - tooltipWidth / 2
        
        // Adjust X if tooltip would go off-screen
        if safeX < minX {
            // Too far left - align to left edge with padding
            safeX = minX
        } else if safeX > maxX {
            // Too far right - align to right edge with padding
            safeX = maxX
        }
        
        // Clamp Y position to stay within bounds
        var safeY = preferredY
        if safeY < minY {
            safeY = minY
        } else if safeY + tooltipHeight > containerHeight - padding {
            // If tooltip would go below screen, position it above the preferred point
            safeY = max(minY, preferredY - tooltipHeight - 8)
        }
        
        // Final clamp to ensure we're within bounds
        safeY = max(minY, min(maxY, safeY))
        
        return (safeX, safeY)
    }
    
    // Helper function to get color for status (matching the provided color mapping)
    private func getStatusColor(_ status: String) -> Color {
        switch status {
        case "ACTIVE":
            return .green
        case "COMPLETED":
            return .blue
        case "HANDOVER":
            return .yellow
        case "IN_REVIEW":
            return .cyan
        case "LOCKED":
            return .indigo
        case "SUSPENDED":
            return .orange
        case "DECLINED":
            return .red
        case "MAINTENANCE":
            return .purple
        case "ARCHIVE":
            return .gray
        default:
            return .accentColor
        }
    }
    
    // Helper function to get display name for status
    private func getStatusDisplayName(_ status: String) -> String {
        switch status {
        case "ACTIVE":
            return "Active"
        case "COMPLETED":
            return "Completed"
        case "HANDOVER":
            return "HandOver"
        case "IN_REVIEW":
            return "In Review"
        case "LOCKED":
            return "Locked"
        case "SUSPENDED":
            return "Suspended"
        case "DECLINED":
            return "Declined"
        case "MAINTENANCE":
            return "Maintenance"
        case "ARCHIVE":
            return "Archive"
        default:
            return status
        }
    }
    
    // MARK: - Charts
    
    // Active Projects Chart
    private var activeProjectsChart: some View {
        ZStack(alignment: .top) {
            Chart {
                ForEach(viewModel.activeProjectsData, id: \.month) { data in
                    LineMark(
                        x: .value("Month", data.month),
                        y: .value("Count", data.count)
                    )
                    .foregroundStyle(Color.green)
                    .interpolationMethod(.linear)
                    .symbol(.circle)
                    .symbolSize(selectedMonth == data.month ? 60 : 40)
                }
                
                // Show tooltip indicators for selected month
                if let selectedMonth = selectedMonth,
                   let selectedData = viewModel.activeProjectsData.first(where: { $0.month == selectedMonth }) {
                    RuleMark(x: .value("Month", selectedMonth))
                        .foregroundStyle(Color.green.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    
                    PointMark(
                        x: .value("Month", selectedMonth),
                        y: .value("Count", selectedData.count)
                    )
                    .foregroundStyle(Color.green)
                    .symbolSize(60)
                }
            }
            .chartXSelection(value: $selectedMonth)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let month = value.as(String.self) {
                            Text(month)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: true))
            .frame(minHeight: 220, maxHeight: 250)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            
            // Enhanced Tooltip overlay with safe positioning
            if let selectedMonth = selectedMonth,
               let selectedData = viewModel.activeProjectsData.first(where: { $0.month == selectedMonth }),
               let monthIndex = viewModel.activeProjectsData.firstIndex(where: { $0.month == selectedMonth }) {
                GeometryReader { geometry in
                    let chartWidth = geometry.size.width
                    let dataCount = CGFloat(viewModel.activeProjectsData.count)
                    let preferredX = (CGFloat(monthIndex) + 0.5) * (chartWidth / dataCount)
                    
                    // Estimate tooltip size
                    let tooltipWidth: CGFloat = 180
                    let tooltipHeight: CGFloat = 70
                    
                    // Calculate safe position
                    let safePosition = calculateSafeTooltipPosition(
                        preferredX: preferredX,
                        preferredY: 24,
                        tooltipWidth: tooltipWidth,
                        tooltipHeight: tooltipHeight,
                        containerWidth: geometry.size.width,
                        containerHeight: geometry.size.height,
                        padding: 12
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedMonth)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Divider()
                            .background(Color(.separator).opacity(0.3))
                        
                        HStack(spacing: 10) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("Active Projects")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(selectedData.count)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: tooltipWidth)
                    .position(x: safePosition.x + tooltipWidth / 2, y: safePosition.y)
                }
                .frame(minHeight: 220, maxHeight: 250)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // Projects Percentage by Status Chart
    private var projectStatusPercentageChart: some View {
        ZStack(alignment: .trailing) {
            Chart {
                ForEach(viewModel.projectStatusPercentageData, id: \.status) { data in
                    BarMark(
                        x: .value("Percentage", data.percentage),
                        y: .value("Status", data.status)
                    )
                    .foregroundStyle(
                        selectedStatusForPercentage == data.status
                        ? getStatusColor(data.status).opacity(0.85)
                        : getStatusColor(data.status)
                    )
                    .cornerRadius(6, style: .continuous)
                }
                
                // Selected Rule
                if let selectedStatus = selectedStatusForPercentage {
                    RuleMark(y: .value("Status", selectedStatus))
                        .foregroundStyle(Color.accentColor.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .chartYSelection(value: $selectedStatusForPercentage)
            .chartXAxis {
                AxisMarks(position: .bottom, values: .stride(by: 25)) { value in
                    AxisGridLine()
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(Int(doubleValue))%")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic) { value in
                    AxisGridLine()
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let status = value.as(String.self) {
                            Text(getStatusDisplayName(status))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .chartXScale(domain: 0...100)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(minHeight: CGFloat(max(viewModel.projectStatusPercentageData.count, 3)) * 50 + 40)
            
            // Custom scroll indicator
            if viewModel.projectStatusPercentageData.count > 3 {
                VStack {
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                }
            }
            
            // Tooltip overlay
            if let selectedStatus = selectedStatusForPercentage,
               let selectedData = viewModel.projectStatusPercentageData.first(where: { $0.status == selectedStatus }) {
                GeometryReader { geometry in
                    let barHeight = 50.0
                    let statusIndex = viewModel.projectStatusPercentageData.firstIndex(where: { $0.status == selectedStatus }) ?? 0
                    let preferredY = (CGFloat(statusIndex) * barHeight) + (barHeight / 2) + 20
                    
                    // Calculate x position based on the bar's end (percentage value)
                    let maxPercentage = 100.0
                    let barWidthRatio = selectedData.percentage / maxPercentage
                    let chartAreaWidth = geometry.size.width - 24
                    let preferredX = chartAreaWidth * 0.75 * barWidthRatio + 80
                    
                    let tooltipWidth: CGFloat = 200
                    let tooltipHeight: CGFloat = 90
                    
                    let safePosition = calculateSafeTooltipPosition(
                        preferredX: preferredX,
                        preferredY: preferredY,
                        tooltipWidth: tooltipWidth,
                        tooltipHeight: tooltipHeight,
                        containerWidth: geometry.size.width,
                        containerHeight: geometry.size.height,
                        padding: 12
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Title Row
                        HStack(spacing: 8) {
                            Circle()
                                .fill(getStatusColor(selectedStatus))
                                .frame(width: 10, height: 10)
                            Text(getStatusDisplayName(selectedStatus))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        
                        Divider().background(Color(.separator).opacity(0.3))
                        
                        // Percentage Row
                        HStack {
                            Text("Percentage")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f%%", selectedData.percentage))
                                .font(.system(size: 14, weight: .bold))
                        }
                        
                        // Count Row
                        HStack {
                            Text("Count")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(selectedData.count) projects")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: tooltipWidth, height: tooltipHeight)
                    .position(x: safePosition.x + tooltipWidth / 2, y: safePosition.y)
                }
                .frame(minHeight: CGFloat(max(viewModel.projectStatusPercentageData.count, 3)) * 50 + 40)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .scrollIndicators(.hidden)
    }
    
    // Sub-Category Activity Chart
    private var subCategoryActivityChart: some View {
        ZStack(alignment: .trailing) {
            Chart {
                ForEach(viewModel.subCategoryActivityData, id: \.category) { data in
                    BarMark(
                        x: .value("Count", data.count),
                        y: .value("Category", data.category)
                    )
                    .foregroundStyle(selectedCategory == data.category ? Color.blue.opacity(0.8) : Color.blue)
                }
                
                // Show rule mark for selected category
                if let selectedCategory = selectedCategory,
                   let selectedData = viewModel.subCategoryActivityData.first(where: { $0.category == selectedCategory }) {
                    RuleMark(y: .value("Category", selectedCategory))
                        .foregroundStyle(Color.accentColor.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
            .chartYSelection(value: $selectedCategory)
            .onChange(of: selectedCategory) { newValue in
                if let category = newValue {
                    handleCategorySelection(category: category)
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom, values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 10)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let category = value.as(String.self) {
                            Text(category)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .frame(minHeight: CGFloat(max(viewModel.subCategoryActivityData.count, 3)) * 50 + 60)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            
            // Enhanced Tooltip overlay with safe positioning
            if let selectedCategory = selectedCategory,
               let selectedData = viewModel.subCategoryActivityData.first(where: { $0.category == selectedCategory }),
               let categoryIndex = viewModel.subCategoryActivityData.firstIndex(where: { $0.category == selectedCategory }) {
                GeometryReader { geometry in
                    let barHeight = 50.0
                    let preferredY = (CGFloat(categoryIndex) * barHeight) + (barHeight / 2) + 20
                    
                    // Calculate x position based on the bar's end (count value)
                    let maxCount = viewModel.subCategoryActivityData.map { $0.count }.max() ?? 1
                    let barWidthRatio = Double(selectedData.count) / Double(maxCount)
                    let chartAreaWidth = geometry.size.width - 16
                    let preferredX = chartAreaWidth * 0.75 * barWidthRatio + 60
                    
                    // Estimate tooltip size
                    let tooltipWidth: CGFloat = 200
                    let tooltipHeight: CGFloat = 80
                    
                    // Calculate safe position
                    let safePosition = calculateSafeTooltipPosition(
                        preferredX: preferredX,
                        preferredY: preferredY,
                        tooltipWidth: tooltipWidth,
                        tooltipHeight: tooltipHeight,
                        containerWidth: geometry.size.width,
                        containerHeight: geometry.size.height,
                        padding: 12
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedCategory)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        Divider()
                            .background(Color(.separator).opacity(0.3))
                        
                        HStack(spacing: 10) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("Expenses")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(selectedData.count)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        
                        // Show press count if available
                        if let pressCount = categoryPressCounts[selectedCategory], pressCount > 0 {
                            Divider()
                                .background(Color(.separator).opacity(0.3))
                            
                            HStack(spacing: 10) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.blue)
                                Text("Presses")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(pressCount)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: tooltipWidth)
                    .position(x: safePosition.x + tooltipWidth / 2, y: safePosition.y)
                }
                .frame(minHeight: CGFloat(max(viewModel.subCategoryActivityData.count, 3)) * 50 + 60)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingProjectModal) {
            if let category = selectedCategoryForModal,
               let categoryData = viewModel.subCategoryActivityData.first(where: { $0.category == category }) {
                ProjectListModalView(
                    category: category,
                    projectNames: categoryData.projectNames,
                    expenseCount: categoryData.count,
                    searchTextBinding: $searchTextBinding,
                    dismissReports: dismissReports
                )
            }
        }
    }
    
    // Handler for category selection - handles press counting and single click modal
    private func handleCategorySelection(category: String) {
        let now = Date()
        
        // Cancel previous timer if it exists
        modalTimer?.invalidate()
        
        // Increment press counter
        categoryPressCounts[category, default: 0] += 1
        
        // Check if this is the same category as last tap
        if let lastCategory = lastTappedCategory, lastCategory == category {
            // Same category - check if it's a rapid press or single click
            if let lastTime = lastTapTime, now.timeIntervalSince(lastTime) < 0.3 {
                // Rapid press - just update counter, don't show modal yet
                lastTapTime = now
                return
            }
        }
        
        // New category or gap > 300ms - set up timer to show modal after 300ms of inactivity
        lastTapTime = now
        lastTappedCategory = category
        
        modalTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { timer in
            DispatchQueue.main.async {
                // After 300ms of no activity, show modal if counter is 1 (single click)
                // or just show the counter if multiple presses
                if self.categoryPressCounts[category] == 1 {
                    // Single click - show modal
                    self.selectedCategoryForModal = category
                    self.showingProjectModal = true
                    // Reset press count after showing modal
                    self.categoryPressCounts[category] = 0
                }
                // If counter > 1, just keep showing the counter in the tooltip
            }
        }
        RunLoop.main.add(modalTimer!, forMode: .common)
    }
    
    // Modal view for displaying project names
    private struct ProjectListModalView: View {
        let category: String
        let projectNames: [String]
        let expenseCount: Int
        @Binding var searchTextBinding: String
        let dismissReports: () -> Void
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            NavigationView {
                VStack(spacing: 0) {
                    // Header info
                    VStack(spacing: 12) {
                        Text(category)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 16) {
                            VStack(spacing: 4) {
                                Text("\(expenseCount)")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.blue)
                                Text("Expenses")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Divider()
                                .frame(height: 40)
                            
                            VStack(spacing: 4) {
                                Text("\(projectNames.count)")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.green)
                                Text("Projects")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    .background(Color(.systemGroupedBackground))
                    
                    Divider()
                    
                    // Scrollable project list
                    if projectNames.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No Projects")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("No projects found for this category")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(projectNames, id: \.self) { projectName in
                                    Button {
                                        HapticManager.selection()
                                        // Set search text and dismiss both modals
                                        searchTextBinding = projectName
                                        dismiss()
                                        // Small delay to ensure modal dismisses before reports dismisses
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            dismissReports()
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "building.2.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(.blue)
                                                .frame(width: 24)
                                            
                                            Text(projectName)
                                                .font(.system(size: 16, weight: .regular))
                                                .foregroundStyle(.primary)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                        .background(Color(.systemBackground))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if projectName != projectNames.last {
                                        Divider()
                                            .padding(.leading, 44)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                .background(Color(.systemGroupedBackground))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
    
    // Delay Correlation Chart (Extended Days vs Extra Cost)
    private var delayCorrelationChart: some View {
        // Calculate axis domains to ensure 0 is at the start
        let maxExtendedDays = viewModel.delayCorrelationData.map { $0.delayDays }.max() ?? 1.0
        let maxExtraCost = viewModel.delayCorrelationData.map { $0.extraCost }.max() ?? 1.0
        
        // Add padding to max values (10% padding)
        let xAxisMax = max(maxExtendedDays * 1.1, 1.0)
        let yAxisMax = max(maxExtraCost * 1.1, 1.0)
        
        return ZStack(alignment: .topLeading) {
            Chart {
                ForEach(viewModel.delayCorrelationData, id: \.id) { data in
                    PointMark(
                        x: .value("Extended Days", data.delayDays),
                        y: .value("Extra Cost", data.extraCost)
                    )
                    .foregroundStyle(selectedDelayCorrelationItem?.id == data.id ? Color.blue : Color.cyan)
                    .symbolSize(selectedDelayCorrelationItem?.id == data.id ? 80 : 60)
                    .opacity(selectedDelayCorrelationItem?.id == data.id ? 1.0 : 0.7)
                }
            }
            .chartXScale(domain: 0...xAxisMax)
            .chartYScale(domain: 0...yAxisMax)
            .chartXAxis {
                AxisMarks(position: .bottom, values: .stride(by: max(1.0, xAxisMax / 5))) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let days = value.as(Double.self) {
                            Text("\(Int(days))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let cost = value.as(Double.self) {
                            Text(viewModel.formatChartNumber(cost))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .chartXAxisLabel("Extended Days")
                .font(.system(size: 12, weight: .medium))
            .chartYAxisLabel("Extra Cost")
                .font(.system(size: 12, weight: .medium))
            .chartXSelection(value: Binding(
                get: { lastSelectedX },
                set: { newValue in
                    lastSelectedX = newValue
                    if let xValue = newValue {
                        if let yValue = lastSelectedY {
                            // Both X and Y are available, find closest point using combined distance
                            selectedDelayCorrelationItem = findClosestPoint(xValue: xValue, yValue: yValue, xAxisMax: xAxisMax, yAxisMax: yAxisMax)
                        } else {
                            // Only X is available, find closest by X only
                            selectedDelayCorrelationItem = viewModel.delayCorrelationData.min(by: { 
                                abs($0.delayDays - xValue) < abs($1.delayDays - xValue) 
                            })
                        }
                    } else {
                        // Selection cleared
                        lastSelectedY = nil
                        selectedDelayCorrelationItem = nil
                    }
                }
            ))
            .chartYSelection(value: Binding(
                get: { lastSelectedY },
                set: { newValue in
                    lastSelectedY = newValue
                    if let yValue = newValue {
                        if let xValue = lastSelectedX {
                            // Both X and Y are available, find closest point using combined distance
                            selectedDelayCorrelationItem = findClosestPoint(xValue: xValue, yValue: yValue, xAxisMax: xAxisMax, yAxisMax: yAxisMax)
                        } else {
                            // Only Y is available, find closest by Y only
                            selectedDelayCorrelationItem = viewModel.delayCorrelationData.min(by: { 
                                abs($0.extraCost - yValue) < abs($1.extraCost - yValue) 
                            })
                        }
                    } else {
                        // Selection cleared
                        lastSelectedX = nil
                        selectedDelayCorrelationItem = nil
                    }
                }
            ))
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(minHeight: 220, maxHeight: 350)
            
            // Tooltip overlay - positioned outside chart to prevent layout shifts
            if let selectedItem = selectedDelayCorrelationItem {
                GeometryReader { geometry in
                    // Calculate position based on data point location
                    let xRange = xAxisMax - 0
                    let yRange = yAxisMax - 0
                    
                    // Chart area dimensions (accounting for padding and axis labels)
                    let chartPadding: CGFloat = 50
                    let chartWidth = geometry.size.width - chartPadding * 2
                    let chartHeight = geometry.size.height - chartPadding * 2
                    
                    // Calculate data point position
                    let xRatio = (selectedItem.delayDays - 0) / xRange
                    let yRatio = (selectedItem.extraCost - 0) / yRange
                    
                    let pointX = chartPadding + (xRatio * chartWidth)
                    let pointY = chartPadding + ((1 - yRatio) * chartHeight) // Invert Y for screen coordinates
                    
                    // Position tooltip above the point
                    let tooltipWidth: CGFloat = 180
                    let tooltipHeight: CGFloat = 80
                    let tooltipX = max(chartPadding, min(pointX - tooltipWidth / 2, geometry.size.width - tooltipWidth - chartPadding))
                    let tooltipY = max(8, pointY - tooltipHeight - 12)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedItem.project)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("Extended: \(Int(selectedItem.delayDays)) days")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("Extra: \(viewModel.formatChartNumber(selectedItem.extraCost))")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(width: tooltipWidth, height: tooltipHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                    )
                    .position(x: tooltipX + tooltipWidth / 2, y: tooltipY + tooltipHeight / 2)
                }
                .frame(minHeight: 220, maxHeight: 350)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // Helper function to find the closest data point using normalized combined distance
    private func findClosestPoint(xValue: Double, yValue: Double, xAxisMax: Double, yAxisMax: Double) -> MainReportViewModel.DelayCorrelationData? {
        guard !viewModel.delayCorrelationData.isEmpty else { return nil }
        
        // Normalize the axes to calculate combined distance properly
        let normalizedX = xValue / max(xAxisMax, 1.0)
        let normalizedY = yValue / max(yAxisMax, 1.0)
        
        return viewModel.delayCorrelationData.min(by: { data1, data2 in
            // Normalize data points
            let normX1 = data1.delayDays / max(xAxisMax, 1.0)
            let normY1 = data1.extraCost / max(yAxisMax, 1.0)
            let normX2 = data2.delayDays / max(xAxisMax, 1.0)
            let normY2 = data2.extraCost / max(yAxisMax, 1.0)
            
            // Calculate Euclidean distance (squared for comparison, no need to sqrt)
            let dist1 = (normX1 - normalizedX) * (normX1 - normalizedX) + (normY1 - normalizedY) * (normY1 - normalizedY)
            let dist2 = (normX2 - normalizedX) * (normX2 - normalizedX) + (normY2 - normalizedY) * (normY2 - normalizedY)
            
            return dist1 < dist2
        })
    }
    
    // Suspension Reason Chart
    private var suspensionReasonChart: some View {
        // Handle empty state
        if viewModel.suspensionReasonData.isEmpty {
            return AnyView(
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No Data Available")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("No suspended projects found")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            )
        }
        
        // Calculate X-axis max value
        let maxCount = viewModel.suspensionReasonData.map { $0.count }.max() ?? 0
        let xAxisMax: Double
        if maxCount == 0 {
            xAxisMax = 1.0
        } else {
            // Add 10% padding and round up to next 0.5
            let padding = max(Double(maxCount) * 0.1, 0.5)
            xAxisMax = ceil((Double(maxCount) + padding) * 2) / 2.0
        }
        
        return AnyView(ZStack(alignment: .topLeading) {
            Chart {
                ForEach(viewModel.suspensionReasonData, id: \.reason) { data in
                    BarMark(
                        x: .value("Count", Double(data.count)),
                        y: .value("Reason", data.reason)
                    )
                    .foregroundStyle(selectedSuspensionReason == data.reason ? Color.orange.opacity(0.8) : Color.orange)
                }
                
                // Show rule mark for selected reason
                if let selectedReason = selectedSuspensionReason {
                    RuleMark(y: .value("Reason", selectedReason))
                        .foregroundStyle(Color.accentColor.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
            .chartYSelection(value: $selectedSuspensionReason)
            .onChange(of: selectedSuspensionReason) { newValue in
                if let reason = newValue {
                    handleSuspensionReasonSelection(reason: reason)
                }
            }
            .chartXScale(domain: 0...xAxisMax, type: .linear)
            .chartXAxis {
                AxisMarks(position: .bottom, values: .stride(by: 0.5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let count = value.as(Double.self) {
                            Text(String(format: "%.1f", count))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 10)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let reason = value.as(String.self) {
                            Text(reason)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .chartXAxisLabel("Count")
                .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(minHeight: 200, maxHeight: 300)
            
            // Enhanced Tooltip overlay with safe positioning
            if let selectedReason = selectedSuspensionReason,
               let selectedData = viewModel.suspensionReasonData.first(where: { $0.reason == selectedReason }),
               let reasonIndex = viewModel.suspensionReasonData.firstIndex(where: { $0.reason == selectedReason }) {
                GeometryReader { geometry in
                    let barHeight = max(40.0, (geometry.size.height - 60) / CGFloat(max(viewModel.suspensionReasonData.count, 1)))
                    let preferredY = (CGFloat(reasonIndex) * barHeight) + (barHeight / 2) + 30
                    
                    // Calculate x position based on the bar's end (count value)
                    let maxCount = viewModel.suspensionReasonData.map { $0.count }.max() ?? 1
                    let barWidthRatio = Double(selectedData.count) / Double(maxCount)
                    let chartAreaWidth = geometry.size.width - 16
                    let preferredX = chartAreaWidth * 0.75 * barWidthRatio + 60
                    
                    // Estimate tooltip size
                    let tooltipWidth: CGFloat = 220
                    let tooltipHeight: CGFloat = 80
                    
                    // Calculate safe position
                    let safePosition = calculateSafeTooltipPosition(
                        preferredX: preferredX,
                        preferredY: preferredY,
                        tooltipWidth: tooltipWidth,
                        tooltipHeight: tooltipHeight,
                        containerWidth: geometry.size.width,
                        containerHeight: geometry.size.height,
                        padding: 12
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedReason)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        
                        Divider()
                            .background(Color(.separator).opacity(0.3))
                        
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 10, height: 10)
                            Text("Projects")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(selectedData.count)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        
                        // Show press count if available
                        if let pressCount = suspensionReasonPressCounts[selectedReason], pressCount > 0 {
                            Divider()
                                .background(Color(.separator).opacity(0.3))
                            
                            HStack(spacing: 10) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.orange)
                                Text("Presses")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(pressCount)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: tooltipWidth)
                    .position(x: safePosition.x + tooltipWidth / 2, y: safePosition.y)
                }
                .frame(minHeight: 200, maxHeight: 300)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingSuspensionProjectModal) {
            if let reason = selectedSuspensionReasonForModal,
               let reasonData = viewModel.suspensionReasonData.first(where: { $0.reason == reason }) {
                SuspensionProjectListModalView(
                    reason: reason,
                    projectNames: reasonData.projectNames,
                    projectCount: reasonData.count,
                    searchTextBinding: $searchTextBinding,
                    dismissReports: dismissReports
                )
            }
        })
    }
    
    // Handler for suspension reason selection - handles press counting and single click modal
    private func handleSuspensionReasonSelection(reason: String) {
        let now = Date()
        
        // Cancel previous timer if it exists
        suspensionModalTimer?.invalidate()
        
        // Increment press counter
        suspensionReasonPressCounts[reason, default: 0] += 1
        
        // Check if this is the same reason as last tap
        if let lastReason = lastTappedSuspensionReason, lastReason == reason {
            // Same reason - check if it's a rapid press or single click
            if let lastTime = lastSuspensionTapTime, now.timeIntervalSince(lastTime) < 0.3 {
                // Rapid press - just update counter, don't show modal yet
                lastSuspensionTapTime = now
                return
            }
        }
        
        // New reason or gap > 300ms - set up timer to show modal after 300ms of inactivity
        lastSuspensionTapTime = now
        lastTappedSuspensionReason = reason
        
        suspensionModalTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { timer in
            DispatchQueue.main.async {
                // After 300ms of no activity, show modal if counter is 1 (single click)
                // or just show the counter if multiple presses
                if self.suspensionReasonPressCounts[reason] == 1 {
                    // Single click - show modal
                    self.selectedSuspensionReasonForModal = reason
                    self.showingSuspensionProjectModal = true
                    // Reset press count after showing modal
                    self.suspensionReasonPressCounts[reason] = 0
                }
                // If counter > 1, just keep showing the counter in the tooltip
            }
        }
        RunLoop.main.add(suspensionModalTimer!, forMode: .common)
    }
    
    // Modal view for displaying project names for suspension reasons
    private struct SuspensionProjectListModalView: View {
        let reason: String
        let projectNames: [String]
        let projectCount: Int
        @Binding var searchTextBinding: String
        let dismissReports: () -> Void
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            NavigationView {
                VStack(spacing: 0) {
                    // Header info
                    VStack(spacing: 12) {
                        Text(reason)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        HStack(spacing: 16) {
                            VStack(spacing: 4) {
                                Text("\(projectCount)")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.orange)
                                Text("Projects")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    .background(Color(.systemGroupedBackground))
                    
                    Divider()
                    
                    // Scrollable project list
                    if projectNames.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No Projects")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("No projects found for this suspension reason")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(projectNames, id: \.self) { projectName in
                                    Button {
                                        HapticManager.selection()
                                        // Set search text and dismiss both modals
                                        searchTextBinding = projectName
                                        dismiss()
                                        // Small delay to ensure modal dismisses before reports dismisses
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            dismissReports()
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "building.2.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(.orange)
                                                .frame(width: 24)
                                            
                                            Text(projectName)
                                                .font(.system(size: 16, weight: .regular))
                                                .foregroundStyle(.primary)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                        .background(Color(.systemBackground))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if projectName != projectNames.last {
                                        Divider()
                                            .padding(.leading, 44)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                .background(Color(.systemGroupedBackground))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

