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
                // Project Filter - Multi-select
                MultiSelectDropdown(
                    label: "Project",
                    displayText: viewModel.selectedProjectsDisplayText,
                    options: viewModel.projectOptions.filter { $0 != "All Projects" },
                    selectedItems: $viewModel.selectedProjects,
                    allOptionText: "All Projects"
                )
                
                // Stage Filter - Multi-select
                MultiSelectDropdown(
                    label: "Stage",
                    displayText: viewModel.selectedStagesDisplayText,
                    options: viewModel.stageOptions.filter { $0 != "All Stages" },
                    selectedItems: $viewModel.selectedStages,
                    allOptionText: "All Stages"
                )
                
                // Department Filter - Multi-select
                MultiSelectDropdown(
                    label: "Department",
                    displayText: viewModel.selectedDepartmentsDisplayText,
                    options: viewModel.departmentOptions.filter { $0 != "All Departments" },
                    selectedItems: $viewModel.selectedDepartments,
                    allOptionText: "All Departments"
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
    
    // MARK: - Multi-Select Dropdown Component
    private struct MultiSelectDropdown: View {
        let label: String
        let displayText: String
        let options: [String]
        @Binding var selectedItems: Set<String>
        let allOptionText: String
        @State private var isOpen = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                ZStack(alignment: .topLeading) {
                    // Button to toggle dropdown
                    Button {
                        HapticManager.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isOpen.toggle()
                        }
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.small) {
                            Text(displayText)
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .symbolEffect(.bounce, value: selectedItems)
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
                    .zIndex(isOpen ? 2 : 1)
                    
                    // Dropdown menu
                    if isOpen {
                        VStack(alignment: .leading, spacing: 0) {
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(alignment: .leading, spacing: 0) {
                                    // "All" option
                                    Button {
                                        HapticManager.selection()
                                        if selectedItems.count == options.count {
                                            selectedItems = []
                                        } else {
                                            selectedItems = Set(options)
                                        }
                                    } label: {
                                        HStack {
                                            Text(allOptionText)
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            if selectedItems.count == options.count {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(.blue)
                                            }
                                        }
                                        .padding(.horizontal, DesignSystem.Spacing.small + 2)
                                        .padding(.vertical, DesignSystem.Spacing.small)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Divider()
                                    
                                    // Individual options
                                    ForEach(options, id: \.self) { option in
                                        Button {
                                            HapticManager.selection()
                                            if selectedItems.contains(option) {
                                                selectedItems.remove(option)
                                            } else {
                                                selectedItems.insert(option)
                                            }
                                        } label: {
                                            HStack {
                                                Text(option)
                                                    .font(.system(size: 14, weight: .regular))
                                                    .foregroundStyle(.primary)
                                                Spacer()
                                                if selectedItems.contains(option) {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .foregroundStyle(.blue)
                                                }
                                            }
                                            .padding(.horizontal, DesignSystem.Spacing.small + 2)
                                            .padding(.vertical, DesignSystem.Spacing.small)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        
                                        if option != options.last {
                                            Divider()
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .padding(.top, 44)
                        .zIndex(3)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
            }
        }
    }
    
    // MARK: - Project Status Multi-Select Filter
    private var projectStatusMultiSelectFilter: some View {
        MultiSelectDropdown(
            label: "Project Status",
            displayText: viewModel.selectedStatusesDisplayText,
            options: viewModel.projectStatusOptions,
            selectedItems: $viewModel.selectedProjectStatuses,
            allOptionText: "ALL Status"
        )
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
            
            // Cost by Project Status
            chartCard(
                title: "Cost by Project Status",
                subtitle: "₹ Cr · Portfolio split"
            ) {
                statusCostChart
            }
            
            // Sub-Category Spend
            chartCard(
                title: "Sub-Category Spend",
                subtitle: "Filtered by Project · Department"
            ) {
                subCategorySpendChart
            }
            
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
                .frame(minHeight: 200, maxHeight: 300)
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
    @State private var selectedCostTrendMonth: String? = nil
    
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
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.quaternary)
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(formatChartValue(v))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    .chartPlotStyle { plot in
                        plot.frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .frame(width: 60)
                    .padding(.trailing, 4)

                    // -----------------------------
                    // SCROLLABLE CHART
                    // -----------------------------
                    ScrollView(.horizontal, showsIndicators: true) {
                        ZStack(alignment: .top) {
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
                                    .symbolSize(selectedCostTrendMonth == data.month ? 60 : 40)
                                    .interpolationMethod(.linear)
                                }
                                
                                // Show tooltip indicators for selected month
                                if let selectedMonth = selectedCostTrendMonth,
                                   let selectedData = viewModel.costTrendData.first(where: { $0.month == selectedMonth }) {
                                    RuleMark(x: .value("Month", selectedMonth))
                                        .foregroundStyle(Color.accentColor.opacity(0.3))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                    
                                    PointMark(
                                        x: .value("Month", selectedMonth),
                                        y: .value("Cost", max(selectedData.value, 0))
                                    )
                                    .foregroundStyle(Color.accentColor)
                                    .symbolSize(60)
                                }
                            }
                            .chartXSelection(value: $selectedCostTrendMonth)
                            .chartYAxis(.hidden)
                            .chartYScale(domain: 0...yAxisMax)
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
                            .chartPlotStyle { plot in
                                plot.frame(maxHeight: .infinity, alignment: .bottom)
                            }
                            .frame(
                                width: max(CGFloat(viewModel.costTrendData.count) * 60,
                                           geometry.size.width - 60),
                                height: geometry.size.height
                            )
                            .padding(.bottom, 35)
                            .padding(.top, 10)
                            
                            // Tooltip overlay
                            if let selectedMonth = selectedCostTrendMonth,
                               let selectedData = viewModel.costTrendData.first(where: { $0.month == selectedMonth }),
                               let monthIndex = viewModel.costTrendData.firstIndex(where: { $0.month == selectedMonth }) {
                                GeometryReader { tooltipGeometry in
                                    let chartWidth = max(CGFloat(viewModel.costTrendData.count) * 60,
                                                        geometry.size.width - 50)
                                    let dataCount = CGFloat(viewModel.costTrendData.count)
                                    let xPosition = (CGFloat(monthIndex) + 0.5) * (chartWidth / dataCount)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(selectedMonth)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        HStack(spacing: 6) {
                                            Text("Cost (₹ Cr):")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                            Text(String(format: "%.1f", selectedData.value / 10000000.0))
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
                                        y: 20
                                    )
                                }
                                .frame(
                                    width: max(CGFloat(viewModel.costTrendData.count) * 60,
                                               geometry.size.width - 60),
                                    height: geometry.size.height
                                )
                            }
                        }
                    }
                }
            }
        }
        .frame(minHeight: 200, maxHeight: 250)
        .padding(.vertical, 8)
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
    @State private var selectedStageForTooltip: String? = nil
    
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
        
        return ZStack(alignment: .top) {
            GeometryReader { geometry in
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
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.quaternary)
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(formatChartValue(v))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    .chartPlotStyle { plot in
                        plot.frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .frame(width: 60)
                    .frame(height: geometry.size.height)
                    .padding(.trailing, 4)
                    
                    // -----------------------------
                    // SCROLLABLE CHART CONTENT
                    // -----------------------------
                    ScrollView(.horizontal, showsIndicators: true) {
                        ZStack(alignment: .top) {
                            Chart {
                                ForEach(viewModel.stageBudgetData, id: \.stage) { data in
                                    BarMark(
                                        x: .value("Stage", data.stage),
                                        y: .value("Amount", data.budget)
                                    )
                                    .foregroundStyle(selectedStageForTooltip == data.stage ? Color.blue.opacity(0.8) : Color.blue)
                                    .position(by: .value("Type", "Budget"))
                                    
                                    BarMark(
                                        x: .value("Stage", data.stage),
                                        y: .value("Amount", data.actual)
                                    )
                                    .foregroundStyle(selectedStageForTooltip == data.stage ? Color.green.opacity(0.8) : Color.green)
                                    .position(by: .value("Type", "Actual"))
                                }
                                
                                // Show rule mark for selected stage
                                if let selectedStage = selectedStageForTooltip {
                                    RuleMark(x: .value("Stage", selectedStage))
                                        .foregroundStyle(Color.accentColor.opacity(0.3))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                }
                            }
                            .chartXSelection(value: $selectedStageForTooltip)
                            .chartXAxis {
                                stageBudgetXAxis
                            }
                            .chartYAxis(.hidden) // Hide Y-axis in scrollable part
                            .chartYScale(domain: 0...yAxisMax, type: .linear)
                            .chartForegroundStyleScale([
                                "Budget": Color.blue,
                                "Actual": Color.green
                            ])
                            .chartLegend(position: .bottom, alignment: .center)
                            .chartPlotStyle { plot in
                                plot.frame(maxHeight: .infinity, alignment: .bottom)
                            }
                            // Calculate width: each bar pair needs ~80 points (40 per bar + spacing)
                            .frame(width: max(CGFloat(viewModel.stageBudgetData.count) * 80, geometry.size.width - 60))
                            .padding(.bottom, 40) // Add padding to prevent scroll indicator from covering labels
                            .padding(.top, 10)
                            
                            // Tooltip overlay
                            if let selectedStage = selectedStageForTooltip,
                               let selectedData = viewModel.stageBudgetData.first(where: { $0.stage == selectedStage }),
                               let stageIndex = viewModel.stageBudgetData.firstIndex(where: { $0.stage == selectedStage }) {
                                GeometryReader { tooltipGeometry in
                                    let chartWidth = max(CGFloat(viewModel.stageBudgetData.count) * 80, geometry.size.width - 60)
                                    let dataCount = CGFloat(viewModel.stageBudgetData.count)
                                    let xPosition = (CGFloat(stageIndex) + 0.5) * (chartWidth / dataCount)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(selectedStage)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        HStack(spacing: 6) {
                                            Text("Budget (₹ Cr):")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                            Text(String(format: "%.1f", selectedData.budget / 10000000.0))
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.primary)
                                        }
                                        HStack(spacing: 6) {
                                            Text("Actual (₹ Cr):")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                            Text(String(format: "%.1f", selectedData.actual / 10000000.0))
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
                                        y: 20
                                    )
                                }
                                .frame(
                                    width: max(CGFloat(viewModel.stageBudgetData.count) * 80, geometry.size.width - 60),
                                    height: geometry.size.height
                                )
                            }
                        }
                    }
                    .scrollIndicators(.visible)
                }
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
        AxisMarks(values: .automatic(desiredCount: 10)) { value in
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
                    .font(.system(size: 11, weight: .medium))
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
    @State private var selectedProjectForTooltip: String? = nil
    
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
        
        return ZStack(alignment: .top) {
            GeometryReader { geometry in
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
                        ZStack(alignment: .top) {
                            Chart {
                                ForEach(viewModel.projectWiseData, id: \.project) { data in
                                    BarMark(
                                        x: .value("Project", data.project),
                                        y: .value("Amount", data.budget)
                                    )
                                    .foregroundStyle(selectedProjectForTooltip == data.project ? Color.blue.opacity(0.8) : Color.blue)
                                    .position(by: .value("Type", "Budget"))
                                    
                                    BarMark(
                                        x: .value("Project", data.project),
                                        y: .value("Amount", data.actual)
                                    )
                                    .foregroundStyle(selectedProjectForTooltip == data.project ? Color.green.opacity(0.8) : Color.green)
                                    .position(by: .value("Type", "Actual"))
                                }
                                
                                // Show rule mark for selected project
                                if let selectedProject = selectedProjectForTooltip {
                                    RuleMark(x: .value("Project", selectedProject))
                                        .foregroundStyle(Color.accentColor.opacity(0.3))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                }
                            }
                            .chartXSelection(value: $selectedProjectForTooltip)
                            .chartXAxis {
                                projectWiseXAxis
                            }
                            .chartYAxis(.hidden) // Hide Y-axis in scrollable part
                            .chartYScale(domain: 0...yAxisMax, type: .linear)
                            .chartForegroundStyleScale([
                                "Budget": Color.blue,
                                "Actual": Color.green
                            ])
                            .chartLegend(position: .bottom, alignment: .center)
                            .chartPlotStyle { plot in
                                plot.frame(maxHeight: .infinity, alignment: .bottom)
                            }
                            // Calculate width: each bar pair needs ~80 points (40 per bar + spacing)
                            .frame(width: max(CGFloat(viewModel.projectWiseData.count) * 80, geometry.size.width - 60))
                            .padding(.bottom, 40) // Add padding to prevent scroll indicator from covering labels
                            .padding(.top, 10)
                            
                            // Tooltip overlay
                            if let selectedProject = selectedProjectForTooltip,
                               let selectedData = viewModel.projectWiseData.first(where: { $0.project == selectedProject }),
                               let projectIndex = viewModel.projectWiseData.firstIndex(where: { $0.project == selectedProject }) {
                                GeometryReader { tooltipGeometry in
                                    let chartWidth = max(CGFloat(viewModel.projectWiseData.count) * 80, geometry.size.width - 60)
                                    let dataCount = CGFloat(viewModel.projectWiseData.count)
                                    let xPosition = (CGFloat(projectIndex) + 0.5) * (chartWidth / dataCount)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(selectedProject)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        HStack(spacing: 6) {
                                            Text("Budget (₹ Cr):")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                            Text(String(format: "%.1f", selectedData.budget / 10000000.0))
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.primary)
                                        }
                                        HStack(spacing: 6) {
                                            Text("Actual (₹ Cr):")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                            Text(String(format: "%.1f", selectedData.actual / 10000000.0))
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
                                        y: 20
                                    )
                                }
                                .frame(
                                    width: max(CGFloat(viewModel.projectWiseData.count) * 80, geometry.size.width - 60),
                                    height: geometry.size.height
                                )
                            }
                        }
                    }
                    .scrollIndicators(.visible)
                }
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
        AxisMarks(values: .automatic(desiredCount: 10)) { value in
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
                    .font(.system(size: 11, weight: .medium))
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
    @State private var selectedStageProjectForTooltip: String? = nil
    
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
                                    Text(project)
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
                    
                    // Tooltip overlay
                    if let selectedProject = selectedStageProjectForTooltip,
                       let selectedData = viewModel.stageAcrossProjectsData.first(where: { $0.project == selectedProject }),
                       let projectIndex = viewModel.stageAcrossProjectsData.firstIndex(where: { $0.project == selectedProject }) {
                        GeometryReader { geometry in
                            let chartWidth = geometry.size.width - 16 // Account for padding
                            let dataCount = CGFloat(viewModel.stageAcrossProjectsData.count)
                            let xPosition = (CGFloat(projectIndex) + 0.5) * (chartWidth / dataCount)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(selectedProject)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                HStack(spacing: 6) {
                                    Text("Budget (₹ Cr):")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.1f", selectedData.budget / 10000000.0))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                                HStack(spacing: 6) {
                                    Text("Actual (₹ Cr):")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.1f", selectedData.actual / 10000000.0))
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
                                y: 20
                            )
                        }
                        .frame(minHeight: 200, maxHeight: 300)
                    }
                }
            }
        }
    }
    
    // Sub-Category Spend Chart
    @State private var selectedSpendCategory: String? = nil
    
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
            
            // Tooltip overlay
            if let selectedCategory = selectedSpendCategory,
               let selectedData = viewModel.subCategorySpendData.first(where: { $0.category == selectedCategory }),
               let categoryIndex = viewModel.subCategorySpendData.firstIndex(where: { $0.category == selectedCategory }) {
                GeometryReader { geometry in
                    let barHeight = 50.0
                    let yPosition = (CGFloat(categoryIndex) * barHeight) + (barHeight / 2) + 20
                    
                    // Calculate x position based on the bar's end (spend value)
                    // We need to estimate the bar width based on the spend relative to max spend
                    let maxSpend = viewModel.subCategorySpendData.map { $0.value }.max() ?? 1
                    let barWidthRatio = Double(selectedData.value) / Double(maxSpend)
                    let estimatedBarEndX = geometry.size.width * 0.7 * barWidthRatio + 50 // Approximate chart area width
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedCategory)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            Text("Spend (₹ Cr):")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f", selectedData.value / 10000000.0))
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
                        x: min(estimatedBarEndX + 70, geometry.size.width - 80),
                        y: yPosition
                    )
                }
                .frame(minHeight: CGFloat(max(viewModel.subCategorySpendData.count, 3)) * 50 + 60)
            }
        }
    }
    
    // Status Cost Chart
    @State private var selectedStatusForTooltip: String? = nil
    
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
            Chart {
                ForEach(viewModel.statusCostData, id: \.status) { data in
                    BarMark(
                        x: .value("Status", data.status),
                        y: .value("Cost", data.value)
                    )
                    .foregroundStyle(selectedStatusForTooltip == data.status ? Color.orange.opacity(0.8) : Color.orange)
                }
                
                // Show rule mark for selected status
                if let selectedStatus = selectedStatusForTooltip {
                    RuleMark(x: .value("Status", selectedStatus))
                        .foregroundStyle(Color.accentColor.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
            .chartXSelection(value: $selectedStatusForTooltip)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let status = value.as(String.self) {
                            Text(status)
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
                        if let doubleValue = value.as(Double.self) {
                            Text(formatChartValue(doubleValue))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...yAxisMax, type: .linear)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(minHeight: 200, maxHeight: 300)
            
            // Tooltip overlay
            if let selectedStatus = selectedStatusForTooltip,
               let selectedData = viewModel.statusCostData.first(where: { $0.status == selectedStatus }),
               let statusIndex = viewModel.statusCostData.firstIndex(where: { $0.status == selectedStatus }) {
                GeometryReader { geometry in
                    let chartWidth = geometry.size.width - 16 // Account for padding
                    let dataCount = CGFloat(viewModel.statusCostData.count)
                    let xPosition = (CGFloat(statusIndex) + 0.5) * (chartWidth / dataCount)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            // Orange square indicator
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.orange)
                                .frame(width: 12, height: 12)
                            
                            Text(selectedStatus)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        HStack(spacing: 6) {
                            Text("Cost (₹ Cr):")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f", selectedData.value / 10000000.0))
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
                        y: 20
                    )
                }
                .frame(minHeight: 200, maxHeight: 300)
            }
        }
    }
    
    // Overrun Scatter Chart
    @State private var selectedOverrunStage: String? = nil
    
    private var overrunScatterChart: some View {
        ZStack(alignment: .top) {
            Chart {
                ForEach(viewModel.overrunData, id: \.stage) { data in
                    PointMark(
                        x: .value("Progress", data.progress),
                        y: .value("Overrun", data.overrun)
                    )
                    .foregroundStyle(
                        selectedOverrunStage == data.stage
                        ? Color.red.opacity(0.8)
                        : Color.red
                    )
                    .symbolSize(
                        selectedOverrunStage == data.stage
                        ? 80
                        : 60
                    )
                }
                
                // Show rule marks for selected point
                if let selectedStage = selectedOverrunStage,
                   let selectedData = viewModel.overrunData.first(where: { $0.stage == selectedStage }) {
                    RuleMark(x: .value("Progress", selectedData.progress))
                        .foregroundStyle(Color.accentColor.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    
                    RuleMark(y: .value("Overrun", selectedData.overrun))
                        .foregroundStyle(Color.accentColor.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
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
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let progress = value.as(Double.self) {
                            Text("\(Int(progress))%")
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
                        if let overrun = value.as(Double.self) {
                            Text("\(Int(overrun))%")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .chartXAxisLabel("Stage Progress (%)")
                .font(.system(size: 12, weight: .medium))
            .chartYAxisLabel("Cost Overrun (%)")
                .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(minHeight: 200, maxHeight: 300)
            
            // Tooltip overlay
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
                    
                    // Calculate position
                    let xRatio = (selectedData.progress - minProgress) / progressRangeSize
                    let yRatio = (selectedData.overrun - minOverrun) / overrunRangeSize
                    
                    let xPosition = chartPadding + (xRatio * chartWidth)
                    let yPosition = chartPadding + ((1 - yRatio) * chartHeight) // Invert Y for screen coordinates
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            // Red square indicator
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                            
                            Text("Stage: \(selectedData.stage) · Progress: \(Int(selectedData.progress))% · Overrun: \(Int(selectedData.overrun))%")
                                .font(.system(size: 13, weight: .semibold))
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
                        x: min(max(xPosition, 80), geometry.size.width - 80),
                        y: max(min(yPosition - 60, geometry.size.height - 80), 60)
                    )
                }
                .frame(minHeight: 200, maxHeight: 300)
            }
        }
    }
    
    // Burn Rate Chart
    @State private var selectedBurnRateProject: String? = nil
    
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
        
        // Calculate X-axis max value
        let maxRate = viewModel.burnRateData.map { $0.rate }.max() ?? 0
        let xAxisMax: Double
        if maxRate == 0 {
            xAxisMax = 1.0 // Small default when all values are 0
        } else {
            // Add 10% padding
            let padding = max(maxRate * 0.1, 0.1)
            xAxisMax = maxRate + padding
        }
        
        return AnyView(ZStack(alignment: .topLeading) {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 0) {
                    // -----------------------------
                    // SCROLLABLE CHART CONTENT (with Y-axis)
                    // -----------------------------
                    ScrollView(.vertical, showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            Chart {
                                ForEach(viewModel.burnRateData, id: \.project) { data in
                                    BarMark(
                                        x: .value("Rate", data.rate),
                                        y: .value("Project", data.project)
                                    )
                                    .foregroundStyle(selectedBurnRateProject == data.project ? Color.green.opacity(0.8) : Color.green)
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
                                AxisMarks(position: .leading, values: .automatic(desiredCount: 10)) { value in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                        .foregroundStyle(.quaternary)
                                    AxisValueLabel {
                                        if let project = value.as(String.self) {
                                            Text(project)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }
                            }
                            .chartPlotStyle { plot in
                                plot.frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(
                                width: geometry.size.width,
                                height: CGFloat(max(viewModel.burnRateData.count, 3)) * 50 + 40
                            )
                            .padding(.bottom, 40)
                            .padding(.top, 10)
                            
                            // Tooltip overlay
                            if let selectedProject = selectedBurnRateProject,
                               let selectedData = viewModel.burnRateData.first(where: { $0.project == selectedProject }),
                               let projectIndex = viewModel.burnRateData.firstIndex(where: { $0.project == selectedProject }) {
                                GeometryReader { tooltipGeometry in
                                    let barHeight = 50.0
                                    let yPosition = (CGFloat(projectIndex) * barHeight) + (barHeight / 2) + 20
                                    
                                    // Calculate x position based on the bar's end (rate value)
                                    let maxRate = viewModel.burnRateData.map { $0.rate }.max() ?? 1
                                    let barWidthRatio = Double(selectedData.rate) / Double(maxRate)
                                    let estimatedBarEndX = tooltipGeometry.size.width * 0.7 * barWidthRatio + 50
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(selectedProject)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        HStack(spacing: 6) {
                                            Text("Spent (last 30 days):")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                            Text(formatAmount(selectedData.totalSpend))
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
                                        x: min(estimatedBarEndX + 70, tooltipGeometry.size.width - 80),
                                        y: yPosition
                                    )
                                }
                                .frame(
                                    width: geometry.size.width,
                                    height: CGFloat(max(viewModel.burnRateData.count, 3)) * 50 + 40
                                )
                            }
                        }
                    }
                    .scrollIndicators(.visible)
                    
                    // -----------------------------
                    // FIXED X-AXIS (at bottom)
                    // -----------------------------
                    Chart {
                        ForEach(viewModel.burnRateData, id: \.project) { data in
                            BarMark(
                                x: .value("Rate", data.rate),
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
                                .foregroundStyle(.quaternary)
                            AxisValueLabel {
                                if let rate = value.as(Double.self) {
                                    Text(String(format: "%.2f", rate))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    .chartPlotStyle { plot in
                        plot.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 40)
                    .padding(.top, 4)
                }
            }
        }
        .frame(minHeight: 200, maxHeight: 300))
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
                        y: 20
                    )
                }
                .frame(minHeight: 220, maxHeight: 250)
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
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let stage = value.as(String.self) {
                        Text(stage)
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
                    if let doubleValue = value.as(Double.self) {
                        Text("\(Int(doubleValue))%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...100)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .chartForegroundStyleScale([
            "In Progress": Color.blue,
            "Handover": Color.yellow,
            "Delayed": Color.orange,
            "Complete": Color.gray
        ])
        .chartLegend(position: .bottom)
    }
    
    // Sub-Category Activity Chart
    @State private var selectedCategory: String? = nil
    
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
            
            // Tooltip overlay
            if let selectedCategory = selectedCategory,
               let selectedData = viewModel.subCategoryActivityData.first(where: { $0.category == selectedCategory }),
               let categoryIndex = viewModel.subCategoryActivityData.firstIndex(where: { $0.category == selectedCategory }) {
                GeometryReader { geometry in
                    let barHeight = 50.0
                    let yPosition = (CGFloat(categoryIndex) * barHeight) + (barHeight / 2) + 20
                    
                    // Calculate x position based on the bar's end (count value)
                    // We need to estimate the bar width based on the count relative to max count
                    let maxCount = viewModel.subCategoryActivityData.map { $0.count }.max() ?? 1
                    let barWidthRatio = Double(selectedData.count) / Double(maxCount)
                    let estimatedBarEndX = geometry.size.width * 0.7 * barWidthRatio + 50 // Approximate chart area width
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedCategory)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            Text("Expenses:")
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
                        x: min(estimatedBarEndX + 70, geometry.size.width - 80),
                        y: yPosition
                    )
                }
                .frame(minHeight: CGFloat(max(viewModel.subCategoryActivityData.count, 3)) * 50 + 60)
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
            AxisMarks(position: .bottom, values: .automatic(desiredCount: 6)) { value in
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
                        Text(String(format: "%.1f", cost))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .chartXAxisLabel("Delay Days")
            .font(.system(size: 12, weight: .medium))
        .chartYAxisLabel("Extra Cost (₹ Cr)")
            .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
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
    
    // Helper function to format currency with appropriate units
    private func formatAmount(_ value: Double) -> String {
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
}


// MARK: - Preview
#Preview {
    MainReportView()
}

