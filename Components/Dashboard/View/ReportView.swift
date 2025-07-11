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
    var projectId : String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.large) {
                    // Hero Section
                    heroSection
                    
                    // Quick Stats Cards
                    quickStatsSection
                    
                    // Filters Section
                    filtersSection
                    
                    // Chart Section
                    chartSection
                    
                    // Department Budget Summary Section
                    departmentBudgetSummarySection
                    
                    // Export Section
                    exportSection
                }
                .padding(.horizontal)
                .padding(.top, DesignSystem.Spacing.small)
                .onAppear {
                    if let projectId = projectId {
                        viewModel.fetchDepartmentNames(from: projectId)
                        Task {
                            await viewModel.loadApprovedExpenses(projectId: projectId)
                            await viewModel.loadDepartmentBudgets(projectId: projectId)
                        }
                    }
                }
                .onChange(of: viewModel.selectedDepartment) {
                    Task {
                        if let projectId = projectId {
                            await viewModel.loadApprovedExpenses(projectId: projectId)
                        }
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
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Reports")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Icon and Title
            VStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue.gradient)
                    .symbolEffect(.pulse.wholeSymbol)
                
                Text("Analytics Overview")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text("Track and analyze your project expenses with detailed insights")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.large)
    }
    
    // MARK: - Quick Stats Section
    private var quickStatsSection: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            StatCard(
                title: "Total Expenses",
                value: "₹\(Int(viewModel.filteredExpenses.reduce(0) { $0 + $1.amount }).formatted())",
                icon: "indianrupeesign.circle.fill",
                color: .blue
            )
            
            StatCard(
                title: "Categories",
                value: "\(viewModel.expenseCategories.count)",
                icon: "folder.fill",
                color: .green
            )
            
            StatCard(
                title: "Period",
                value: viewModel.selectedDateRange.description,
                icon: "calendar.circle.fill",
                color: .orange
            )
        }
    }
    
    // MARK: - Filters Section
    private var filtersSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack {
                Text("Filters")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button("Reset") {
                    HapticManager.selection()
                    viewModel.selectedDateRange = .thisMonth
                    viewModel.selectedDepartment = "All"
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.blue)
            }
            
            HStack(spacing: DesignSystem.Spacing.medium) {
                FilterCard(
                    title: "Date Range",
                    selection: $viewModel.selectedDateRange,
                    options: ReportViewModel.DateRange.allCases,
                    icon: "calendar"
                )
                
                FilterCard(
                    title: "Department",
                    selection: $viewModel.selectedDepartment,
                    options: viewModel.departmentNames,
                    icon: "building.2"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Text("Expense Categories")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .foregroundStyle(.blue.gradient)
            }
            
            if viewModel.expenseCategories.isEmpty {
                EmptyStateView(
                    icon: "chart.bar.xaxis",
                    title: "No Expenses Found",
                    subtitle: "No expenses found for the selected period and filters"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: DesignSystem.Spacing.medium) {
                        ForEach(viewModel.expenseCategories, id: \.name) { category in
                            ChartBar(category: category, maxAmount: viewModel.expenseCategories.map(\.amount).max() ?? 1)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 50)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Department Budget Summary Section
    private var departmentBudgetSummarySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack {
                Text("Department Budget Summary")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "building.columns.fill")
                    .font(.title3)
                    .foregroundStyle(.purple.gradient)
            }
            
            if viewModel.departmentBudgets.isEmpty {
                EmptyStateView(
                    icon: "building.2",
                    title: "No Department Data",
                    subtitle: "Department budgets will appear here once data is loaded"
                )
            } else {
                VStack(spacing: 0) {
                    // Table Header
                    HStack {
                        Text("Department")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Budget")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        Text("Spent")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        Text("Remaining")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, DesignSystem.Spacing.small)
                    .background(Color(.quaternarySystemFill))
                    
                    // Table Rows
                    ForEach(Array(viewModel.departmentBudgets.enumerated()), id: \.element.department) { index, budget in
                        BudgetRow(budget: budget, isLast: index == viewModel.departmentBudgets.count - 1)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Export Section
    private var exportSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack {
                Text("Export Options")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.title3)
                    .foregroundStyle(.green.gradient)
            }
            
            HStack(spacing: DesignSystem.Spacing.medium) {
                ExportButton(
                    title: "Export PDF",
                    icon: "doc.fill",
                    color: .red,
                    action: viewModel.exportToPDF
                )
                
                ExportButton(
                    title: "Export Excel",
                    icon: "tablecells.fill",
                    color: .green,
                    action: viewModel.exportToExcel
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.bottom, DesignSystem.Spacing.large)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color.gradient)
            
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

struct FilterCard<T: Hashable>: View where T: CustomStringConvertible {
    let title: String
    @Binding var selection: T
    let options: [T]
    let icon: String
    
    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    HapticManager.selection()
                    selection = option
                } label: {
                    HStack {
                        Text(option.description)
                        if option == selection {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    
                    Text(selection.description)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }
}

struct ChartBar: View {
    let category: ExpenseCategory
    let maxAmount: Double
    
    private var barHeight: CGFloat {
        let ratio = category.amount / maxAmount
        return max(ratio * 150, 20)
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            Text(category.formattedAmount)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(LinearGradient(
                    colors: [.blue.opacity(0.8), .blue.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 40, height: barHeight)
                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
            
            Text(category.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize()
                .rotationEffect(.degrees(-45))
                .offset(y: 15)
        }
        .frame(minWidth: 60)
    }
}

struct BudgetRow: View {
    let budget: DepartmentBudget
    let isLast: Bool
    
    private var remainingAmount: Double {
        budget.totalBudget - budget.approvedBudget
    }
    
    private var spentPercentage: Double {
        guard budget.totalBudget > 0 else { return 0 }
        return budget.approvedBudget / budget.totalBudget
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(budget.department)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("₹\(Int(budget.totalBudget).formatted())")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                Text("₹\(Int(budget.approvedBudget).formatted())")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(spentPercentage > 0.8 ? .orange : .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                Text("₹\(Int(remainingAmount).formatted())")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(remainingAmount < 0 ? .red : .green)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, DesignSystem.Spacing.medium)
            .background(Color(.systemBackground))
            
            if !isLast {
                Divider()
                    .padding(.horizontal)
            }
        }
    }
}

struct ExportButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.selection()
            action()
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.6))
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: DesignSystem.Spacing.small) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.extraLarge)
    }
}

#Preview {
    ReportView(projectId: "I1kHn5UTOs6FCBA33Ke5")
}
