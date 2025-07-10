//
//  ReportView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 7/10/25.
//

import SwiftUI

struct ReportView: View {
    @StateObject private var viewModel = ReportViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChartView = ChartView.bar
    var projectId : String?
    
    private enum ChartView {
        case bar
        case business
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.large) {
                    // Header Section
                    headerSection
                    
                    // Filters Section
                    filtersSection
                    
                    // Export Buttons Section
                    exportButtonsSection
                    
                    // Chart Section
                    chartSection
                    
                    // Department Budget Summary Section
                    departmentBudgetSummarySection
                }
                .padding()
                .onAppear{
                    if let projectId = projectId{
                        viewModel.fetchDepartmentNames(from: projectId)
                    }
                }
                .onChange(of: viewModel.selectedDepartment) {
                    Task{
                        if let projectId = projectId{
                            await viewModel.loadApprovedExpenses(projectId: projectId)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticManager.selection()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("REPORTS OVERVIEW")
                    .font(.title2.weight(.bold))
            }
            Text("Track and analyze your project expenses")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Filters Section
    private var filtersSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack {
                filterMenu(
                    title: "Date Range",
                    icon: "calendar",
                    selection: $viewModel.selectedDateRange,
                    options: ReportViewModel.DateRange.allCases
                )
                
                filterMenu(
                    title: "Department",
                    icon: "folder",
                    selection: $viewModel.selectedDepartment,
                    options: viewModel.departmentNames
                )
            }
        }
    }
    
    private func filterMenu<T: Hashable>(
        title: String,
        icon: String,
        selection: Binding<T>,
        options: [T]
    ) -> some View where T: CustomStringConvertible {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    HapticManager.selection()
                    selection.wrappedValue = option
                } label: {
                    HStack {
                        Text(option.description)
                        if option == selection.wrappedValue {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Image(systemName: icon)
                    Text(selection.wrappedValue.description)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }
    
    // MARK: - Export Buttons Section
    private var exportButtonsSection: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            exportButton(title: "Export to PDF", icon: "doc.fill", action: viewModel.exportToPDF)
            exportButton(title: "Export to Excel", icon: "tablecells.fill", action: viewModel.exportToExcel)
        }
    }
    
    private func exportButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.selection()
            action()
        }) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }
    
    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Expense Categories")
                .font(.title3.weight(.semibold))
            
            // Toggle between Bar and Business views
            HStack(spacing: 0) {
                segmentButton(title: "Bar", isSelected: selectedChartView == .bar) {
                    selectedChartView = .bar
                }
                segmentButton(title: "Business", isSelected: selectedChartView == .business) {
                    selectedChartView = .business
                }
            }
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            
            if viewModel.expenseCategories.isEmpty {
                Text("No expenses found for the selected period")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: DesignSystem.Spacing.medium) {
                        ForEach(viewModel.expenseCategories, id: \.name) { category in
                            VStack {
                                Text(category.formattedAmount)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 30, height: calculateBarHeight(for: category))
                                
                                Text(category.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                                    .rotationEffect(.degrees(-45))
                                    .offset(y: 10)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(radius: 2, y: 2)
    }
    
    private func calculateBarHeight(for category: ExpenseCategory) -> CGFloat {
        let maxAmount = viewModel.expenseCategories.map(\.amount).max() ?? 1
        let ratio = category.amount / maxAmount
        return max(50 * ratio, 20) // Minimum height of 20, maximum of 200
    }
    
    // MARK: - Department Budget Summary Section
    private var departmentBudgetSummarySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Department Budget Summary")
                .font(.headline)
            
            ForEach(viewModel.filteredDepartmentBudgets, id: \.department) { budget in
                VStack(spacing: DesignSystem.Spacing.small) {
                    HStack {
                        Text(budget.department)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("₹\(Int(budget.totalBudget).formatted())")
                            .font(.subheadline)
                    }
                    
                    GeometryReader { geometry in
                        let width = geometry.size.width * (budget.approvedBudget / budget.totalBudget)
                        
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .fill(Color(.systemGray5))
                            
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .fill(budget.color)
                                .frame(width: width)
                        }
                    }
                    .frame(height: 8)
                    
                    HStack {
                        Text("Spent: ₹\(Int(budget.approvedBudget).formatted())")
                        Spacer()
                        Text("Remaining: ₹\(Int(budget.totalBudget - budget.approvedBudget).formatted())")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }
        }
    }
    
    private func segmentButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .blue : .secondary)
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.small)
                .background(isSelected ? Color.blue.opacity(0.1) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
        }
    }
}

#Preview {
    ReportView(projectId: "I1kHn5UTOs6FCBA33Ke5")
}
