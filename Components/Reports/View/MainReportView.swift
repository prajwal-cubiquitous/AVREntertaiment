//
//  MainReportView.swift
//  AVREntertainment
//
//  Created by Auto on 1/1/25.
//

import SwiftUI
import Charts
import Accessibility

struct MainReportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MainReportViewModel()
    @State private var selectedTab: ReportTab = .cost
    
    enum ReportTab: String, CaseIterable {
        case cost = "COST INSIGHTS"
        case project = "PROJECT INSIGHTS"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background with proper material
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with Tabs
                    headerView
                    
                    // Content
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.medium) {
                            // Filters Section
                            filtersSection
                            
                            // KPI Cards
                            kpiSection
                            
                            // Tab Content with animation
                            Group {
                                if selectedTab == .cost {
                                    costInsightsContent
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)
                                        ))
                                } else {
                                    projectInsightsContent
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)
                                        ))
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                        .padding(.vertical, DesignSystem.Spacing.medium)
                        .padding(.bottom, DesignSystem.Spacing.extraLarge)
                    }
                    .scrollIndicators(.visible)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticManager.selection()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Close Reports")
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            // Title Section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text("Tracura")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Portfolio · Cost & Project Insights")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.top, DesignSystem.Spacing.medium)
            .padding(.bottom, DesignSystem.Spacing.small)
            
            // Tabs with improved styling
            HStack(spacing: 0) {
                ForEach(ReportTab.allCases, id: \.self) { tab in
                    Button {
                        HapticManager.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 0) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium, design: .default))
                                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                                .padding(.vertical, DesignSystem.Spacing.small + 2)
                            
                            // Active indicator with animation
                            Rectangle()
                                .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                                .frame(height: 3)
                                .cornerRadius(1.5)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(tab.rawValue)
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
            .background(
                Divider()
                    .background(Color(.separator))
            )
        }
        .background(.regularMaterial)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Filters Section
    private var filtersSection: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            HStack(spacing: DesignSystem.Spacing.small) {
                // Project Filter
                filterDropdown(
                    label: "Project",
                    selection: $viewModel.selectedProject,
                    options: viewModel.projectOptions
                )
                
                // Stage Filter
                filterDropdown(
                    label: "Stage",
                    selection: $viewModel.selectedStage,
                    options: viewModel.stageOptions
                )
                
                // Department Filter
                filterDropdown(
                    label: "Department",
                    selection: $viewModel.selectedDepartment,
                    options: viewModel.departmentOptions
                )
            }
        }
    }
    
    private func filterDropdown(label: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        HapticManager.selection()
                        selection.wrappedValue = option
                    } label: {
                        HStack {
                            Text(option)
                            if selection.wrappedValue == option {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.small) {
                    Text(selection.wrappedValue)
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .symbolEffect(.bounce, value: selection.wrappedValue)
                }
                .padding(.horizontal, DesignSystem.Spacing.small + 2)
                .padding(.vertical, DesignSystem.Spacing.small)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                )
            }
            .accessibilityLabel("\(label) filter")
            .accessibilityValue(selection.wrappedValue)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - KPI Section
    private var kpiSection: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            kpiCard(label: "Total Budget", value: viewModel.totalBudgetFormatted)
            kpiCard(label: "Total Spent", value: viewModel.totalSpentFormatted)
            kpiCard(label: "Remaining", value: viewModel.remainingFormatted)
        }
    }
    
    private func kpiCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.small + 2)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
    
    // MARK: - Cost Insights Content
    private var costInsightsContent: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Cost Trend Chart
            chartCard(
                title: "Cost Trend (MoM)",
                subtitle: "Monthly total cost · ₹ Cr",
                totalValue: viewModel.costTrendTotal
            ) {
                costTrendChart
            }
            
            // Stage Budget vs Actual
            chartCard(
                title: "Stage Budget vs Actual",
                subtitle: "₹ Cr · Budget vs Actuals"
            ) {
                stageBudgetChart
            }
            
            // Project-wise Budget vs Actual
            chartCard(
                title: "Project-wise Budget vs Actual",
                subtitle: "Total project budget vs total spend"
            ) {
                projectWiseBudgetChart
            }
            
            // Projects at Selected Stage
            chartCard(
                title: "Projects at Selected Stage",
                subtitle: "Budget vs Actual at this stage across projects"
            ) {
                stageAcrossProjectsChart
            }
            
            // Two Column Layout - Responsive
            GeometryReader { geometry in
                if geometry.size.width > 600 {
                    // Wider layout: side by side
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.medium) {
                        chartCard(
                            title: "Sub-Category Spend",
                            subtitle: "Filtered by Project · Department"
                        ) {
                            subCategorySpendChart
                        }
                        
                        chartCard(
                            title: "Cost by Project Status",
                            subtitle: "₹ Cr · Portfolio split"
                        ) {
                            statusCostChart
                        }
                    }
                } else {
                    // Narrow layout: stacked
                    VStack(spacing: DesignSystem.Spacing.medium) {
                        chartCard(
                            title: "Sub-Category Spend",
                            subtitle: "Filtered by Project · Department"
                        ) {
                            subCategorySpendChart
                        }
                        
                        chartCard(
                            title: "Cost by Project Status",
                            subtitle: "₹ Cr · Portfolio split"
                        ) {
                            statusCostChart
                        }
                    }
                }
            }
            .frame(height: 240)
            
            // Cost Overrun vs Stage Progress
            chartCard(
                title: "Cost Overrun vs Stage Progress",
                subtitle: "Variance % vs Progress %"
            ) {
                overrunScatterChart
            }
            
            // Burn Rate by Project
            chartCard(
                title: "Burn Rate by Project",
                subtitle: "₹ Cr/day · last 30 days"
            ) {
                burnRateChart
            }
        }
    }
    
    // MARK: - Project Insights Content
    private var projectInsightsContent: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Active Projects (MoM)
            chartCard(
                title: "Active Projects (MoM)",
                subtitle: "Count of active projects"
            ) {
                activeProjectsChart
            }
            
            // Stage Progress Status
            chartCard(
                title: "Stage Progress Status",
                subtitle: "% share of stages"
            ) {
                stageProgressChart
            }
            
            // Sub-Category Activity
            chartCard(
                title: "Sub-Category Activity",
                subtitle: "# of expenses · last 30 days"
            ) {
                subCategoryActivityChart
            }
            
            // Delay Days vs Extra Cost
            chartCard(
                title: "Delay Days vs Extra Cost",
                subtitle: "Project-level correlation"
            ) {
                delayCorrelationChart
            }
            
            // Suspended Projects by Reason
            chartCard(
                title: "Suspended Projects by Reason",
                subtitle: "Current FY"
            ) {
                suspensionReasonChart
            }
        }
    }
    
    // MARK: - Chart Card Helper
    private func chartCard<Content: View>(
        title: String,
        subtitle: String,
        totalValue: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.small) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let totalValue = totalValue {
                    Text(totalValue)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, DesignSystem.Spacing.small)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill))
                        .cornerRadius(DesignSystem.CornerRadius.small)
                }
            }
            
            content()
                .frame(height: 160)
                .accessibilityElement(children: .contain)
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(Color(.separator).opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(subtitle)")
    }
    
    // MARK: - Charts
    
    // Cost Trend Chart
    private var costTrendChart: some View {
        Chart {
            ForEach(viewModel.costTrendData, id: \.month) { data in
                LineMark(
                    x: .value("Month", data.month),
                    y: .value("Cost", data.value)
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.catmullRom)
                .symbol(.circle)
                .symbolSize(40)
                
                AreaMark(
                    x: .value("Month", data.month),
                    y: .value("Cost", data.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.quaternary)
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.quaternary)
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // Stage Budget vs Actual Chart
    private var stageBudgetChart: some View {
        Chart {
            ForEach(viewModel.stageBudgetData, id: \.stage) { data in
                BarMark(
                    x: .value("Stage", data.stage),
                    y: .value("Amount", data.budget)
                )
                .foregroundStyle(Color.blue)
                .position(by: .value("Type", "Budget"))
                
                BarMark(
                    x: .value("Stage", data.stage),
                    y: .value("Amount", data.actual)
                )
                .foregroundStyle(Color.green)
                .position(by: .value("Type", "Actual"))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartForegroundStyleScale([
            "Budget": Color.blue,
            "Actual": Color.green
        ])
        .chartLegend(position: .bottom)
    }
    
    // Project-wise Budget vs Actual Chart
    private var projectWiseBudgetChart: some View {
        Chart {
            ForEach(viewModel.projectWiseData, id: \.project) { data in
                BarMark(
                    x: .value("Project", data.project),
                    y: .value("Amount", data.budget)
                )
                .foregroundStyle(Color.blue)
                .position(by: .value("Type", "Budget"))
                
                BarMark(
                    x: .value("Project", data.project),
                    y: .value("Amount", data.actual)
                )
                .foregroundStyle(Color.green)
                .position(by: .value("Type", "Actual"))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartForegroundStyleScale([
            "Budget": Color.blue,
            "Actual": Color.green
        ])
        .chartLegend(position: .bottom)
    }
    
    // Stage Across Projects Chart
    private var stageAcrossProjectsChart: some View {
        Group {
            if viewModel.selectedStage == "All Stages" {
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
            } else {
                Chart {
                    ForEach(viewModel.stageAcrossProjectsData, id: \.project) { data in
                        BarMark(
                            x: .value("Project", data.project),
                            y: .value("Amount", data.budget)
                        )
                        .foregroundStyle(Color.gray)
                        .position(by: .value("Type", "Budget"))
                        
                        BarMark(
                            x: .value("Project", data.project),
                            y: .value("Amount", data.actual)
                        )
                        .foregroundStyle(Color.green)
                        .position(by: .value("Type", "Actual"))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartForegroundStyleScale([
                    "Budget": Color.gray,
                    "Actual": Color.green
                ])
                .chartLegend(position: .bottom)
            }
        }
    }
    
    // Sub-Category Spend Chart
    private var subCategorySpendChart: some View {
        Chart {
            ForEach(viewModel.subCategorySpendData, id: \.category) { data in
                BarMark(
                    x: .value("Spend", data.value),
                    y: .value("Category", data.category)
                )
                .foregroundStyle(Color.cyan)
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
            }
        }
    }
    
    // Status Cost Chart
    private var statusCostChart: some View {
        Chart {
            ForEach(viewModel.statusCostData, id: \.status) { data in
                BarMark(
                    x: .value("Status", data.status),
                    y: .value("Cost", data.value)
                )
                .foregroundStyle(Color.orange)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
    
    // Overrun Scatter Chart
    private var overrunScatterChart: some View {
        Chart {
            ForEach(viewModel.overrunData, id: \.stage) { data in
                PointMark(
                    x: .value("Progress", data.progress),
                    y: .value("Overrun", data.overrun)
                )
                .foregroundStyle(Color.red)
                .symbolSize(60)
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartXAxisLabel("Stage Progress (%)")
        .chartYAxisLabel("Cost Overrun (%)")
    }
    
    // Burn Rate Chart
    private var burnRateChart: some View {
        Chart {
            ForEach(viewModel.burnRateData, id: \.project) { data in
                BarMark(
                    x: .value("Rate", data.rate),
                    y: .value("Project", data.project)
                )
                .foregroundStyle(Color.green)
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
            }
        }
    }
    
    // Active Projects Chart
    private var activeProjectsChart: some View {
        Chart {
            ForEach(viewModel.activeProjectsData, id: \.month) { data in
                LineMark(
                    x: .value("Month", data.month),
                    y: .value("Count", data.count)
                )
                .foregroundStyle(Color.green)
                .interpolationMethod(.catmullRom)
                .symbol(.circle)
                .symbolSize(30)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
    
    // Stage Progress Chart
    private var stageProgressChart: some View {
        Chart {
            ForEach(viewModel.stageProgressData, id: \.stage) { data in
                BarMark(
                    x: .value("Stage", data.stage),
                    y: .value("Value", data.inProgress)
                )
                .foregroundStyle(Color.blue)
                .position(by: .value("Type", "In Progress"))
                
                BarMark(
                    x: .value("Stage", data.stage),
                    y: .value("Value", data.handover)
                )
                .foregroundStyle(Color.yellow)
                .position(by: .value("Type", "Handover"))
                
                BarMark(
                    x: .value("Stage", data.stage),
                    y: .value("Value", data.delayed)
                )
                .foregroundStyle(Color.orange)
                .position(by: .value("Type", "Delayed"))
                
                BarMark(
                    x: .value("Stage", data.stage),
                    y: .value("Value", data.complete)
                )
                .foregroundStyle(Color.gray)
                .position(by: .value("Type", "Complete"))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartForegroundStyleScale([
            "In Progress": Color.blue,
            "Handover": Color.yellow,
            "Delayed": Color.orange,
            "Complete": Color.gray
        ])
        .chartLegend(position: .bottom)
    }
    
    // Sub-Category Activity Chart
    private var subCategoryActivityChart: some View {
        Chart {
            ForEach(viewModel.subCategoryActivityData, id: \.category) { data in
                BarMark(
                    x: .value("Count", data.count),
                    y: .value("Category", data.category)
                )
                .foregroundStyle(Color.blue)
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
            }
        }
    }
    
    // Delay Correlation Chart
    private var delayCorrelationChart: some View {
        Chart {
            ForEach(viewModel.delayCorrelationData, id: \.project) { data in
                PointMark(
                    x: .value("Delay Days", data.delayDays),
                    y: .value("Extra Cost", data.extraCost)
                )
                .foregroundStyle(Color.cyan)
                .symbolSize(60)
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartXAxisLabel("Delay Days")
        .chartYAxisLabel("Extra Cost (₹ Cr)")
    }
    
    // Suspension Reason Chart
    private var suspensionReasonChart: some View {
        Chart {
            ForEach(viewModel.suspensionReasonData, id: \.reason) { data in
                BarMark(
                    x: .value("Count", data.count),
                    y: .value("Reason", data.reason)
                )
                .foregroundStyle(Color.orange)
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
            }
        }
    }
}


// MARK: - Preview
#Preview {
    MainReportView()
}

