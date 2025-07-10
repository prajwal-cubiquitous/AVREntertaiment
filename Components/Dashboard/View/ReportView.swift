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
                    
                    // Bar Chart Section
                    barChartSection
                    
                    // Department Budget Summary Table
                    departmentBudgetTableSection
                }
                .padding(DesignSystem.Spacing.medium)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reports Overview")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
        .onAppear {
            viewModel.loadReportData()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("REPORTS OVERVIEW")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Success checkmark
                Image(systemName: "checkmark.square.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .cardStyle()
    }
    
    // MARK: - Filters Section
    private var filtersSection: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            HStack(spacing: DesignSystem.Spacing.medium) {
                // Date Range Filter
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Date Range")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(ReportViewModel.DateRange.allCases, id: \.self) { range in
                            Button {
                                viewModel.selectedDateRange = range
                                HapticManager.selection()
                            } label: {
                                HStack {
                                    Text(range.rawValue)
                                    if viewModel.selectedDateRange == range {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(viewModel.selectedDateRange.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(DesignSystem.Spacing.medium)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                }
                
                // Department Filter
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text("Department")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(viewModel.availableDepartments, id: \.self) { department in
                            Button {
                                viewModel.selectedDepartment = department
                                HapticManager.selection()
                            } label: {
                                HStack {
                                    Text(department)
                                    if viewModel.selectedDepartment == department {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(viewModel.selectedDepartment)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(DesignSystem.Spacing.medium)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .cardStyle()
    }
    
    // MARK: - Export Buttons Section
    private var exportButtonsSection: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            // Export PDF Button
            Button {
                HapticManager.impact(.medium)
                viewModel.exportToPDF()
            } label: {
                HStack {
                    Image(systemName: "doc.fill")
                        .font(.headline)
                    Text("Export PDF")
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.medium)
                .background(Color.blue)
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            
            // Export Excel Button
            Button {
                HapticManager.impact(.medium)
                viewModel.exportToExcel()
            } label: {
                HStack {
                    Image(systemName: "tablecells.fill")
                        .font(.headline)
                    Text("Export Excel")
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.medium)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .cardStyle()
    }
    
    // MARK: - Bar Chart Section
    private var barChartSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Toggle between Bar and Business views
            HStack {
                Button("Bar") {
                    HapticManager.selection()
                }
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.small)
                .background(Color(.tertiarySystemFill))
                .cornerRadius(DesignSystem.CornerRadius.small)
                
                Button("Byusess") {
                    HapticManager.selection()
                }
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.small)
                
                Spacer()
            }
            
            // Bar Chart
            if !viewModel.expenseCategories.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    // Y-axis labels and bars
                    HStack(alignment: .bottom, spacing: DesignSystem.Spacing.small) {
                        // Y-axis
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("400")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                                .frame(height: 40)
                            
                            Text("200")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                                .frame(height: 40)
                            
                            Text("0")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 30)
                        
                        // Bars
                        HStack(alignment: .bottom, spacing: DesignSystem.Spacing.medium) {
                            ForEach(Array(viewModel.expenseCategories.prefix(3).enumerated()), id: \.offset) { index, category in
                                VStack(spacing: DesignSystem.Spacing.small) {
                                    // Bar
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue)
                                        .frame(
                                            width: 60,
                                            height: max(20, CGFloat(category.amount / 10000) * 80) // Scale based on amount
                                        )
                                        .animation(.easeInOut(duration: 0.8).delay(Double(index) * 0.1), value: category.amount)
                                    
                                    // Label
                                    Text(category.name)
                                        .font(DesignSystem.Typography.caption1)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 60)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
                .frame(height: 150)
            } else {
                // Empty state
                VStack {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text("No data available")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 150)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .cardStyle()
    }
    
    // MARK: - Department Budget Summary Table
    private var departmentBudgetTableSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Department Budget Summary")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Table Header
            HStack {
                Text("Department")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Budget")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
                
                Text("Spent")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
                
                Text("Remaining")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(DesignSystem.CornerRadius.small)
            
            // Table Rows
            VStack(spacing: 1) {
                ForEach(viewModel.filteredDepartmentBudgets, id: \.department) { budget in
                    HStack {
                        Text(budget.department)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("₹\(Int(budget.totalBudget).formatted())")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(.primary)
                            .frame(width: 80, alignment: .trailing)
                        
                        Text("₹\(Int(budget.approvedBudget).formatted())")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(.primary)
                            .frame(width: 80, alignment: .trailing)
                        
                        Text("₹\(Int(budget.totalBudget - budget.approvedBudget).formatted())")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(budget.totalBudget - budget.approvedBudget >= 0 ? .green : .red)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.vertical, DesignSystem.Spacing.small)
                    .background(Color(.quaternarySystemFill))
                }
            }
            .cornerRadius(DesignSystem.CornerRadius.small)
            
            if viewModel.filteredDepartmentBudgets.isEmpty {
                VStack {
                    Image(systemName: "table")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text("No department data available")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.large)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .cardStyle()
    }
}

#Preview {
    ReportView()
}
