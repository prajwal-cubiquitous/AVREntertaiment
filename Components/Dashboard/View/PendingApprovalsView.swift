//
//  PendingApprovalsView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/26/25.
//

import SwiftUI
import FirebaseFirestore

struct PendingApprovalsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PendingApprovalsViewModel
    @State private var showingExpenseDetail = false
    @State private var selectedExpense: Expense?
    @State private var showingDateFilter = false
    @State private var showingDepartmentFilter = false
    @State private var showingExpenseChat = false
    @State private var selectedExpenseForChat: Expense?
    var project: Project
    let role: UserRole?
    @EnvironmentObject var navigationManager: NavigationManager
    
    init(role: UserRole? = nil, project: Project, phoneNumber: String) {
        self._viewModel = StateObject(wrappedValue: PendingApprovalsViewModel(role: role, project: project,phoneNumber: phoneNumber))
        self.project = project
        self.role = role
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Minimal Header
                    minimalHeaderView
                    
                    // Smart Filters
                    smartFiltersView
                    
                    // Content
                    if viewModel.filteredExpenses.isEmpty {
                        emptyStateView
                    } else {
                        approvalsListView
                    }
                }
                
                // Floating Action Buttons
                if viewModel.hasSelectedExpenses {
                    floatingActionButtons
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.loadPendingExpenses()
            
            // Check if there's already an expenseId set (from notification navigation)
            if let expenseItem = navigationManager.activeExpenseId {
                let showChat = navigationManager.expenseScreenType == .chat
                if !showChat {
                    print("📋 PendingApprovalsView: ExpenseId already set on appear, expenseId: \(expenseItem.id)")
                    // Find and show the expense detail
                    handleExpenseNavigation(expenseId: expenseItem.id)
                }
            }
        }
        .onChange(of: navigationManager.activeExpenseId) { oldValue, newValue in
            if let expenseItem = newValue {
                // Check if we should show expense detail (not chat)
                let showChat = navigationManager.expenseScreenType == .chat
                if !showChat {
                    print("📋 PendingApprovalsView: Expense navigation detected, expenseId: \(expenseItem.id)")
                    // Find and show the expense detail
                    handleExpenseNavigation(expenseId: expenseItem.id)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ExpenseStatusUpdated"))) { _ in
            // Reload expenses when an expense status is updated (approved/rejected)
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
        .sheet(isPresented: $showingExpenseDetail) {
            if let expense = selectedExpense {
                if expense.status == .pending {
                    ExpenseDetailView(expense: expense, role: viewModel.currentUserRole)
                } else {
                    ExpenseDetailReadOnlyView(expense: expense)
                }
            }
        }
        .sheet(isPresented: $showingExpenseChat) {
            if let expense = selectedExpenseForChat , let projectId = project.id{
                ExpenseChatView(
                    expense: expense,
                    userPhoneNumber: viewModel.getCurrentUserPhoneNumber(), projectId: projectId, role: role ?? .USER
                )
            }
        }
    }
    
    // MARK: - Minimal Header View
    private var minimalHeaderView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            
            Spacer()
            
            // Selection indicator
            if viewModel.hasSelectedExpenses {
                Text("\(viewModel.selectedExpenses.count) selected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(12)
            }
            
            Spacer()
            
            Button {
                // Search action
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.top, DesignSystem.Spacing.medium)
        .padding(.bottom, DesignSystem.Spacing.small)
    }
    
    // MARK: - Smart Filters View
    private var smartFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.small) {
                // Date Filter
                FilterChip(
                    title: viewModel.selectedDateFilter ?? "All Dates",
                    isSelected: viewModel.selectedDateFilter != nil,
                    action: {
                        showingDateFilter = true
                    }
                )
                
                // Department Filter
                FilterChip(
                    title: viewModel.selectedDepartmentFilter ?? "All Depts",
                    isSelected: viewModel.selectedDepartmentFilter != nil,
                    action: {
                        showingDepartmentFilter = true
                    }
                )
                
                // Amount Filter
                FilterChip(
                    title: "Amount",
                    isSelected: false,
                    action: {
                        // Show amount filter
                    }
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
        }
        .padding(.vertical, DesignSystem.Spacing.small)
        .actionSheet(isPresented: $showingDateFilter) {
            ActionSheet(
                title: Text("Filter by Date"),
                buttons: [
                    .default(Text("All Dates")) {
                        viewModel.selectedDateFilter = nil
                    },
                    .default(Text("Today")) {
                        viewModel.selectedDateFilter = "Today"
                    },
                    .default(Text("This Week")) {
                        viewModel.selectedDateFilter = "This Week"
                    },
                    .default(Text("This Month")) {
                        viewModel.selectedDateFilter = "This Month"
                    },
                    .cancel()
                ]
            )
        }
        .actionSheet(isPresented: $showingDepartmentFilter) {
            ActionSheet(
                title: Text("Filter by Department"),
                buttons: [
                    .default(Text("All Departments")) {
                        viewModel.selectedDepartmentFilter = nil
                    }
                ] + viewModel.availableDepartments.map { department in
                    .default(Text(department)) {
                        viewModel.selectedDepartmentFilter = department
                    }
                } + [.cancel()]
            )
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Spacer()
            
            VStack(spacing: DesignSystem.Spacing.medium) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                    .symbolRenderingMode(.hierarchical)
                
                Text("All Caught Up!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("No pending approvals at the moment")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Approvals List View
    private var approvalsListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.small) {
                ForEach(viewModel.filteredExpenses) { expense in
                    ModernExpenseApprovalRow(
                        expense: expense,
                        isSelected: viewModel.selectedExpenses.contains(expense.id ?? ""),
                        onSelectionChanged: { isSelected in
                            viewModel.toggleExpenseSelection(expense, isSelected: isSelected)
                        },
                        onDetailTapped: {
                            selectedExpense = expense
                            showingExpenseDetail = true
                        },
                        onChatTapped: {
                            selectedExpenseForChat = expense
                            showingExpenseChat = true
                        },
                        viewModel: viewModel
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.bottom, 100) // Space for floating buttons
        }
    }
    
    // MARK: - Handle Expense Navigation
    private func handleExpenseNavigation(expenseId: String) {
        // Wait for expenses to load, then find and show the expense
        Task {
            // Wait a bit for expenses to load if they haven't yet
            if viewModel.filteredExpenses.isEmpty {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            // Try to find the expense in the loaded expenses
            if let expense = viewModel.filteredExpenses.first(where: { $0.id == expenseId }) {
                await MainActor.run {
                    selectedExpense = expense
                    showingExpenseDetail = true
                    // Clear navigation after showing
                    navigationManager.setExpenseId(nil)
                }
            } else {
                // Expense not found in pending list, might be approved/rejected
                // Try to load it directly from Firebase
                await loadExpenseDirectly(expenseId: expenseId)
            }
        }
    }
    
    private func loadExpenseDirectly(expenseId: String) async {
        guard let projectId = project.id,
              let customerId = try? await FirebasePathHelper.shared.fetchEffectiveUserID() else {
            return
        }
        
        do {
            let expenseDoc = try await FirebasePathHelper.shared
                .expensesCollection(customerId: customerId, projectId: projectId)
                .document(expenseId)
                .getDocument()
            
            if expenseDoc.exists, var expense = try? expenseDoc.data(as: Expense.self) {
                expense.id = expenseDoc.documentID
                await MainActor.run {
                    selectedExpense = expense
                    showingExpenseDetail = true
                    // Clear navigation after showing
                    navigationManager.setExpenseId(nil)
                }
            } else {
                // Expense not found, clear navigation
                await MainActor.run {
                    navigationManager.setExpenseId(nil)
                }
            }
        } catch {
            print("❌ Error loading expense: \(error)")
            await MainActor.run {
                navigationManager.setExpenseId(nil)
            }
        }
    }
    
    // MARK: - Floating Action Buttons
    private var floatingActionButtons: some View {
        VStack {
            Spacer()
            
            HStack(spacing: DesignSystem.Spacing.medium) {
                // Approve Button
                Button {
                    HapticManager.impact(.medium)
                    viewModel.showApprovalConfirmation()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                        Text("Approve")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.medium)
                    .background(Color.green)
                    .cornerRadius(DesignSystem.CornerRadius.large)
                }
                
                // Reject Button
                Button {
                    HapticManager.impact(.medium)
                    viewModel.showRejectionConfirmation()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                        Text("Reject")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.medium)
                    .background(Color.red)
                    .cornerRadius(DesignSystem.CornerRadius.large)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.bottom, DesignSystem.Spacing.medium)
            .background(
                Rectangle()
                    .fill(.regularMaterial)
                    .ignoresSafeArea()
            )
        }
    }
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.systemBackground))
                        .overlay(
                            Capsule()
                                .stroke(Color.secondary.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modern Expense Approval Row
struct ModernExpenseApprovalRow: View {
    let expense: Expense
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    let onDetailTapped: () -> Void
    let onChatTapped: () -> Void
    @ObservedObject var viewModel: PendingApprovalsViewModel
    @State var UserName: String = ""
    @State private var showingFileViewer = false
    
    // Helper function to extract department name (everything after first underscore)
    private func extractDepartmentName(from departmentString: String) -> String {
        if let underscoreIndex = departmentString.firstIndex(of: "_") {
            let departmentName = String(departmentString[departmentString.index(after: underscoreIndex)...])
            return departmentName.isEmpty ? departmentString : departmentName
        }
        return departmentString
    }
    
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            // Selection Checkbox
            Button {
                HapticManager.selection()
                onSelectionChanged(!isSelected)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .green : .secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            
            // Main Content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                
                // Top Row: Amount and Date
                HStack {
                    Text("₹\(String(format: "%.2f", expense.amount))")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(expense.date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Middle Row: Department and Categories
                HStack {
                    Text(extractDepartmentName(from: expense.department))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
//                    Spacer()
//                    
//                    Text(expense.categories.joined(separator: ", "))
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                        .lineLimit(1)
                    
                    Spacer()
                    
                    // File attachment icon
                    if let attachmentURL = expense.attachmentURL, !attachmentURL.isEmpty {
                        FileIconView(
                            fileName: expense.attachmentName,
                            fileURL: attachmentURL,
                            onTap: {
                                showingFileViewer = true
                            }, isReciept: true
                        )
                    }
                    
                    // Message Button
                    Button {
                        HapticManager.selection()
                        onChatTapped()
                    } label: {
                        Image(systemName: "message")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)

                }
                
                // Bottom Row: Submitted By and Description
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Submitted by: \(UserName != "" ? UserName : expense.submittedBy)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
//                    Spacer()
//                    
//                    if !expense.description.isEmpty {
//                        Text(expense.description)
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                            .lineLimit(1)
//                    }
                    
            
                }
            }
            
            // Detail Button
            Button {
                HapticManager.selection()
                onDetailTapped()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .task {
            do {
                UserName = try await viewModel.loadUserData(userId: expense.submittedBy)
            } catch {
                // Now you can handle specific failures
                print("Failed to load user data: \(error)") // More descriptive now
                
                // Optional: Update the UI based on the specific error
                if let userDataError = error as? UserDataError {
                    switch userDataError {
                    case .userNotFound:
                        print("User Not Found Error")
                    case .missingNameField:
                        print("Name not available")
                    case .invalidUserId:
                        print("Invalid user")
                    }
                } else {
                    // Handle other errors like network issues
                   print("Error loading")
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingFileViewer) {
            if let urlString = expense.attachmentURL,
               let url = URL(string: urlString) {
                FileViewerSheet(fileURL: url, fileName: expense.attachmentName)
            }
        }
    }
}

//#Preview {
//    PendingApprovalsView(role: .ADMIN, project: .constant(Project(id: "123", name: "Test"))
//} 
