//
//  PendingApprovalsView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/26/25.
//

import SwiftUI

struct PendingApprovalsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PendingApprovalsViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Filters
                    filtersView
                    
                    // Approvals List
                    approvalsListView
                    
                    // Action Buttons
                    if viewModel.hasSelectedExpenses {
                        actionButtonsView
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.loadPendingExpenses()
        }
        .alert("Confirm Action", isPresented: $viewModel.showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button(viewModel.pendingAction == .approve ? "Approve" : "Reject", role: viewModel.pendingAction == .approve ? .none : .destructive) {
                viewModel.executeAction()
            }
        } message: {
            Text(viewModel.confirmationMessage)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("AVR")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("ENTERTAINMENT")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                        .tracking(1)
                }
                
                Spacer()
                
                Button {
                    // Search action
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.top, DesignSystem.Spacing.medium)
            
            Text("Pending Approvals")
                .font(DesignSystem.Typography.title1)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, DesignSystem.Spacing.small)
                .padding(.bottom, DesignSystem.Spacing.large)
        }
        .background(
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    // MARK: - Filters View
    private var filtersView: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            // Date Filter
            Menu {
                Button("All Dates") { viewModel.selectedDateFilter = nil }
                Button("Today") { viewModel.selectedDateFilter = "Today" }
                Button("This Week") { viewModel.selectedDateFilter = "This Week" }
                Button("This Month") { viewModel.selectedDateFilter = "This Month" }
            } label: {
                HStack {
                    Text(viewModel.selectedDateFilter ?? "Date")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(.primary)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.small)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(DesignSystem.CornerRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Department Filter
            Menu {
                Button("All Departments") { viewModel.selectedDepartmentFilter = nil }
                ForEach(viewModel.availableDepartments, id: \.self) { department in
                    Button(department) { viewModel.selectedDepartmentFilter = department }
                }
            } label: {
                HStack {
                    Text(viewModel.selectedDepartmentFilter ?? "Dept")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(.primary)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.small)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(DesignSystem.CornerRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Approvals List View
    private var approvalsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Table Header
                tableHeaderView
                
                // Expense Rows
                ForEach(viewModel.filteredExpenses) { expense in
                    ExpenseApprovalRow(
                        expense: expense,
                        isSelected: viewModel.selectedExpenses.contains(expense.id ?? ""),
                        onSelectionChanged: { isSelected in
                            viewModel.toggleExpenseSelection(expense, isSelected: isSelected)
                        },
                        onDetailTapped: {
                            // Show expense details
                        }
                    )
                    .background(Color(UIColor.systemBackground))
                }
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.bottom, DesignSystem.Spacing.extraLarge)
        }
    }
    
    // MARK: - Table Header View
    private var tableHeaderView: some View {
        HStack {
            Text("Date")
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(width: 60, alignment: .leading)
            
            Text("Dept")
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            
            Text("Subcategory")
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Submitted By")
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(Color.secondary.opacity(0.1))
    }
    
    // MARK: - Action Buttons View
    private var actionButtonsView: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Button {
                HapticManager.impact(.medium)
                viewModel.showApprovalConfirmation()
            } label: {
                Text("Approve Selected")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.medium)
                    .background(Color.blue)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            
            Button {
                HapticManager.impact(.medium)
                viewModel.showRejectionConfirmation()
            } label: {
                Text("Reject Selected")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.medium)
                    .background(Color.red)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.bottom, DesignSystem.Spacing.medium)
        .background(Color(UIColor.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
    }
}

#Preview {
    PendingApprovalsView()
} 
