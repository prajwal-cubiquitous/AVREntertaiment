//
//  MainReportView.swift
//  AVREntertainment
//
//  Created by Auto on 1/1/25.
//

import SwiftUI
import Charts
import Accessibility
import FirebaseFirestore

struct MainReportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MainReportViewModel()
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var selectedTab: ReportTab = .cost
    @State private var businessName: String = "Portfolio Insights"
    @Binding var searchTextBinding: String
    @State private var isViewModelReady: Bool = false
    
    enum ReportTab: String, CaseIterable {
        case cost = "Cost Insights"
        case project = "Project Insights"
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
                                        CostInsightsView(
                                            viewModel: viewModel,
                                            expandedChartId: $expandedChartId,
                                            isViewModelReady: isViewModelReady
                                        )
                                        .transition(.opacity)
                                    } else {
                                        ProjectInsightsView(
                                            viewModel: viewModel,
                                            expandedChartId: $expandedChartId,
                                            searchTextBinding: $searchTextBinding,
                                            isViewModelReady: isViewModelReady,
                                            dismissReports: { dismiss() }
                                        )
                                        .transition(.opacity)
                                    }
                                }
                                .animation(.easeInOut(duration: 0.2), value: selectedTab)
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
            await loadBusinessName()
            // Mark viewModel as ready after data is loaded
            isViewModelReady = true
        }
        .onAppear {
            // Additional safety: ensure we're on main thread
            if !isViewModelReady && !viewModel.isLoading {
                isViewModelReady = true
            }
        }
    }
    
    // MARK: - Helper Functions
    /// Safely check if cost trend data is available
    private var hasCostTrendData: Bool {
        guard isViewModelReady && !viewModel.isLoading else { return false }
        // Safely access the array count
        return viewModel.costTrendData.count > 0
    }
    
    /// Safely get cost trend data count for ID generation
    private var costTrendDataCount: Int {
        guard isViewModelReady && !viewModel.isLoading else { return 0 }
        return viewModel.costTrendData.count
    }
    
    /// Safely check if active projects data is available
    private var hasActiveProjectsData: Bool {
        guard isViewModelReady && !viewModel.isLoading else { return false }
        // Safely access the array count
        return viewModel.activeProjectsData.count > 0
    }
    
    /// Safely get active projects data count for ID generation
    private var activeProjectsDataCount: Int {
        guard isViewModelReady && !viewModel.isLoading else { return 0 }
        return viewModel.activeProjectsData.count
    }
    
    // MARK: - Load Business Name
    private func loadBusinessName() async {
        guard let customerId = authService.currentCustomerId else {
            await MainActor.run {
                businessName = "Portfolio Insights"
            }
            return
        }
        
        do {
            let customerDoc = try await Firestore.firestore()
                .collection("customers")
                .document(customerId)
                .getDocument()
            
            if customerDoc.exists,
               let customer = try? customerDoc.data(as: Customer.self) {
                await MainActor.run {
                    businessName = customer.businessName.isEmpty ? "Portfolio Insights" : customer.businessName
                }
            } else {
                await MainActor.run {
                    businessName = "Portfolio Insights"
                }
            }
        } catch {
            Swift.print("Error loading business name: \(error.localizedDescription)")
            await MainActor.run {
                businessName = "Portfolio Insights"
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            // Business Name Header - Following Apple Design Guidelines
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dashboard & Reports")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    
                   Text(businessName)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
            
            // Segmented Control Style Tabs - Apple Design Pattern
            HStack(spacing: 8) {
                ForEach(ReportTab.allCases, id: \.self) { tab in
                    Button {
                        HapticManager.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(selectedTab == tab ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selectedTab == tab ? Color.primary : Color(.systemGray6))
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.rawValue)
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background {
            // Subtle background with proper material
            Rectangle()
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 1)
        }
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
                .foregroundStyle(.primary)
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
                        .foregroundStyle(isDateRangeCustom ? .blue : .primary)
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
        
        // Check if a specific filter is selected (not "All")
        private var isSpecificFilterSelected: Bool {
            // Check if display text is different from "All" option (case-insensitive)
            let displayLower = displayText.lowercased()
            let allOptionLower = allOptionText.lowercased()
            
            // Return true if display text doesn't match "All" option and doesn't contain "All"
            return displayText != allOptionText && 
                   !displayLower.contains("all") &&
                   !displayLower.contains("no status")
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(.primary)
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
                                .foregroundStyle(isSpecificFilterSelected ? .blue : .primary)
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
            allOptionText: "All Status"
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
    
    // Check if date range is custom (not default 6 months)
    private var isDateRangeCustom: Bool {
        let calendar = Calendar.current
        let defaultStartDate = calendar.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let defaultEndDate = Date()
        
        // Compare dates ignoring time
        let currentStart = calendar.startOfDay(for: viewModel.startDate)
        let currentEnd = calendar.startOfDay(for: viewModel.endDate)
        let defaultStart = calendar.startOfDay(for: defaultStartDate)
        let defaultEnd = calendar.startOfDay(for: defaultEndDate)
        
        return currentStart != defaultStart || currentEnd != defaultEnd
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
            kpiCard(label: "Total Approved", value: viewModel.totalSpentFormatted)
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
                .foregroundColor({
                    switch label {
                    case "Total Approved":
                        return .blue
                    case "Remaining":
                        return .green
                    default:
                        return .primary
                    }
                }())

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
    
    // MARK: - Chart Card Helper with Full-Screen Support
    @State private var expandedChartId: String? = nil
}


// MARK: - Preview
#Preview {
    MainReportView(searchTextBinding: .constant(""))
}
