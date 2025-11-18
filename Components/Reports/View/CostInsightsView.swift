//
//  CostInsightsView.swift
//  AVREntertainment
//
//  Created by Auto on 1/1/25.
//

import SwiftUI
import Charts

struct CostInsightsView: View {
    @ObservedObject var viewModel: MainReportViewModel
    @Binding var expandedChartId: String?
    let isViewModelReady: Bool
    
    // MARK: - State Variables for Cost Charts
    @State private var selectedCostTrendMonth: String? = nil
    @State private var selectedPhaseName: String? = nil
    @State private var selectedStageForTooltip: String? = nil
    @State private var selectedProjectName: String? = nil
    @State private var selectedProjectForTooltip: String? = nil
    @State private var selectedStageProjectForTooltip: String? = nil
    @State private var selectedStatusForTooltip: String? = nil
    @State private var selectedSpendCategory: String? = nil
    @State private var selectedOverrunStage: String? = nil
    @State private var selectedBurnRateProject: String? = nil
    
    var body: some View {
        // Check isViewModelReady FIRST before any ViewModel access
        // This prevents EXC_BAD_ACCESS crashes on older devices
        if !isViewModelReady {
            EmptyView()
        } else if viewModel.isLoading {
            EmptyView()
        } else if viewModel.costTrendData.count == 0 {
            EmptyView()
        } else {
            costInsightsContentBody()
        }
    }
    
    @ViewBuilder
    private func costInsightsContentBody() -> some View {
        // Ensure we're on main thread and ViewModel is ready before accessing properties
        if isViewModelReady && !viewModel.isLoading {
            VStack(spacing: DesignSystem.Spacing.medium) {
                // Cost Trend Chart
                ReportChartCard(
                    title: "Cost Trend (MoM)",
                    subtitle: "Monthly total cost · ₹ ",
                    totalValue: viewModel.costTrendTotal,
                    chartId: "costTrend",
                    expandedChartId: $expandedChartId
                ) {
                    costTrendChart
                }
                
                // Stage Budget vs Actual - Only show if more than 1 phase
                if viewModel.stageBudgetData.count > 1 {
                    ReportChartCard(
                        title: "Stage Budget vs Actual",
                        subtitle: "₹  · Budget vs Actuals",
                        totalValue: nil,
                        chartId: "stageBudget",
                        expandedChartId: $expandedChartId
                    ) {
                        stageBudgetChart
                    }
                }
                
                // Project-wise Budget vs Actual - Only show if more than 1 project
                if viewModel.projectWiseData.count > 1 {
                    ReportChartCard(
                        title: "Project-wise Budget vs Actual",
                        subtitle: "Total project budget vs total spend",
                        totalValue: nil,
                        chartId: "projectWise",
                        expandedChartId: $expandedChartId
                    ) {
                        projectWiseBudgetChart
                    }
                }
                
                // Projects at Selected Stage
                ReportChartCard(
                    title: "Projects at Selected Stage",
                    subtitle: "Budget vs Actual at this stage across projects",
                    totalValue: nil,
                    chartId: "stageAcrossProjects",
                    expandedChartId: $expandedChartId
                ) {
                    stageAcrossProjectsChart
                }
                
                // Cost by Project Status
                ReportChartCard(
                    title: "Cost by Project Status",
                    subtitle: "₹  · Portfolio split",
                    totalValue: nil,
                    chartId: "statusCost",
                    expandedChartId: $expandedChartId
                ) {
                    statusCostChart
                }
                
                // Sub-Category Spend
                ReportChartCard(
                    title: "Sub-Category Spend",
                    subtitle: "Filtered by Project · Department",
                    totalValue: nil,
                    chartId: "subCategorySpend",
                    expandedChartId: $expandedChartId
                ) {
                    subCategorySpendChart
                }
                
                // Cost Overrun vs Stage Progress
                ReportChartCard(
                    title: "Cost Overrun vs Stage Progress",
                    subtitle: "Variance % vs Progress %",
                    totalValue: nil,
                    chartId: "overrun",
                    expandedChartId: $expandedChartId
                ) {
                    overrunScatterChart
                }
                
                // Burn Rate by Project
                ReportChartCard(
                    title: "Burn Rate by Project",
                    subtitle: "Total approved expenses · last 30 days",
                    totalValue: nil,
                    chartId: "burnRate",
                    expandedChartId: $expandedChartId
                ) {
                    burnRateChart
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
    
    // Helper function to format values without currency symbol (for tooltip labels)
    private func formatValue(_ value: Double) -> String {
        let absValue = abs(value)
        
        if absValue < 1000 {
            // 1 to 999: show actual numbers
            return String(format: "%.0f", value)
        } else if absValue < 100000 {
            // 1000 to 99999: show in thousands (k) with 2 decimals (e.g., "1.00k")
            let thousands = value / 1000.0
            return String(format: "%.2fk", thousands)
        } else if absValue < 10000000 {
            // 100000 to 9999999: show in lakhs with 2 decimals (e.g., "9.99 lakhs")
            let lakhs = value / 100000.0
            return String(format: "%.2f lakhs", lakhs)
        } else {
            // 10000000+: show in crores (Cr) with 2 decimals
            let crores = value / 10000000.0
            return String(format: "%.2f Cr", crores)
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
    
    // Helper function to generate Y-axis values that always include 0
    private func generateYAxisValues(max: Double, desiredCount: Int = 5) -> [Double] {
        guard max > 0 else { return [0, 1000] }
        
        // Calculate a nice step size
        let range = max
        let rawStep = range / Double(desiredCount - 1)
        
        // Round to a nice number
        let magnitude = pow(10, floor(log10(rawStep)))
        let normalizedStep = rawStep / magnitude
        let niceStep: Double
        
        if normalizedStep <= 1 {
            niceStep = 1 * magnitude
        } else if normalizedStep <= 2 {
            niceStep = 2 * magnitude
        } else if normalizedStep <= 5 {
            niceStep = 5 * magnitude
        } else {
            niceStep = 10 * magnitude
        }
        
        // Generate values starting from 0
        var values: [Double] = [0]
        var current = niceStep
        while current < max * 1.01 { // Add small tolerance to include max
            values.append(current)
            current += niceStep
        }
        
        // Ensure max is included if it's not already close to a step
        if let last = values.last, abs(last - max) > niceStep * 0.1 {
            values.append(max)
        }
        
        // Sort and remove duplicates
        values = Array(Set(values)).sorted()
        
        return values
    }
    
    // MARK: - Charts
    
    // Cost Trend Chart
    private var costTrendChart: some View {
        // Always use vertical layout with horizontal scrolling for > 6 months
        // Y-axis is fixed, only chart content scrolls
        let maxValue = viewModel.costTrendData.map { $0.value }.max() ?? 0
        // Calculate Y-axis max: if max is 0, use small default; otherwise add 10% padding, but ensure it's at least slightly above max
        let yAxisMax: Double
        if maxValue == 0 {
            yAxisMax = 1000 // Small default when all values are 0
        } else {
            // Add 10% padding, but ensure minimum increment
            let padding = max(maxValue * 0.1, maxValue * 0.05)
            yAxisMax = maxValue + padding
        }
        
        return ZStack(alignment: .top) {
            GeometryReader { geometry in
                HStack(alignment: .top, spacing: 0) {

                    // -----------------------------
                    // FIXED Y-AXIS (Enhanced styling)
                    // -----------------------------
                    Chart {
                        ForEach(viewModel.costTrendData, id: \.month) { data in
                            AreaMark(
                                x: .value("Month", data.month),
                                y: .value("Cost", max(data.value, 0))
                            )
                            .foregroundStyle(.clear)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYScale(domain: 0...yAxisMax)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color(.separator).opacity(0.3))
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(formatChartValue(v))
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartPlotStyle { plot in
                        plot.frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .frame(width: 70, alignment: .leading) // Wider to ensure labels are fully visible
                    .padding(.trailing, 4)
                    .padding(.top, 4) // Minimal top padding
                    .padding(.bottom, 40) // Bottom padding to show 0 at bottom

                    // -----------------------------
                    // SCROLLABLE CHART (Enhanced)
                    // -----------------------------
                    ZStack(alignment: .trailing) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            ZStack(alignment: .top) {
                            Chart {
                                // 1️⃣ AREA FIRST – this fixes the baseline (Enhanced gradient)
                                ForEach(viewModel.costTrendData, id: \.month) { data in
                                    AreaMark(
                                        x: .value("Month", data.month),
                                        y: .value("Cost", max(data.value, 0))
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color.accentColor.opacity(0.3),
                                                Color.accentColor.opacity(0.15),
                                                Color.accentColor.opacity(0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)
                                }

                                // 2️⃣ LINE ON TOP (Enhanced styling)
                                ForEach(viewModel.costTrendData, id: \.month) { data in
                                    LineMark(
                                        x: .value("Month", data.month),
                                        y: .value("Cost", max(data.value, 0))
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                    .symbol {
                                        Circle()
                                            .fill(Color.accentColor)
                                            .frame(width: selectedCostTrendMonth == data.month ? 8 : 6, height: selectedCostTrendMonth == data.month ? 8 : 6)
                                            .shadow(color: Color.accentColor.opacity(0.5), radius: 3)
                                    }
                                    .symbolSize(selectedCostTrendMonth == data.month ? 80 : 50)
                                    .interpolationMethod(.catmullRom)
                                }
                                
                                // Show tooltip indicators for selected month (Enhanced)
                                if let selectedMonth = selectedCostTrendMonth,
                                   let selectedData = viewModel.costTrendData.first(where: { $0.month == selectedMonth }) {
                                    RuleMark(x: .value("Month", selectedMonth))
                                        .foregroundStyle(Color.accentColor.opacity(0.4))
                                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                                    
                                    PointMark(
                                        x: .value("Month", selectedMonth),
                                        y: .value("Cost", max(selectedData.value, 0))
                                    )
                                    .foregroundStyle(Color.accentColor)
                                    .symbol {
                                        Circle()
                                            .fill(Color.accentColor)
                                            .frame(width: 10, height: 10)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 2)
                                            )
                                            .shadow(color: Color.accentColor.opacity(0.6), radius: 4)
                                    }
                                    .symbolSize(100)
                                }
                            }
                            .chartXSelection(value: $selectedCostTrendMonth)
                            .chartYAxis(.hidden)
                            .chartYScale(domain: 0...yAxisMax)
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                        .foregroundStyle(Color(.separator).opacity(0.2))
                                    AxisValueLabel {
                                        if let month = value.as(String.self) {
                                            Text(month)
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .chartPlotStyle { plot in
                                plot.frame(maxHeight: .infinity, alignment: .bottom)
                            }
                            .frame(
                                width: max(CGFloat(viewModel.costTrendData.count) * 70,
                                           geometry.size.width - 70),
                                height: geometry.size.height
                            )
                            .padding(.bottom, 40)
                            .padding(.top, 8) // Reduced top padding
                            .padding(.leading, 4)
                            
                            // Enhanced Tooltip overlay with safe positioning
                            if let selectedMonth = selectedCostTrendMonth,
                               let selectedData = viewModel.costTrendData.first(where: { $0.month == selectedMonth }),
                               let monthIndex = viewModel.costTrendData.firstIndex(where: { $0.month == selectedMonth }) {
                                GeometryReader { tooltipGeometry in
                                    let chartWidth = max(CGFloat(viewModel.costTrendData.count) * 70,
                                                        geometry.size.width - 70)
                                    let dataCount = CGFloat(viewModel.costTrendData.count)
                                    let preferredX = (CGFloat(monthIndex) + 0.5) * (chartWidth / dataCount)
                                    
                                    // Estimate tooltip size
                                    let tooltipWidth: CGFloat = 180
                                    let tooltipHeight: CGFloat = 80
                                    
                                    // Calculate safe position
                                    let safePosition = calculateSafeTooltipPosition(
                                        preferredX: preferredX,
                                        preferredY: 24,
                                        tooltipWidth: tooltipWidth,
                                        tooltipHeight: tooltipHeight,
                                        containerWidth: tooltipGeometry.size.width,
                                        containerHeight: tooltipGeometry.size.height,
                                        padding: 12
                                    )
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(selectedMonth)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.primary)
                                        
                                        Divider()
                                            .background(Color(.separator).opacity(0.3))
                                        
                                        HStack(spacing: 8) {
                                            Image(systemName: "indianrupeesign.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(.secondary)
                                            Text("Cost")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(formatValue(selectedData.value))
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
                                .frame(
                                    width: max(CGFloat(viewModel.costTrendData.count) * 70,
                                               geometry.size.width - 70),
                                    height: geometry.size.height
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        }
                        .scrollIndicators(.hidden)
                        
                        // Arrow indicator on right side middle
                        VStack {
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                )
                                .padding(.trailing, 12)
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(minHeight: 220, maxHeight: 350)
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cost trend chart showing monthly costs")
        .accessibilityHint("Tap and drag to explore monthly data points")
    }
    
    // Stage Budget vs Actual Chart
    private var stageBudgetChart: some View {
        // Calculate Y-axis max value
        let maxValue = viewModel.stageBudgetData.map { max($0.budget, $0.actual) }.max() ?? 0
        let yAxisMax: Double
        if maxValue == 0 {
            yAxisMax = 1000 // Small default when all values are 0
        } else {
            // Add 10% padding, but ensure minimum increment
            let padding = max(maxValue * 0.1, maxValue * 0.05)
            yAxisMax = maxValue + padding
        }
        
        // Calculate nice step size for Y-axis
        let rawStep = yAxisMax / 5.0
        let magnitude = pow(10, floor(log10(rawStep)))
        let normalizedStep = rawStep / magnitude
        let niceStep: Double
        if normalizedStep <= 1 {
            niceStep = 1 * magnitude
        } else if normalizedStep <= 2 {
            niceStep = 2 * magnitude
        } else if normalizedStep <= 5 {
            niceStep = 5 * magnitude
        } else {
            niceStep = 10 * magnitude
        }
        
        // Fixed Y-axis chart
        let yAxisChart = Chart {
            ForEach(viewModel.stageBudgetData, id: \.stage) { data in
                BarMark(
                    x: .value("Stage", data.stage),
                    y: .value("Amount", max(data.budget, data.actual))
                )
                .foregroundStyle(.clear) // Invisible, just for axis calculation
            }
        }
        .chartXAxis(.hidden)
        .chartYScale(domain: 0...yAxisMax)
        .chartYAxis {
            AxisMarks(position: .leading, values: .stride(by: niceStep)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.separator).opacity(0.3))
                AxisValueLabel(centered: false) {
                    if let v = value.as(Double.self) {
                        Text(formatChartValue(v))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: 70, alignment: .leading) // Wider to ensure labels are fully visible
        .padding(.trailing, 4)
        .padding(.top, 0) // No top padding to maximize space for labels
        .padding(.bottom, 50) // Bottom padding to show 0 at bottom
        
        return ZStack(alignment: .top) {
            GeometryReader { geometry in
                HStack(alignment: .top, spacing: 0) {
                    // -----------------------------
                    // FIXED Y-AXIS (Enhanced)
                    // -----------------------------
                    yAxisChart
                    
                    // -----------------------------
                    // SCROLLABLE CHART CONTENT
                    // -----------------------------
                    ZStack(alignment: .trailing) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            ZStack(alignment: .top) {
                            Chart {
                                ForEach(viewModel.stageBudgetData, id: \.stage) { data in
                                    // Budget Bar (Enhanced styling)
                                    BarMark(
                                        x: .value("Stage", data.stage),
                                        y: .value("Amount", data.budget)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: selectedStageForTooltip == data.stage 
                                                ? [Color.blue.opacity(0.9), Color.blue.opacity(0.7)]
                                                : [Color.blue.opacity(0.8), Color.blue.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .cornerRadius(6)
                                    .position(by: .value("Type", "Budget"))
                                    
                                    // Actual Bar (Enhanced styling)
                                    BarMark(
                                        x: .value("Stage", data.stage),
                                        y: .value("Amount", data.actual)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: selectedStageForTooltip == data.stage
                                                ? [Color.green.opacity(0.9), Color.green.opacity(0.7)]
                                                : [Color.green.opacity(0.8), Color.green.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .cornerRadius(6)
                                    .position(by: .value("Type", "Actual"))
                                }
                                
                                // Show rule mark for selected stage (Enhanced)
                                if let selectedStage = selectedStageForTooltip {
                                    RuleMark(x: .value("Stage", selectedStage))
                                        .foregroundStyle(Color.accentColor.opacity(0.4))
                                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                                }
                            }
                            .chartXSelection(value: $selectedStageForTooltip)
                            .chartXAxis {
                                stageBudgetXAxis
                            }
                            .chartYAxis(.hidden) // Hide Y-axis in scrollable part
                            .chartYScale(domain: 0...yAxisMax)
                            .chartForegroundStyleScale([
                                "Budget": Color.blue,
                                "Actual": Color.green
                            ])
                            .chartLegend(position: .bottom, alignment: .center, spacing: 16)
                            .chartPlotStyle { plot in
                                plot.frame(maxHeight: .infinity, alignment: .bottom)
                            }
                            // Calculate width: each bar pair needs ~90 points for better spacing
                            .frame(
                                width: max(CGFloat(viewModel.stageBudgetData.count) * 90, geometry.size.width - 70),
                                height: geometry.size.height
                            )
                            .padding(.bottom, 60) // Increased padding for rotated labels
                            .padding(.top, 12)
                            .padding(.leading, 4)
                            
                            // Enhanced Tooltip overlay with safe positioning
                            if let selectedStage = selectedStageForTooltip,
                               let selectedData = viewModel.stageBudgetData.first(where: { $0.stage == selectedStage }),
                               let stageIndex = viewModel.stageBudgetData.firstIndex(where: { $0.stage == selectedStage }) {
                                GeometryReader { tooltipGeometry in
                                    let chartWidth = max(CGFloat(viewModel.stageBudgetData.count) * 90, geometry.size.width - 70)
                                    let dataCount = CGFloat(viewModel.stageBudgetData.count)
                                    let preferredX = (CGFloat(stageIndex) + 0.5) * (chartWidth / dataCount)
                                    
                                    // Estimate tooltip size
                                    let tooltipWidth: CGFloat = 200
                                    let tooltipHeight: CGFloat = 140
                                    
                                    // Calculate safe position
                                    let safePosition = calculateSafeTooltipPosition(
                                        preferredX: preferredX,
                                        preferredY: 28,
                                        tooltipWidth: tooltipWidth,
                                        tooltipHeight: tooltipHeight,
                                        containerWidth: tooltipGeometry.size.width,
                                        containerHeight: tooltipGeometry.size.height,
                                        padding: 12
                                    )
                                    
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(truncateName(selectedStage))
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        
                                        Divider()
                                            .background(Color(.separator).opacity(0.3))
                                        
                                        // Budget row
                                        HStack(spacing: 10) {
                                            Circle()
                                                .fill(Color.blue)
                                                .frame(width: 10, height: 10)
                                            Text("Budget")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(formatValue(selectedData.budget))
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(.primary)
                                        }
                                        
                                        // Actual row
                                        HStack(spacing: 10) {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 10, height: 10)
                                            Text("Actual")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(formatValue(selectedData.actual))
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(.primary)
                                        }
                                        
                                        // Variance row
                                        let variance = selectedData.actual - selectedData.budget
                                        let variancePercent = selectedData.budget > 0 ? (variance / selectedData.budget) * 100 : 0
                                        HStack(spacing: 10) {
                                            Image(systemName: variance >= 0 ? "arrow.up.right" : "arrow.down.right")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(variance >= 0 ? .red : .green)
                                            Text("Variance")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(String(format: "%.1f%%", abs(variancePercent)))
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundStyle(variance >= 0 ? .red : .green)
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
                                .frame(
                                    width: max(CGFloat(viewModel.stageBudgetData.count) * 90, geometry.size.width - 70),
                                    height: geometry.size.height
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        }
                        .scrollIndicators(.hidden)
                        
                        // Arrow indicator on right side middle
                        VStack {
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                )
                                .padding(.trailing, 6)
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(minHeight: 220, maxHeight: 350)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stage budget versus actual chart")
        .accessibilityHint("Tap on bars to see detailed budget and actual values")
        .sheet(item: Binding(
            get: { selectedPhaseName.map { PhaseNameItem(name: $0) } },
            set: { selectedPhaseName = $0?.name }
        )) { item in
            phaseNameSheet(item: item)
        }
    }
    
    private var stageBudgetXAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 10)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(Color(.separator).opacity(0.2))
            AxisValueLabel {
                if let phaseName = value.as(String.self) {
                    TruncatedPhaseNameView(
                        phaseName: phaseName,
                        onTap: {
                            selectedPhaseName = phaseName
                        }
                    )
                    .rotationEffect(.degrees(-45), anchor: .center)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                }
            }
        }
    }
    
    private func phaseNameSheet(item: PhaseNameItem) -> some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text(item.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.selection()
                        selectedPhaseName = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // Helper struct for phase name display with truncation
    private struct TruncatedPhaseNameView: View {
        let phaseName: String
        let onTap: () -> Void
        let maxLength: Int = 20 // Increased to show more characters
        
        private var truncatedName: String {
            if phaseName.count > maxLength {
                return String(phaseName.prefix(maxLength)) + "..."
            }
            return phaseName
        }
        
        private var needsTruncation: Bool {
            phaseName.count > maxLength
        }
        
        var body: some View {
            Group {
                Text(truncatedName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 120) // Increased width for better visibility
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticManager.selection()
                        if needsTruncation {
                            onTap()
                        }
                    }
            }
        }
    }
    
    // Helper struct for sheet presentation
    private struct PhaseNameItem: Identifiable {
        let id = UUID()
        let name: String
    }
    
    // Project-wise Budget vs Actual Chart
    private var projectWiseBudgetChart: some View {
        // Calculate Y-axis max value
        let maxValue = viewModel.projectWiseData.map { max($0.budget, $0.actual) }.max() ?? 0
        let yAxisMax: Double
        if maxValue == 0 {
            yAxisMax = 1000 // Small default when all values are 0
        } else {
            // Add 10% padding, but ensure minimum increment
            let padding = max(maxValue * 0.1, maxValue * 0.05)
            yAxisMax = maxValue + padding
        }
        
        // Generate Y-axis values that always include 0
        let yAxisValues = generateYAxisValues(max: yAxisMax, desiredCount: 5)
        
        // Fixed Y-axis chart
        let yAxisChart = Chart {
            ForEach(viewModel.projectWiseData, id: \.project) { data in
                BarMark(
                    x: .value("Project", data.project),
                    y: .value("Amount", max(data.budget, data.actual))
                )
                .foregroundStyle(.clear) // Invisible, just for axis calculation
            }
        }
        .chartXAxis(.hidden)
        .chartYScale(domain: 0...yAxisMax)
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxisValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.separator).opacity(0.3))
                AxisValueLabel(centered: false) {
                    if let v = value.as(Double.self) {
                        Text(formatChartValue(v))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: 70, alignment: .leading) // Wider to ensure labels are fully visible
        .padding(.trailing, 4)
        .padding(.top, 4) // Minimal top padding
        .padding(.bottom, 50) // Bottom padding to show 0 at bottom
        
        return ZStack(alignment: .top) {
            GeometryReader { geometry in
                HStack(alignment: .top, spacing: 0) {
                    // -----------------------------
                    // FIXED Y-AXIS (Enhanced)
                    // -----------------------------
                    yAxisChart
                    
                    // -----------------------------
                    // SCROLLABLE CHART CONTENT
                    // -----------------------------
                    ZStack(alignment: .trailing) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            ZStack(alignment: .top) {
                            Chart {
                                ForEach(viewModel.projectWiseData, id: \.project) { data in
                                    // Budget Bar (Enhanced styling)
                                    BarMark(
                                        x: .value("Project", data.project),
                                        y: .value("Amount", data.budget)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: selectedProjectForTooltip == data.project
                                                ? [Color.blue.opacity(0.9), Color.blue.opacity(0.7)]
                                                : [Color.blue.opacity(0.8), Color.blue.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .cornerRadius(6)
                                    .position(by: .value("Type", "Budget"))
                                    
                                    // Actual Bar (Enhanced styling)
                                    BarMark(
                                        x: .value("Project", data.project),
                                        y: .value("Amount", data.actual)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: selectedProjectForTooltip == data.project
                                                ? [Color.green.opacity(0.9), Color.green.opacity(0.7)]
                                                : [Color.green.opacity(0.8), Color.green.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .cornerRadius(6)
                                    .position(by: .value("Type", "Actual"))
                                }
                                
                                // Show rule mark for selected project (Enhanced)
                                if let selectedProject = selectedProjectForTooltip {
                                    RuleMark(x: .value("Project", selectedProject))
                                        .foregroundStyle(Color.accentColor.opacity(0.4))
                                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                                }
                            }
                            .chartXSelection(value: $selectedProjectForTooltip)
                            .chartXAxis {
                                projectWiseXAxis
                            }
                            .chartYAxis(.hidden) // Hide Y-axis in scrollable part
                            .chartYScale(domain: 0...yAxisMax)
                            .chartForegroundStyleScale([
                                "Budget": Color.blue,
                                "Actual": Color.green
                            ])
                            .chartLegend(position: .bottom, alignment: .center, spacing: 16)
                            .chartPlotStyle { plot in
                                plot.frame(maxHeight: .infinity, alignment: .bottom)
                            }
                            // Calculate width: each bar pair needs ~90 points for better spacing
                            .frame(
                                width: max(CGFloat(viewModel.projectWiseData.count) * 90, geometry.size.width - 70),
                                height: geometry.size.height
                            )
                            .padding(.bottom, 50) // Reduced padding for rotated labels
                            .padding(.top, 8) // Reduced top padding
                            .padding(.leading, 4)
                            .padding(.trailing, 8)
                            
                            // Enhanced Tooltip overlay with safe positioning
                            if let selectedProject = selectedProjectForTooltip,
                               let selectedData = viewModel.projectWiseData.first(where: { $0.project == selectedProject }),
                               let projectIndex = viewModel.projectWiseData.firstIndex(where: { $0.project == selectedProject }) {
                                GeometryReader { tooltipGeometry in
                                    let chartWidth = max(CGFloat(viewModel.projectWiseData.count) * 90, geometry.size.width - 70)
                                    let dataCount = CGFloat(viewModel.projectWiseData.count)
                                    let preferredX = (CGFloat(projectIndex) + 0.5) * (chartWidth / dataCount)
                                    
                                    // Estimate tooltip size
                                    let tooltipWidth: CGFloat = 200
                                    let tooltipHeight: CGFloat = 140
                                    
                                    // Calculate safe position
                                    let safePosition = calculateSafeTooltipPosition(
                                        preferredX: preferredX,
                                        preferredY: 28,
                                        tooltipWidth: tooltipWidth,
                                        tooltipHeight: tooltipHeight,
                                        containerWidth: tooltipGeometry.size.width,
                                        containerHeight: tooltipGeometry.size.height,
                                        padding: 12
                                    )
                                    
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(truncateName(selectedProject))
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        
                                        Divider()
                                            .background(Color(.separator).opacity(0.3))
                                        
                                        // Budget row
                                        HStack(spacing: 10) {
                                            Circle()
                                                .fill(Color.blue)
                                                .frame(width: 10, height: 10)
                                            Text("Budget")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(formatValue(selectedData.budget))
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(.primary)
                                        }
                                        
                                        // Actual row
                                        HStack(spacing: 10) {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 10, height: 10)
                                            Text("Actual")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(formatValue(selectedData.actual))
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(.primary)
                                        }
                                        
                                        // Variance row
                                        let variance = selectedData.actual - selectedData.budget
                                        let variancePercent = selectedData.budget > 0 ? (variance / selectedData.budget) * 100 : 0
                                        HStack(spacing: 10) {
                                            Image(systemName: variance >= 0 ? "arrow.up.right" : "arrow.down.right")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(variance >= 0 ? .red : .green)
                                            Text("Variance")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(String(format: "%.1f%%", abs(variancePercent)))
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundStyle(variance >= 0 ? .red : .green)
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
                                .frame(
                                    width: max(CGFloat(viewModel.projectWiseData.count) * 90, geometry.size.width - 70),
                                    height: geometry.size.height
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        }
                        .scrollIndicators(.hidden)
                        
                        // Arrow indicator on right side middle
                        VStack {
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                )
                                .padding(.trailing, 12)
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(minHeight: 220, maxHeight: 350)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Project-wise budget versus actual chart")
        .accessibilityHint("Tap on bars to see detailed budget and actual values")
        .sheet(item: Binding(
            get: { selectedProjectName.map { ProjectNameItem(name: $0) } },
            set: { selectedProjectName = $0?.name }
        )) { item in
            projectNameSheet(item: item)
        }
    }
    
    private var projectWiseXAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 10)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(Color(.separator).opacity(0.2))
            AxisValueLabel {
                if let projectName = value.as(String.self) {
                    TruncatedProjectNameView(
                        projectName: projectName,
                        onTap: {
                            selectedProjectName = projectName
                        }
                    )
                    .rotationEffect(.degrees(-45), anchor: .center)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                }
            }
        }
    }
    
    private func projectNameSheet(item: ProjectNameItem) -> some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text(item.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.selection()
                        selectedProjectName = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // Helper struct for project name display with truncation
    private struct TruncatedProjectNameView: View {
        let projectName: String
        let onTap: () -> Void
        let maxLength: Int = 20 // Increased to show more characters
        
        private var truncatedName: String {
            if projectName.count > maxLength {
                return String(projectName.prefix(maxLength)) + "..."
            }
            return projectName
        }
        
        private var needsTruncation: Bool {
            projectName.count > maxLength
        }
        
        var body: some View {
            Group {
                Text(truncatedName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 120) // Increased width for better visibility
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticManager.selection()
                        if needsTruncation {
                            onTap()
                        }
                    }
            }
        }
    }
    
    // Helper struct for sheet presentation
    private struct ProjectNameItem: Identifiable {
        let id = UUID()
        let name: String
    }
    
    // Stage Across Projects Chart
    private var stageAcrossProjectsChart: some View {
        Group {
            if viewModel.selectedStages.isEmpty {
                VStack(spacing: DesignSystem.Spacing.small) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("Select a Stage above to compare projects")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("No stage selected. Select a stage to view project comparison.")
            } else if viewModel.selectedStages.count > 1 {
                VStack(spacing: DesignSystem.Spacing.small) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("Select a single Stage to compare projects")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Multiple stages selected. Select a single stage to view project comparison.")
            } else if viewModel.stageAcrossProjectsData.isEmpty {
                VStack(spacing: DesignSystem.Spacing.small) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("No projects found with the selected stage")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("No projects found with the selected stage.")
            } else {
                ZStack(alignment: .top) {
                    Chart {
                        ForEach(viewModel.stageAcrossProjectsData, id: \.project) { data in
                            BarMark(
                                x: .value("Project", data.project),
                                y: .value("Amount", data.budget)
                            )
                            .foregroundStyle(selectedStageProjectForTooltip == data.project ? Color.gray.opacity(0.8) : Color.gray)
                            .position(by: .value("Type", "Budget"))
                            
                            BarMark(
                                x: .value("Project", data.project),
                                y: .value("Amount", data.actual)
                            )
                            .foregroundStyle(selectedStageProjectForTooltip == data.project ? Color.green.opacity(0.8) : Color.green)
                            .position(by: .value("Type", "Actual"))
                        }
                        
                        // Show rule mark for selected project
                        if let selectedProject = selectedStageProjectForTooltip {
                            RuleMark(x: .value("Project", selectedProject))
                                .foregroundStyle(Color.accentColor.opacity(0.3))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        }
                    }
                    .chartXSelection(value: $selectedStageProjectForTooltip)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.quaternary)
                            AxisValueLabel {
                                if let project = value.as(String.self) {
                                    Text(truncateName(project))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.quaternary)
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text(formatChartValue(doubleValue))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    .chartForegroundStyleScale([
                        "Budget": Color.gray,
                        "Actual": Color.green
                    ])
                    .chartLegend(position: .bottom)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(minHeight: 200, maxHeight: 300)
                    
                    // Enhanced Tooltip overlay with safe positioning
                    if let selectedProject = selectedStageProjectForTooltip,
                       let selectedData = viewModel.stageAcrossProjectsData.first(where: { $0.project == selectedProject }),
                       let projectIndex = viewModel.stageAcrossProjectsData.firstIndex(where: { $0.project == selectedProject }) {
                        GeometryReader { geometry in
                            let chartWidth = geometry.size.width - 16 // Account for padding
                            let dataCount = CGFloat(viewModel.stageAcrossProjectsData.count)
                            let preferredX = (CGFloat(projectIndex) + 0.5) * (chartWidth / dataCount)
                            
                            // Estimate tooltip size
                            let tooltipWidth: CGFloat = 200
                            let tooltipHeight: CGFloat = 100
                            
                            // Calculate safe position
                            let safePosition = calculateSafeTooltipPosition(
                                preferredX: preferredX,
                                preferredY: 28,
                                tooltipWidth: tooltipWidth,
                                tooltipHeight: tooltipHeight,
                                containerWidth: geometry.size.width,
                                containerHeight: geometry.size.height,
                                padding: 12
                            )
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text(truncateName(selectedProject))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                
                                Divider()
                                    .background(Color(.separator).opacity(0.3))
                                
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 10, height: 10)
                                    Text("Budget")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(formatValue(selectedData.budget))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                }
                                
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 10, height: 10)
                                    Text("Actual")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(formatValue(selectedData.actual))
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
                        .frame(minHeight: 200, maxHeight: 300)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
    }
    
    // Helper function to get color for status based on display name
    private func getStatusColor(_ status: String) -> Color {
        switch status {
        case "Active":
            return .green
        case "Completed":
            return .blue
        case "Suspended":
            return .orange
        case "Maintenance":
            return .purple
        case "Archive":
            return .gray
        default:
            return .accentColor
        }
    }
    
    // Status Cost Chart
    private var statusCostChart: some View {
        // Calculate Y-axis max value
        let maxValue = viewModel.statusCostData.map { $0.value }.max() ?? 0
        let yAxisMax: Double
        if maxValue == 0 {
            yAxisMax = 1000 // Small default when all values are 0
        } else {
            // Add 10% padding, but ensure minimum increment
            let padding = max(maxValue * 0.1, maxValue * 0.05)
            yAxisMax = maxValue + padding
        }
        
        return ZStack(alignment: .top) {
            
            // MARK: - MAIN CHART
            Chart {
                ForEach(viewModel.statusCostData, id: \.status) { data in
                    BarMark(
                        x: .value("Status", data.status),
                        y: .value("Cost", data.value)
                    )
                    .foregroundStyle(
                        selectedStatusForTooltip == data.status
                        ? getStatusColor(data.status).opacity(0.85)
                        : getStatusColor(data.status)
                    )
                }

                // Selected Rule
                if let selectedStatus = selectedStatusForTooltip {
                    RuleMark(x: .value("Status", selectedStatus))
                        .foregroundStyle(Color.accentColor.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .chartXSelection(value: $selectedStatusForTooltip)
            .chartXAxis {
                AxisMarks(preset: .aligned, values: .automatic) { value in

                    AxisGridLine()
                        .foregroundStyle(.quaternary)

                    AxisValueLabel {
                        if let status = value.as(String.self) {
                            Text(status)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                                .rotationEffect(.degrees(-38))
                                .fixedSize()
                                .padding(.top, 6)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                        .foregroundStyle(.quaternary)

                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatChartValue(doubleValue))
                                .font(.system(size: 11))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 26)     // Extra for rotated labels
            .frame(minHeight: 240, maxHeight: 300)



            // MARK: - TOOLTIP OVERLAY
            if let selectedStatus = selectedStatusForTooltip,
               let selectedData = viewModel.statusCostData.first(where: { $0.status == selectedStatus }),
               let statusIndex = viewModel.statusCostData.firstIndex(where: { $0.status == selectedStatus }) {

                GeometryReader { geometry in

                    let chartWidth = geometry.size.width - 16
                    let barWidth = chartWidth / CGFloat(viewModel.statusCostData.count)
                    let preferredX = (CGFloat(statusIndex) + 0.5) * barWidth

                    let tooltipW: CGFloat = 180
                    let tooltipH: CGFloat = 82

                    let safe = calculateSafeTooltipPosition(
                        preferredX: preferredX,
                        preferredY: 32,
                        tooltipWidth: tooltipW,
                        tooltipHeight: tooltipH,
                        containerWidth: geometry.size.width,
                        containerHeight: geometry.size.height,
                        padding: 12
                    )

                    VStack(alignment: .leading, spacing: 8) {

                        // Title Row
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 10, height: 10)
                            Text(selectedStatus)
                                .font(.system(size: 14, weight: .semibold))
                        }

                        Divider().background(Color(.separator).opacity(0.3))

                        // Cost Row
                        HStack {
                            Image(systemName: "indianrupeesign.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            Text("Cost")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(formatValue(selectedData.value))
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
                    .frame(width: tooltipW, height: tooltipH)
                    .position(
                        x: safe.x + tooltipW / 2,
                        y: safe.y
                    )
                }
                .frame(minHeight: 240, maxHeight: 300)
                .transition(.opacity.combined(with: .scale))
            }
        }

    }
    
    // Sub-Category Spend Chart
    private var subCategorySpendChart: some View {
        ZStack(alignment: .trailing) {
            Chart {
                ForEach(viewModel.subCategorySpendData, id: \.category) { data in
                    BarMark(
                        x: .value("Spend", data.value),
                        y: .value("Category", data.category)
                    )
                    .foregroundStyle(selectedSpendCategory == data.category ? Color.cyan.opacity(0.8) : Color.cyan)
                }
                
                // Show rule mark for selected category
                if let selectedCategory = selectedSpendCategory,
                   let selectedData = viewModel.subCategorySpendData.first(where: { $0.category == selectedCategory }) {
                    RuleMark(y: .value("Category", selectedCategory))
                        .foregroundStyle(Color.accentColor.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
            .chartYSelection(value: $selectedSpendCategory)
            .chartXAxis {
                AxisMarks(position: .bottom, values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatChartValue(doubleValue))
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
            .frame(minHeight: CGFloat(max(viewModel.subCategorySpendData.count, 3)) * 50 + 60)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            
            // Enhanced Tooltip overlay with safe positioning
            if let selectedCategory = selectedSpendCategory,
               let selectedData = viewModel.subCategorySpendData.first(where: { $0.category == selectedCategory }),
               let categoryIndex = viewModel.subCategorySpendData.firstIndex(where: { $0.category == selectedCategory }) {
                GeometryReader { geometry in
                    let barHeight = 50.0
                    let preferredY = (CGFloat(categoryIndex) * barHeight) + (barHeight / 2) + 20
                    
                    // Calculate x position based on the bar's end (spend value)
                    let maxSpend = viewModel.subCategorySpendData.map { $0.value }.max() ?? 1
                    let barWidthRatio = Double(selectedData.value) / Double(maxSpend)
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
                            Image(systemName: "indianrupeesign.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("Spend")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatValue(selectedData.value))
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
                .frame(minHeight: CGFloat(max(viewModel.subCategorySpendData.count, 3)) * 50 + 60)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // Overrun Scatter Chart
    private var overrunScatterChart: some View {
        ZStack(alignment: .top) {
            Chart {
                ForEach(viewModel.overrunData, id: \.stage) { data in
                    PointMark(
                        x: .value("Progress", data.progress),
                        y: .value("Overrun", data.overrun)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: selectedOverrunStage == data.stage
                                ? [Color.red.opacity(0.9), Color.red.opacity(0.7)]
                                : [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbol {
                        Circle()
                            .fill(selectedOverrunStage == data.stage ? Color.red : Color.red.opacity(0.8))
                            .frame(width: selectedOverrunStage == data.stage ? 10 : 8, height: selectedOverrunStage == data.stage ? 10 : 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedOverrunStage == data.stage ? 2 : 1.5)
                            )
                            .shadow(color: Color.red.opacity(0.4), radius: selectedOverrunStage == data.stage ? 4 : 2)
                    }
                    .symbolSize(selectedOverrunStage == data.stage ? 100 : 70)
                }
                
                // Show rule marks for selected point (Enhanced)
                if let selectedStage = selectedOverrunStage,
                   let selectedData = viewModel.overrunData.first(where: { $0.stage == selectedStage }) {
                    RuleMark(x: .value("Progress", selectedData.progress))
                        .foregroundStyle(Color.accentColor.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    
                    RuleMark(y: .value("Overrun", selectedData.overrun))
                        .foregroundStyle(Color.accentColor.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                }
            }
            .chartXSelection(value: Binding(
                get: { 
                    if let stage = selectedOverrunStage,
                       let data = viewModel.overrunData.first(where: { $0.stage == stage }) {
                        return data.progress
                    }
                    return nil
                },
                set: { newProgress in
                    if let progress = newProgress {
                        // Find the closest point to the selected progress
                        if let closest = viewModel.overrunData.min(by: { 
                            abs($0.progress - progress) < abs($1.progress - progress) 
                        }) {
                            selectedOverrunStage = closest.stage
                        }
                    } else {
                        selectedOverrunStage = nil
                    }
                }
            ))
            .chartYSelection(value: Binding(
                get: { 
                    if let stage = selectedOverrunStage,
                       let data = viewModel.overrunData.first(where: { $0.stage == stage }) {
                        return data.overrun
                    }
                    return nil
                },
                set: { newOverrun in
                    if let overrun = newOverrun {
                        // If we already have an X selection, find the point that matches both
                        if let currentProgress = selectedOverrunStage.flatMap({ stage in
                            viewModel.overrunData.first(where: { $0.stage == stage })?.progress
                        }) {
                            // Find point closest to both current progress and new overrun
                            if let closest = viewModel.overrunData.min(by: {
                                let dist1 = sqrt(pow($0.progress - currentProgress, 2) + pow($0.overrun - overrun, 2))
                                let dist2 = sqrt(pow($1.progress - currentProgress, 2) + pow($1.overrun - overrun, 2))
                                return dist1 < dist2
                            }) {
                                selectedOverrunStage = closest.stage
                            }
                        } else {
                            // Just find closest by overrun
                            if let closest = viewModel.overrunData.min(by: { 
                                abs($0.overrun - overrun) < abs($1.overrun - overrun) 
                            }) {
                                selectedOverrunStage = closest.stage
                            }
                        }
                    } else {
                        selectedOverrunStage = nil
                    }
                }
            ))
            .chartXAxis {
                AxisMarks(position: .bottom, values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color(.separator).opacity(0.3))
                    AxisValueLabel {
                        if let progress = value.as(Double.self) {
                            Text("\(Int(progress))%")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color(.separator).opacity(0.3))
                    AxisValueLabel {
                        if let overrun = value.as(Double.self) {
                            Text("\(Int(overrun))%")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxisLabel("Stage Progress (%)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            .chartYAxisLabel("Cost Overrun (%)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(minHeight: 220, maxHeight: 350)
            
            // Enhanced Tooltip overlay with safe positioning
            if let selectedStage = selectedOverrunStage,
               let selectedData = viewModel.overrunData.first(where: { $0.stage == selectedStage }) {
                GeometryReader { geometry in
                    // Calculate position based on chart coordinates
                    // We need to map the data values to screen coordinates
                    let progressRange = viewModel.overrunData.map { $0.progress }
                    let overrunRange = viewModel.overrunData.map { $0.overrun }
                    
                    let minProgress = progressRange.min() ?? 0
                    let maxProgress = progressRange.max() ?? 100
                    let minOverrun = overrunRange.min() ?? -10
                    let maxOverrun = overrunRange.max() ?? 20
                    
                    let progressRangeSize = max(maxProgress - minProgress, 1)
                    let overrunRangeSize = max(maxOverrun - minOverrun, 1)
                    
                    // Chart area (accounting for padding and axis labels)
                    let chartPadding: CGFloat = 50
                    let chartWidth = geometry.size.width - chartPadding * 2
                    let chartHeight = geometry.size.height - chartPadding * 2
                    
                    // Calculate preferred position
                    let xRatio = (selectedData.progress - minProgress) / progressRangeSize
                    let yRatio = (selectedData.overrun - minOverrun) / overrunRangeSize
                    
                    let preferredX = chartPadding + (xRatio * chartWidth)
                    let preferredY = chartPadding + ((1 - yRatio) * chartHeight) // Invert Y for screen coordinates
                    
                    // Estimate tooltip size
                    let tooltipWidth: CGFloat = 220
                    let tooltipHeight: CGFloat = 110
                    
                    // Calculate safe position
                    let safePosition = calculateSafeTooltipPosition(
                        preferredX: preferredX,
                        preferredY: preferredY - 70, // Offset above point
                        tooltipWidth: tooltipWidth,
                        tooltipHeight: tooltipHeight,
                        containerWidth: geometry.size.width,
                        containerHeight: geometry.size.height,
                        padding: 12
                    )
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            Text(truncateName(selectedData.stage))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        
                        Divider()
                            .background(Color(.separator).opacity(0.3))
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Progress")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("\(Int(selectedData.progress))%")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                            
                            Divider()
                                .frame(height: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Overrun")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("\(Int(selectedData.overrun))%")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(selectedData.overrun > 0 ? .red : .green)
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
                    .transition(.scale.combined(with: .opacity))
                }
                .frame(minHeight: 220, maxHeight: 350)
            }
        }
    }
    
    // Burn Rate Chart
    private var burnRateChart: some View {
        // Handle empty state
        if viewModel.burnRateData.isEmpty {
            return AnyView(
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No Data Available")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("No approved expenses found in the last 30 days for selected filters")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            )
        }
        
        // Calculate X-axis max value based on totalSpend
        let maxSpend = viewModel.burnRateData.map { $0.totalSpend }.max() ?? 0
        let xAxisMax: Double
        if maxSpend == 0 {
            xAxisMax = 1000 // Default minimum
        } else {
            // Add 10% padding
            xAxisMax = maxSpend * 1.1
        }
        
        // Calculate chart height for vertical scrolling
        let barHeight: CGFloat = 24
        let barSpacing: CGFloat = 4
        let totalBarHeight = barHeight + barSpacing
        let chartHeight = CGFloat(viewModel.burnRateData.count) * totalBarHeight + 60 // 60 for padding
        
        return AnyView(
            ZStack(alignment: .topLeading) {
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // -----------------------------
                        // SCROLLABLE CHART CONTENT (with Y-axis labels)
                        // -----------------------------
                        ZStack(alignment: .bottom) {
                            ScrollView(.vertical, showsIndicators: false) {
                                ZStack(alignment: .topLeading) {
                                Chart {
                                    ForEach(viewModel.burnRateData, id: \.project) { data in
                                        BarMark(
                                            x: .value("Total Spend", data.totalSpend),
                                            y: .value("Project", data.project)
                                        )
                                        .foregroundStyle(
                                            selectedBurnRateProject == data.project
                                                ? Color.green
                                                : Color.green.opacity(0.85)
                                        )
                                        .cornerRadius(2)
                                    }
                                    
                                    // Show rule mark for selected project
                                    if let selectedProject = selectedBurnRateProject {
                                        RuleMark(y: .value("Project", selectedProject))
                                            .foregroundStyle(Color.accentColor.opacity(0.3))
                                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                    }
                                }
                                .chartYSelection(value: $selectedBurnRateProject)
                                .chartXAxis(.hidden) // Hide X-axis in scrollable part
                                .chartXScale(domain: 0...xAxisMax, type: .linear)
                                .chartYAxis {
                                    AxisMarks(position: .leading, values: .automatic(desiredCount: viewModel.burnRateData.count)) { value in
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                            .foregroundStyle(Color(.separator).opacity(0.2))
                                        AxisValueLabel {
                                            if let project = value.as(String.self) {
                                                Text(truncateName(project))
                                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                    }
                                }
                                .chartPlotStyle { plot in
                                    plot.frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .frame(
                                    width: geometry.size.width,
                                    height: max(chartHeight, geometry.size.height - 70)
                                )
                                .padding(.leading, 4)
                                .padding(.trailing, 12)
                                .padding(.top, 12)
                                .padding(.bottom, 70) // Space for fixed X-axis with rotated labels
                                
                                // Enhanced Tooltip overlay with safe positioning
                                if let selectedProject = selectedBurnRateProject,
                                   let selectedData = viewModel.burnRateData.first(where: { $0.project == selectedProject }),
                                   let projectIndex = viewModel.burnRateData.firstIndex(where: { $0.project == selectedProject }) {
                                    GeometryReader { tooltipGeometry in
                                        // Calculate Y position based on bar position
                                        let preferredY = CGFloat(projectIndex) * totalBarHeight + (barHeight / 2) + 12
                                        
                                        // Calculate X position based on the bar's end (totalSpend value)
                                        let barWidthRatio = Double(selectedData.totalSpend) / Double(xAxisMax)
                                        let chartAreaWidth = tooltipGeometry.size.width - 16 // Account for padding
                                        let preferredX = chartAreaWidth * 0.85 * barWidthRatio + 80
                                        
                                        // Estimate tooltip size
                                        let tooltipWidth: CGFloat = 200
                                        let tooltipHeight: CGFloat = 80
                                        
                                        // Calculate safe position
                                        let safePosition = calculateSafeTooltipPosition(
                                            preferredX: preferredX,
                                            preferredY: preferredY,
                                            tooltipWidth: tooltipWidth,
                                            tooltipHeight: tooltipHeight,
                                            containerWidth: tooltipGeometry.size.width,
                                            containerHeight: tooltipGeometry.size.height,
                                            padding: 12
                                        )
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(truncateName(selectedProject))
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            
                                            Divider()
                                                .background(Color(.separator).opacity(0.3))
                                            
                                            HStack(spacing: 8) {
                                                Image(systemName: "indianrupeesign.circle.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(.secondary)
                                                Text("Total Spend")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(.secondary)
                                                Spacer()
                                                Text(formatValue(selectedData.totalSpend))
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundStyle(.primary)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(.regularMaterial)
                                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                                        )
                                        .frame(width: tooltipWidth)
                                        .position(x: safePosition.x + tooltipWidth / 2, y: safePosition.y)
                                    }
                                    .frame(
                                        width: geometry.size.width,
                                        height: max(chartHeight, geometry.size.height - 70)
                                    )
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            }
                            .scrollIndicators(.hidden)
                            
                            // Arrow indicator on bottom middle (for vertical scroll)
                            HStack {
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    )
                                    .padding(.bottom, 80) // Position above the fixed X-axis
                                Spacer()
                            }
                            .allowsHitTesting(false)
                        }
                        
                        // -----------------------------
                        // FIXED X-AXIS (at bottom, showing values)
                        // -----------------------------
                        Chart {
                            ForEach(viewModel.burnRateData, id: \.project) { data in
                                BarMark(
                                    x: .value("Total Spend", data.totalSpend),
                                    y: .value("Project", data.project)
                                )
                                .foregroundStyle(.clear) // Invisible, just for axis calculation
                            }
                        }
                        .chartYAxis(.hidden)
                        .chartXScale(domain: 0...xAxisMax, type: .linear)
                        .chartXAxis {
                            AxisMarks(position: .bottom, values: .automatic(desiredCount: 6)) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(Color(.separator).opacity(0.3))
                                AxisValueLabel {
                                    if let spend = value.as(Double.self) {
                                        Text(formatChartValue(spend))
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                            .rotationEffect(.degrees(-90))
                                            .offset(x: 0, y: 8)
                                    }
                                }
                            }
                        }
                        .chartPlotStyle { plot in
                            plot.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 70) // Increased height for rotated labels
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(minHeight: 180, maxHeight: 350)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Burn rate chart showing total approved expenses by project for last 30 days")
            .accessibilityHint("Tap on bars to see detailed spending information")
        )
    }
}

