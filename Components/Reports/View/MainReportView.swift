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
                    if viewModel.isLoading {
                        loadingView
                    } else {
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
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading reports...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Filters Section
    private var filtersSection: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            // First row: Date Range and Project Status
            HStack(spacing: DesignSystem.Spacing.small) {
                // Date Range Filter (takes 2/3 of width)
                dateRangeFilter
                    .frame(maxWidth: .infinity)
                
                // Project Status Filter (takes 1/3 of width) - Multi-select
                projectStatusMultiSelectFilter
                    .frame(maxWidth: .infinity)
            }
            
            // Second row: Project, Stage, Department
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
    
    // MARK: - Date Range Filter
    private var dateRangeFilter: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
            Text("Date Range")
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            Menu {
                Button {
                    HapticManager.selection()
                    // Set to last 3 months
                    let calendar = Calendar.current
                    viewModel.startDate = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
                    viewModel.endDate = Date()
                } label: {
                    Label("Last 3 Months", systemImage: "calendar")
                }
                
                Button {
                    HapticManager.selection()
                    // Set to last 6 months
                    let calendar = Calendar.current
                    viewModel.startDate = calendar.date(byAdding: .month, value: -6, to: Date()) ?? Date()
                    viewModel.endDate = Date()
                } label: {
                    Label("Last 6 Months", systemImage: "calendar")
                }
                
                Button {
                    HapticManager.selection()
                    // Set to last year
                    let calendar = Calendar.current
                    viewModel.startDate = calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
                    viewModel.endDate = Date()
                } label: {
                    Label("Last Year", systemImage: "calendar")
                }
                
                Divider()
                
                Button {
                    HapticManager.selection()
                    // Show custom date picker
                    showingDateRangePicker = true
                } label: {
                    Label("Custom Range", systemImage: "calendar.badge.clock")
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.small) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text(dateRangeDisplayText)
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
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
            .accessibilityLabel("Date Range filter")
            .accessibilityValue(dateRangeDisplayText)
        }
        .sheet(isPresented: $showingDateRangePicker) {
            dateRangePickerSheet
        }
    }
    
    @State private var showingDateRangePicker = false
    
    // MARK: - Project Status Multi-Select Filter
    private var projectStatusMultiSelectFilter: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
            Text("Project Status")
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            Menu {
                // "ALL Status" option
                Button {
                    HapticManager.selection()
                    if viewModel.selectedProjectStatuses.count == viewModel.projectStatusOptions.count {
                        // If all are selected, deselect all
                        viewModel.selectedProjectStatuses = []
                    } else {
                        // Select all statuses
                        viewModel.selectedProjectStatuses = Set(viewModel.projectStatusOptions)
                    }
                } label: {
                    HStack {
                        Text("ALL Status")
                        Spacer()
                        if viewModel.selectedProjectStatuses.count == viewModel.projectStatusOptions.count {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                }
                
                Divider()
                
                // Individual status options
                ForEach(viewModel.projectStatusOptions, id: \.self) { status in
                    Button {
                        HapticManager.selection()
                        if viewModel.selectedProjectStatuses.contains(status) {
                            viewModel.selectedProjectStatuses.remove(status)
                        } else {
                            viewModel.selectedProjectStatuses.insert(status)
                        }
                    } label: {
                        HStack {
                            Text(status)
                            Spacer()
                            if viewModel.selectedProjectStatuses.contains(status) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.small) {
                    Text(viewModel.selectedStatusesDisplayText)
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .symbolEffect(.bounce, value: viewModel.selectedProjectStatuses)
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
            .accessibilityLabel("Project Status filter")
            .accessibilityValue(viewModel.selectedStatusesDisplayText)
        }
    }
    
    // MARK: - Date Range Display Text
    private var dateRangeDisplayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        
        let startText = formatter.string(from: viewModel.startDate)
        let endText = formatter.string(from: viewModel.endDate)
        
        return "\(startText) - \(endText)"
    }
    
    private var dateRangePickerSheet: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker(
                        "Start Date",
                        selection: $viewModel.startDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    
                    DatePicker(
                        "End Date",
                        selection: $viewModel.endDate,
                        in: viewModel.startDate...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    
                    if viewModel.endDate < viewModel.startDate {
                        HStack(spacing: DesignSystem.Spacing.extraSmall) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("End date must be after start date")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .padding(.top, DesignSystem.Spacing.extraSmall)
                    }
                } header: {
                    Text("Select Date Range")
                } footer: {
                    Text("Choose a date range to filter the reports data")
                        .font(.caption)
                }
            }
            .navigationTitle("Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.selection()
                        showingDateRangePicker = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.selection()
                        showingDateRangePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
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
            
            // Stage Budget vs Actual - Only show if more than 1 phase
            if viewModel.stageBudgetData.count > 1 {
                chartCard(
                    title: "Stage Budget vs Actual",
                    subtitle: "₹ Cr · Budget vs Actuals"
                ) {
                    stageBudgetChart
                }
            }
            
            // Project-wise Budget vs Actual - Only show if more than 1 project
            if viewModel.projectWiseData.count > 1 {
                chartCard(
                    title: "Project-wise Budget vs Actual",
                    subtitle: "Total project budget vs total spend"
                ) {
                    projectWiseBudgetChart
                }
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
        
        return GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {

                // -----------------------------
                // FIXED Y-AXIS
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
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.quaternary)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatChartValue(v))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartPlotStyle { plot in
                    plot.frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(width: 50)

                // -----------------------------
                // SCROLLABLE CHART
                // -----------------------------
                ScrollView(.horizontal, showsIndicators: true) {

                    Chart {

                        // 1️⃣ AREA FIRST – this fixes the baseline
                        ForEach(viewModel.costTrendData, id: \.month) { data in
                            AreaMark(
                                x: .value("Month", data.month),
                                y: .value("Cost", max(data.value, 0))
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.25),
                                        Color.accentColor.opacity(0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.linear)
                        }

                        // 2️⃣ LINE ON TOP
                        ForEach(viewModel.costTrendData, id: \.month) { data in
                            LineMark(
                                x: .value("Month", data.month),
                                y: .value("Cost", max(data.value, 0))
                            )
                            .foregroundStyle(Color.accentColor)
                            .symbol(.circle)
                            .symbolSize(40)
                            .interpolationMethod(.linear)
                        }
                    }
                    .chartYAxis(.hidden)
                    .chartYScale(domain: 0...yAxisMax)
                    .chartXAxis {
                        AxisMarks() { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.quaternary)
                            AxisValueLabel()
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .chartPlotStyle { plot in
                        plot.frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .frame(
                        width: max(CGFloat(viewModel.costTrendData.count) * 60,
                                   geometry.size.width - 50),
                        height: geometry.size.height
                    )
                    .padding(.bottom, 25)
                }
            }


        }
        .frame(height: 160) // Match the chart card height
    }
    
    // Helper function to format chart axis values
    private func formatChartValue(_ value: Double) -> String {
        let absValue = abs(value)
        
        if absValue < 1000 {
            // 1 to 999: show actual numbers
            return String(format: "%.0f", value)
        } else if absValue < 100000 {
            // 1000 to 99999: show in thousands (k) with 2 decimals
            let thousands = value / 1000.0
            return String(format: "%.2fk", thousands)
        } else if absValue < 10000000 {
            // 100000 to 9999999: show in lakhs with 2 decimals
            let lakhs = value / 100000.0
            return String(format: "%.2f L", lakhs)
        } else {
            // 10000000+: show in crores (Cr) with 2 decimals
            let crores = value / 10000000.0
            return String(format: "%.2fCr", crores)
        }
    }
    
    // Stage Budget vs Actual Chart
    @State private var selectedPhaseName: String? = nil
    
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
        
        return GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // -----------------------------
                // FIXED Y-AXIS
                // -----------------------------
                Chart {
                    ForEach(viewModel.stageBudgetData, id: \.stage) { data in
                        BarMark(
                            x: .value("Stage", data.stage),
                            y: .value("Amount", max(data.budget, data.actual))
                        )
                        .foregroundStyle(.clear) // Invisible, just for axis calculation
                    }
                }
                .chartXAxis(.hidden)
                .chartYScale(domain: 0...yAxisMax, type: .linear)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.quaternary)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatChartValue(v))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartPlotStyle { plot in
                    plot.frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(width: 50)
                .frame(height: geometry.size.height)
                
                // -----------------------------
                // SCROLLABLE CHART CONTENT
                // -----------------------------
                ScrollView(.horizontal, showsIndicators: true) {
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
                        stageBudgetXAxis
                    }
                    .chartYAxis(.hidden) // Hide Y-axis in scrollable part
                    .chartYScale(domain: 0...yAxisMax, type: .linear)
                    .chartForegroundStyleScale([
                        "Budget": Color.blue,
                        "Actual": Color.green
                    ])
                    .chartLegend(position: .bottom)
                    .chartPlotStyle { plot in
                        plot.frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    // Calculate width: each bar pair needs ~80 points (40 per bar + spacing)
                    .frame(width: max(CGFloat(viewModel.stageBudgetData.count) * 80, geometry.size.width - 50))
                    .padding(.bottom, 25) // Add padding to prevent scroll indicator from covering labels
                }
                .scrollIndicators(.visible)
            }
        }
        .frame(height: 200) // Increased height to accommodate rotated labels
        .sheet(item: Binding(
            get: { selectedPhaseName.map { PhaseNameItem(name: $0) } },
            set: { selectedPhaseName = $0?.name }
        )) { item in
            phaseNameSheet(item: item)
        }
    }
    
    private var stageBudgetXAxis: some AxisContent {
        AxisMarks(values: .automatic) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(.quaternary)
            AxisValueLabel {
                if let phaseName = value.as(String.self) {
                    TruncatedPhaseNameView(
                        phaseName: phaseName,
                        onTap: {
                            selectedPhaseName = phaseName
                        }
                    )
                    .rotationEffect(.degrees(-45), anchor: .center)
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
        let maxLength: Int = 10
        
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
                if needsTruncation {
                    Text(truncatedName)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 70)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticManager.selection()
                            onTap()
                        }
                } else {
                    Text(phaseName)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 70)
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
    @State private var selectedProjectName: String? = nil
    
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
        
        return GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                // -----------------------------
                // FIXED Y-AXIS
                // -----------------------------
                Chart {
                    ForEach(viewModel.projectWiseData, id: \.project) { data in
                        BarMark(
                            x: .value("Project", data.project),
                            y: .value("Amount", max(data.budget, data.actual))
                        )
                        .foregroundStyle(.clear) // Invisible, just for axis calculation
                    }
                }
                .chartXAxis(.hidden)
                .chartYScale(domain: 0...yAxisMax, type: .linear)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.quaternary)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatChartValue(v))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartPlotStyle { plot in
                    plot.frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(width: 50)
                .frame(height: geometry.size.height)
                
                // -----------------------------
                // SCROLLABLE CHART CONTENT
                // -----------------------------
                ScrollView(.horizontal, showsIndicators: true) {
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
                        projectWiseXAxis
                    }
                    .chartYAxis(.hidden) // Hide Y-axis in scrollable part
                    .chartYScale(domain: 0...yAxisMax, type: .linear)
                    .chartForegroundStyleScale([
                        "Budget": Color.blue,
                        "Actual": Color.green
                    ])
                    .chartLegend(position: .bottom)
                    .chartPlotStyle { plot in
                        plot.frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    // Calculate width: each bar pair needs ~80 points (40 per bar + spacing)
                    .frame(width: max(CGFloat(viewModel.projectWiseData.count) * 80, geometry.size.width - 50))
                    .padding(.bottom, 25) // Add padding to prevent scroll indicator from covering labels
                }
                .scrollIndicators(.visible)
            }
        }
        .frame(height: 200) // Increased height to accommodate rotated labels
        .sheet(item: Binding(
            get: { selectedProjectName.map { ProjectNameItem(name: $0) } },
            set: { selectedProjectName = $0?.name }
        )) { item in
            projectNameSheet(item: item)
        }
    }
    
    private var projectWiseXAxis: some AxisContent {
        AxisMarks(values: .automatic) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(.quaternary)
            AxisValueLabel {
                if let projectName = value.as(String.self) {
                    TruncatedProjectNameView(
                        projectName: projectName,
                        onTap: {
                            selectedProjectName = projectName
                        }
                    )
                    .rotationEffect(.degrees(-45), anchor: .center)
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
        let maxLength: Int = 10
        
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
                if needsTruncation {
                    Text(truncatedName)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 70)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticManager.selection()
                            onTap()
                        }
                } else {
                    Text(projectName)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 70)
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
    @State private var selectedMonth: String? = nil
    
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
                AxisMarks(values: .automatic) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: true))
            .frame(height: 200)
            
            // Tooltip overlay
            if let selectedMonth = selectedMonth,
               let selectedData = viewModel.activeProjectsData.first(where: { $0.month == selectedMonth }),
               let monthIndex = viewModel.activeProjectsData.firstIndex(where: { $0.month == selectedMonth }) {
                GeometryReader { geometry in
                    let chartWidth = geometry.size.width
                    let dataCount = CGFloat(viewModel.activeProjectsData.count)
                    let xPosition = (CGFloat(monthIndex) + 0.5) * (chartWidth / dataCount)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedMonth)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            Text("Active Projects:")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("\(selectedData.count)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                    }
                    .position(
                        x: xPosition,
                        y: 10
                    )
                }
                .frame(height: 200)
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
            AxisMarks(values: .automatic) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.quaternary)
                AxisValueLabel()
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text("\(Int(doubleValue))%")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...100)
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

