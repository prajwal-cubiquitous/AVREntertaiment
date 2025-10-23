//
//  ReportView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 7/10/25.
//

import SwiftUI
import Combine

@available(iOS 14.0, *)
struct ReportView: View {
    @StateObject private var viewModel = ReportViewModel()
    @Environment(\.compatibleDismiss) private var dismiss
    var projectId : String?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Scrollable Content
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.large) {
                        // Filters Section
                        filtersSection
                        
                        // Chart Section
                        chartSection
                        
                        // Department Budget Summary Section
                        departmentBudgetSummarySection
                    }
                    .padding(.horizontal)
                    .padding(.top, DesignSystem.Spacing.small)
                    .padding(.bottom, 100) // Add bottom padding to avoid floating buttons
                    .onAppear {
                        if let projectId = projectId {
                            viewModel.fetchDepartmentNames(from: projectId)
                            Task {
                                await viewModel.loadApprovedExpenses(projectId: projectId)
                                await viewModel.loadDepartmentBudgets(projectId: projectId)
                            }
                        }
                    }
                    .onReceive(Just(viewModel.selectedDepartment)) { _ in
                        Task {
                            if let projectId = projectId {
                                await viewModel.loadApprovedExpenses(projectId: projectId)
                            }
                        }
                    }
                }
                
                // Floating Export Buttons
                VStack {
                    Spacer()
                    floatingExportButtons
                }
            }
            // .navigationBarTitleDisplayMode(.inline) // iOS 14+ only
            .navigationBarTitle("Reports", displayMode: .inline)
            .navigationBarItems(leading: Button {
                HapticManager.selection()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.secondary)
            })
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Filters Section
    private var filtersSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack {
                Text("Filters")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Color.primary)
                
                Spacer()
                
                Button("Reset") {
                    HapticManager.selection()
                    viewModel.selectedDateRange = .thisMonth
                    viewModel.selectedDepartment = "All"
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.blue)
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
                    .foregroundColor(Color.primary)
                
                Spacer()
                
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            if viewModel.expenseCategories.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundColor(Color.secondary)
                    
                    Text("No Expenses Found")
                        .font(.headline)
                        .foregroundColor(Color.primary)
                    
                    Text("No expenses found for the selected period and filters")
                        .font(.subheadline)
                        .foregroundColor(Color.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
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
                    .foregroundColor(Color.primary)
                
                Spacer()
                
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.purple)
            }
            
            if viewModel.departmentBudgets.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "building.2")
                        .font(.system(size: 40))
                        .foregroundColor(Color.secondary)
                    
                    Text("No Department Data")
                        .font(.headline)
                        .foregroundColor(Color.primary)
                    
                    Text("Department budgets will appear here once data is loaded")
                        .font(.subheadline)
                        .foregroundColor(Color.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    // Table Header
                    HStack {
                        Text("Department")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Budget")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        Text("Spent")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        Text("Remaining")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color.secondary)
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
    
    // MARK: - Floating Export Buttons
    private var floatingExportButtons: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            ExportButton(
                title: "Export PDF",
                icon: "doc.fill",
                color: .red,
                action: exportPDFWithDismiss
            )
            
            ExportButton(
                title: "Export Excel",
                icon: "tablecells.fill",
                color: .green,
                action: exportExcelWithDismiss
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.bottom, DesignSystem.Spacing.medium)
    }
    
    func exportPDFWithDismiss() {
        dismiss() // Dismiss SwiftUI sheet

        // ✅ Wait for sheet animation to finish before presenting share sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            viewModel.exportToPDF()        }
    }
    
    func exportExcelWithDismiss() {
        dismiss() // Dismiss SwiftUI sheet

        // ✅ Wait for sheet animation to finish before presenting share sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            viewModel.exportToExcel()
        }
    }
}

// MARK: - Supporting Views

struct FilterCard<T: Hashable>: View where T: CustomStringConvertible {
    let title: String
    @Binding var selection: T
    let options: [T]
    let icon: String
    
    var body: some View {
        if #available(iOS 14.0, *) {
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
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundColor(Color.secondary)
                    
                    HStack {
                        Image(systemName: icon)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Text(selection.description)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(Color.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(Color.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            }
        } else {
            // Fallback for iOS 13
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color.secondary)
                
                HStack {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Text(selection.description)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Color.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(Color.gray)
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
                .foregroundColor(Color.secondary)
            
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
                .foregroundColor(Color.primary)
                .fixedSize()
                .rotationEffect(.degrees(-45))
                .offset(y: 15)
        }
        .frame(minWidth: 60)
    }
}

@available(iOS 14.0, *)
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
    
    // Special handling for "Other Expenses" - show spent amount as positive
    private var displayAmount: Double {
        if budget.department == "Other Expenses" {
            return budget.approvedBudget // Show spent amount as positive
        } else {
            return remainingAmount
        }
    }
    
    private var displayColor: Color {
        if budget.department == "Other Expenses" {
            return .green // Always green for Other Expenses
        } else {
            return remainingAmount < 0 ? .red : .green
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(budget.department)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("₹\(Int(budget.totalBudget).formattedWithSeparator())")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                Text("₹\(Int(budget.approvedBudget).formattedWithSeparator())")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(spentPercentage > 0.8 ? .orange : .primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                Text("₹\(Int(displayAmount).formattedWithSeparator())")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(displayColor)
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

@available(iOS 14.0, *)
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
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(LinearGradient(gradient: Gradient(colors: [color, color.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}



#Preview {
    ReportView(projectId: "I1kHn5UTOs6FCBA33Ke5")
}
