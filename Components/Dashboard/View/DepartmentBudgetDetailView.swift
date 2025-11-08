//
//  DepartmentBudgetDetailView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/1/25.
//

import SwiftUI
import FirebaseFirestore

enum SortOption: String, CaseIterable {
    case dateDescending = "Date (Newest First)"
    case dateAscending = "Date (Oldest First)"
    case amountDescending = "Amount (High to Low)"
    case amountAscending = "Amount (Low to High)"
    case status = "Status"
    
    var icon: String {
        switch self {
        case .dateDescending: return "calendar.badge.clock"
        case .dateAscending: return "calendar.badge.clock"
        case .amountDescending: return "arrow.down.circle"
        case .amountAscending: return "arrow.up.circle"
        case .status: return "tag"
        }
    }
}

struct DepartmentBudgetDetailView: View {
    let department: String
    let projectId: String
    let role: UserRole?
    let phoneNumber: String
    let phaseId: String?
    @StateObject private var viewModel: DepartmentBudgetDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(department: String, projectId: String, role: UserRole?, phoneNumber: String, phaseId: String? = nil) {
        self.department = department
        self.projectId = projectId
        self.role = role
        self.phoneNumber = phoneNumber
        self.phaseId = phaseId
        self._viewModel = StateObject(wrappedValue: DepartmentBudgetDetailViewModel(phaseId: phaseId))
    }
    @State private var selectedFilter: ExpenseStatus? = nil
    @State private var searchText = ""
    @State private var showingExpenseChat = false
    @State private var selectedExpenseForChat: Expense?
    @State private var showingExpenseDetail = false
    @State private var selectedExpenseForDetail: Expense?
    @State private var showingDateRangePicker = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isDateRangeActive = false
    @State private var sortOption: SortOption = .dateDescending
    @State private var showingSortOptions = false
    @State private var showingEditBudget = false
    @State private var showingDeleteConfirmation = false
    @State private var showingMenu = false
    @State private var showingOnlyDepartmentAlert = false
    @State private var showingAddDepartmentSheet = false
    @State private var pendingDeleteAfterAdd = false
    @State private var phaseIdForDelete: String? = nil
    
    private var filteredExpenses: [Expense] {
        var expenses = viewModel.expenses
        
        // Filter by status - only apply filter if a specific status is selected
        // When selectedFilter is nil, show all expenses (no filtering)
        if let status = selectedFilter {
            expenses = expenses.filter { $0.status == status }
        }
        // When selectedFilter is nil, all expenses are shown (no filtering applied)
        
        // Filter by date range
        if isDateRangeActive {
            expenses = expenses.filter { expense in
                let expenseDate = expense.createdAt.dateValue()
                return expenseDate >= startDate && expenseDate <= endDate
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            expenses = expenses.filter { expense in
                expense.description.localizedCaseInsensitiveContains(searchText) ||
                expense.categoriesString.localizedCaseInsensitiveContains(searchText) ||
                expense.submittedBy.contains(searchText)
            }
        }
        
        // Sort expenses
        switch sortOption {
        case .dateDescending:
            expenses = expenses.sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
        case .dateAscending:
            expenses = expenses.sorted { $0.createdAt.dateValue() < $1.createdAt.dateValue() }
        case .amountDescending:
            expenses = expenses.sorted { $0.amount > $1.amount }
        case .amountAscending:
            expenses = expenses.sorted { $0.amount < $1.amount }
        case .status:
            expenses = expenses.sorted { $0.status.rawValue < $1.status.rawValue }
        }
        
        return expenses
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with department info
                headerView
                
                // Filter and search section
                filterSection
                
                // Content
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.expenses.isEmpty {
                    emptyStateView
                } else {
                    expensesListView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
                
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(department)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(department == "Other" ? "Anonymous Expenses" : "Department Expenses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Hide edit/delete options for "Other" department (anonymous expenses)
                    if role == .ADMIN && department != "Other" {
                        Menu {
                            Button(role: .none) {
                                showingEditBudget = true
                            } label: {
                                Label("Edit Budget", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                Task {
                                    let isOnlyDepartment = await viewModel.isOnlyDepartmentInAnyPhase(
                                        department: department,
                                        projectId: projectId
                                    )
                                    await MainActor.run {
                                        if isOnlyDepartment {
                                            showingOnlyDepartmentAlert = true
                                        } else {
                                            showingDeleteConfirmation = true
                                        }
                                    }
                                }
                            } label: {
                                Label("Delete Department", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Ensure filter is reset to "All" when view appears
            selectedFilter = nil
            viewModel.loadExpenses(for: department, projectId: projectId)
        }
        .sheet(isPresented: $showingExpenseChat) {
            if let expense = selectedExpenseForChat {
                ExpenseChatView(
                    expense: expense,
                    userPhoneNumber: phoneNumber, 
                    projectId: projectId, 
                    role: role ?? .USER
                )
            }
        }
        .sheet(isPresented: $showingExpenseDetail) {
            if let expense = selectedExpenseForDetail {
                if expense.status == .pending {
                    ExpenseDetailView(expense: expense, role: role)
                } else {
                    ExpenseDetailReadOnlyView(expense: expense)
                }
            }
        }
        // date-range panel is rendered inline inside filterSection overlay
        .confirmationDialog("Sort Options", isPresented: $showingSortOptions) {
            ForEach(SortOption.allCases, id: \.self) { option in
                Button(action: {
                    sortOption = option
                }) {
                    HStack {
                        Text(option.rawValue)
                        if sortOption == option {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditBudget) {
            EditBudgetSheet(
                department: department,
                projectId: projectId,
                currentBudget: viewModel.totalBudget,
                onSave: { newBudget in
                    Task {
                        await viewModel.updateDepartmentBudget(
                            department: department,
                            projectId: projectId,
                            newBudget: newBudget
                        )
                        // Reload expenses to refresh budget display
                        await viewModel.loadExpenses(for: department, projectId: projectId)
                        await MainActor.run {
                            showingEditBudget = false
                        }
                    }
                }
            )
            .presentationDetents([.medium])
        }
        .alert("Cannot Delete Department", isPresented: $showingOnlyDepartmentAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Add Department") {
                showingAddDepartmentSheet = true
            }
        } message: {
            Text("There should be at least one department in each phase. Please add a new department before deleting this one.")
        }
        .alert("Delete Department", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteDepartment(
                        department: department,
                        projectId: projectId
                    )
                    await MainActor.run {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this department? This will remove it from all phases. This action cannot be undone.")
        }
        .sheet(isPresented: $showingAddDepartmentSheet, onDismiss: {
            if pendingDeleteAfterAdd, let phaseIdToDelete = phaseIdForDelete {
                Task {
                    await viewModel.deleteDepartmentFromPhase(
                        department: department,
                        projectId: projectId,
                        phaseId: phaseIdToDelete
                    )
                    // Reload expenses to refresh the view
                    await viewModel.loadExpenses(for: department, projectId: projectId)
                    await MainActor.run {
                        pendingDeleteAfterAdd = false
                        phaseIdForDelete = nil
                        dismiss()
                    }
                }
            }
        }) {
            if let phaseInfo = viewModel.phasesWithOnlyThisDepartment.first {
                AddDepartmentSheetForDelete(
                    projectId: projectId,
                    phaseId: phaseInfo.id,
                    phaseName: phaseInfo.name,
                    onSaved: {
                        phaseIdForDelete = phaseInfo.id
                        pendingDeleteAfterAdd = true
                        showingAddDepartmentSheet = false
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            // Department stats
            GeometryReader { geometry in
                VStack(spacing: 12) {
                    // 🔹 Total Budget (Top Center)
                    VStack(spacing: 4) {
                        Text("Total Budget")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(department != "Other" ? viewModel.totalBudgetFormatted : "N/A")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    // 🔹 Spent and Remaining (Bottom Row)
                    HStack {
                        VStack(spacing: 4) {
                            Text("Spent")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(viewModel.totalSpentFormatted)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(width: geometry.size.width / 2, alignment: .leading)
                        
                        VStack(spacing: 4) {
                            Text("Remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(department != "Other" ? viewModel.remainingBudgetFormatted : "N/A")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(viewModel.remainingBudget >= 0 ? .blue : .red)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .multilineTextAlignment(.trailing)
                        }
                        .frame(width: geometry.size.width / 2, alignment: .trailing)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 100)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray5), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)

            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Budget Utilization")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(Int(viewModel.budgetUtilizationPercentage))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: viewModel.remainingBudget >= 0 ? [.green, .blue] : [.red, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(min(viewModel.budgetUtilizationPercentage / 100, 1.0)), height: 8)
                            .animation(.easeInOut(duration: 1.0), value: viewModel.budgetUtilizationPercentage)
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search expenses...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                Menu {
                    // Status Section
                    Section("Status") {
                        Button(action: { 
                            // Explicitly reset filter to show all expenses
                            selectedFilter = nil
                        }) {
                            HStack {
                                Text("All")
                                if selectedFilter == nil { Spacer(); Image(systemName: "checkmark") }
                            }
                        }
                        ForEach(ExpenseStatus.allCases, id: \.self) { status in
                            Button(action: { 
                                selectedFilter = status
                            }) {
                                HStack {
                                    Text(status.rawValue.capitalized)
                                    if selectedFilter == status { Spacer(); Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }

                    // Sort Picker
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Label(option.rawValue, systemImage: option.icon)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    // Date Range Controls
                    Toggle(isOn: $isDateRangeActive) {
                        Label("Enable Date Range", systemImage: "calendar")
                    }
                    Button {
                        showingDateRangePicker = true
                    } label: {
                        Label("Set Date Range…", systemImage: "calendar.badge.plus")
                    }

                    // Clear section
                    if selectedFilter != nil || isDateRangeActive || searchText.isEmpty == false || sortOption != .dateDescending {
                        Button("Clear All Filters", role: .destructive) {
                            selectedFilter = nil
                            isDateRangeActive = false
                            searchText = ""
                            sortOption = .dateDescending
                        }
                    }
                } label: {
                    Label("Filter & Sort", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)

            // Unified Filter & Sort Menu
            HStack {
//                Menu {
//                    // Status Section
//                    Section("Status") {
//                        Button(action: { selectedFilter = nil }) {
//                            HStack {
//                                Text("All")
//                                if selectedFilter == nil { Spacer(); Image(systemName: "checkmark") }
//                            }
//                        }
//                        ForEach(ExpenseStatus.allCases, id: \.self) { status in
//                            Button(action: { selectedFilter = status }) {
//                                HStack {
//                                    Text(status.rawValue.capitalized)
//                                    if selectedFilter == status { Spacer(); Image(systemName: "checkmark") }
//                                }
//                            }
//                        }
//                    }
//
//                    // Sort Picker
//                    Picker("Sort by", selection: $sortOption) {
//                        ForEach(SortOption.allCases, id: \.self) { option in
//                            Label(option.rawValue, systemImage: option.icon)
//                                .tag(option)
//                        }
//                    }
//                    .pickerStyle(.menu)
//
//                    // Date Range Controls
//                    Toggle(isOn: $isDateRangeActive) {
//                        Label("Enable Date Range", systemImage: "calendar")
//                    }
//                    Button {
//                        showingDateRangePicker = true
//                    } label: {
//                        Label("Set Date Range…", systemImage: "calendar.badge.plus")
//                    }
//
//                    // Clear section
//                    if selectedFilter != nil || isDateRangeActive || searchText.isEmpty == false || sortOption != .dateDescending {
//                        Button("Clear All Filters", role: .destructive) {
//                            selectedFilter = nil
//                            isDateRangeActive = false
//                            searchText = ""
//                            sortOption = .dateDescending
//                        }
//                    }
//                } label: {
//                    Label("Filter & Sort", systemImage: "line.3.horizontal.decrease.circle")
//                        .font(.subheadline)
//                        .padding(.horizontal, 12)
//                        .padding(.vertical, 8)
//                        .background(Color.blue.opacity(0.1))
//                        .clipShape(RoundedRectangle(cornerRadius: 12))
//                }

//                Spacer()

                // Totals Summary
                totalsSummary
            }
            
            // Removed legacy status chips (now consolidated in unified menu)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(alignment: .topLeading) {
            if showingDateRangePicker {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Date Range")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Button(action: { showingDateRangePicker = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start").font(.caption2).foregroundColor(.secondary)
                            DatePicker("Start", selection: $startDate, displayedComponents: [.date])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .scaleEffect(0.8)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("End").font(.caption2).foregroundColor(.secondary)
                            DatePicker("End", selection: $endDate, displayedComponents: [.date])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if endDate < startDate {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("End date must be after start date")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Button {
                            isDateRangeActive = false
                            showingDateRangePicker = false
                        } label: {
                            Text("Clear")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button {
                            guard endDate >= startDate else { return }
                            isDateRangeActive = true
                            showingDateRangePicker = false
                        } label: {
                            Text("Apply")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(endDate < startDate)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .frame(maxWidth: 280)
                .padding(.leading, 16)
                .padding(.top, 100)
            }
        }
    }

    // MARK: - Totals Summary View
    private var totalsSummary: some View {
        let approved = viewModel.expenses.filter { $0.status == .approved }.reduce(0.0) { $0 + $1.amount }
        let pending = viewModel.expenses.filter { $0.status == .pending }.reduce(0.0) { $0 + $1.amount }
        let rejected = viewModel.expenses.filter { $0.status == .rejected }.reduce(0.0) { $0 + $1.amount }
        return HStack(spacing: 8) {
            amountBadge(title: "Approved", amount: approved, color: .green)
            amountBadge(title: "Pending", amount: pending, color: .orange)
            amountBadge(title: "Rejected", amount: rejected, color: .red)
        }
    }

    private func amountBadge(title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            Text(Int(amount).formattedCurrency)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.accentColor)
            
            Text("Loading expenses...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.6))
                .symbolRenderingMode(.hierarchical)
            
            Text("No Expenses Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(department == "Other" 
                 ? "No anonymous expenses found yet." 
                 : "No expenses have been recorded for the \(department) department yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Expenses List View
    private var expensesListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredExpenses) { expense in
                    DepartmentExpenseRowView(
                        expense: expense, 
                        approverName: viewModel.getApproverName(for: expense),
                        onChatTapped: {
                            selectedExpenseForChat = expense
                            showingExpenseChat = true
                        },
                        onExpenseTapped: {
                            selectedExpenseForDetail = expense
                            showingExpenseDetail = true
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Department Filter Chip
struct DepartmentFilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? color : color.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Department Expense Row View
struct DepartmentExpenseRowView: View {
    let expense: Expense
    let approverName: String?
    let onChatTapped: () -> Void
    let onExpenseTapped: () -> Void
    @State private var showingFileViewer = false
    
    var body: some View {
        Button(action: {
            HapticManager.selection()
            onExpenseTapped()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with amount and status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(expense.amountFormatted)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        // Date at top-right
                        HStack {
                            Spacer()
                            Text(expense.dateFormatted)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 8) {
                            // Status badge with enhanced design
                            HStack(spacing: 4) {
                                Image(systemName: expense.status.icon)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                
                                Text(expense.status.rawValue.capitalized)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(expense.status.color)
                                    .shadow(color: expense.status.color.opacity(0.3), radius: 2, x: 0, y: 1)
                            )
                            
                            // Chat button - only show for pending expenses
                            if expense.status == .pending {
                                Button {
                                    HapticManager.selection()
                                    onChatTapped()
                                } label: {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                        .padding(6)
                                        .background(
                                            Circle()
                                                .fill(Color.blue.opacity(0.1))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Show approver text only when the expense is approved
                        if expense.status == .approved, let approver = approverName {
                            Text("Approved by \(approver)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Description
                Text(expense.description)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Categories and payment mode
                HStack {
                    // Categories
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        Text(expense.categoriesString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Payment mode
                    HStack(spacing: 4) {
                        Image(systemName: expense.modeOfPayment.icon)
                            .font(.caption2)
                            .foregroundColor(.green)
                        
                        Text(expense.modeOfPayment.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Submitted by
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    
                    Text("Submitted by: \(expense.submittedBy)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // File attachment icon
                    if let attachmentURL = expense.attachmentURL, !attachmentURL.isEmpty {
                        FileIconView(
                            fileName: expense.attachmentName,
                            fileURL: attachmentURL,
                            onTap: {
                                showingFileViewer = true
                            }
                        )
                    }
                }
                
                // Remark intentionally omitted in list view; shown in detail view
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingFileViewer) {
            if let urlString = expense.attachmentURL,
               let url = URL(string: urlString) {
                FileViewerSheet(fileURL: url, fileName: expense.attachmentName)
            }
        }
    }
}

// MARK: - View Model
class DepartmentBudgetDetailViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalBudget: Double = 0
    @Published var totalSpent: Double = 0
    @Published var approvers: [String: String] = [:] // phoneNumber: name
    @Published var phaseIds: [String] = [] // Store phase IDs that contain this department
    @Published var phasesWithOnlyThisDepartment: [(id: String, name: String)] = [] // Phases with only this department
    
    let phaseId: String? // Store the phaseId passed from the view
    
    init(phaseId: String? = nil) {
        self.phaseId = phaseId
    }
    
    var remainingBudget: Double {
        totalBudget - totalSpent
    }
    
    var customerID: String {
        get async throws {
            try await FirebasePathHelper.shared.fetchEffectiveUserID()
        }
    }

    var budgetUtilizationPercentage: Double {
        guard totalBudget > 0 else { return 0 }
        return (totalSpent / totalBudget) * 100
    }
    
    var totalBudgetFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: totalBudget)) ?? "₹0"
    }
    
    var totalSpentFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: totalSpent)) ?? "₹0"
    }
    
    var remainingBudgetFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: remainingBudget)) ?? "₹0"
    }
    
    func loadExpenses(for department: String, projectId: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Get customer ID
                let customerID = try await FirebasePathHelper.shared.fetchEffectiveUserID()
                
                // Special handling for "Other" department (anonymous expenses)
                let loadedExpenses: [Expense]
                if department == "Other" {
                    // Load anonymous expenses for this project
                    let baseQuery = FirebasePathHelper.shared
                        .expensesCollection(customerId: customerID, projectId: projectId)
                        .whereField("isAnonymous", isEqualTo: true)
                    
                    // Build query conditionally based on whether phaseId is provided
                    let query: Query
                    if let phaseId = phaseId {
                        query = baseQuery.whereField("phaseId", isEqualTo: phaseId)
                        print("🔍 [Other Department] Loading anonymous expenses with phaseId: \(phaseId)")
                    } else {
                        query = baseQuery
                        print("🔍 [Other Department] Loading all anonymous expenses (no phaseId filter)")
                    }
                    
                    let expensesSnapshot = try await query
                        .order(by: "createdAt", descending: true)
                        .getDocuments()
                    
                    print("🔍 [Other Department] Found \(expensesSnapshot.documents.count) anonymous expenses in query")
                    
                    loadedExpenses = expensesSnapshot.documents.compactMap { doc in
                        do {
                            var expense = try doc.data(as: Expense.self)
                            expense.id = doc.documentID
                            return expense
                        } catch {
                            print("❌ Error decoding expense document \(doc.documentID): \(error)")
                            return nil
                        }
                    }
                    
                    print("✅ [Other Department] Successfully loaded \(loadedExpenses.count) expenses")
                } else {
                    // Load expenses for the specific department
                    let baseQuery = FirebasePathHelper.shared
                        .expensesCollection(customerId: customerID, projectId: projectId)
                        .whereField("department", isEqualTo: department)
                    
                    // Build query conditionally based on whether phaseId is provided
                    let query: Query
                    if let phaseId = phaseId {
                        query = baseQuery.whereField("phaseId", isEqualTo: phaseId)
                        print("🔍 Loading expenses for department: \(department), phaseId: \(phaseId)")
                    } else {
                        query = baseQuery
                        print("🔍 Loading expenses for department: \(department), all phases (no phaseId filter)")
                    }
                    
                    let expensesSnapshot = try await query
                        .order(by: "createdAt", descending: true)
                        .getDocuments()
                    
                    print("🔍 Found \(expensesSnapshot.documents.count) expenses in query for department: \(department)")
                    
                    loadedExpenses = expensesSnapshot.documents.compactMap { doc in
                        do {
                            var expense = try doc.data(as: Expense.self)
                            expense.id = doc.documentID
                            return expense
                        } catch {
                            print("❌ Error decoding expense document \(doc.documentID): \(error)")
                            return nil
                        }
                    }
                    
                    print("✅ Successfully loaded \(loadedExpenses.count) expenses for department: \(department)")
                }
                
                // Calculate totals
                let totalSpent = loadedExpenses
                    .filter { $0.status == .approved }
                    .reduce(0) { $0 + $1.amount }
                
                // For "Other" department, budget is 0 (no allocated budget for anonymous expenses)
                var allocated: Double = 0
                var phaseIdsWithDepartment: [String] = []
                var phasesOnlyWithThisDepartment: [(id: String, name: String)] = []
                
                if department != "Other" {
                    // Aggregate allocated budget from phases for this department
                    let phasesSnapshot = try await FirebasePathHelper.shared
                        .phasesCollection(customerId: customerID, projectId: projectId)
                        .getDocuments()
                    for doc in phasesSnapshot.documents {
                        if let phase = try? doc.data(as: Phase.self) {
                            if phase.departments[department] != nil {
                                allocated += phase.departments[department] ?? 0
                                phaseIdsWithDepartment.append(doc.documentID)
                                
                                // Check if this is the only department in this phase
                                if phase.departments.count == 1 {
                                    phasesOnlyWithThisDepartment.append((id: doc.documentID, name: phase.phaseName))
                                }
                            }
                        }
                    }
                }
                
                // Load approver names
                await loadApproverNames(for: loadedExpenses)
                
                await MainActor.run {
                    self.totalBudget = allocated
                    self.expenses = loadedExpenses
                    self.totalSpent = totalSpent
                    self.phaseIds = phaseIdsWithDepartment
                    self.phasesWithOnlyThisDepartment = phasesOnlyWithThisDepartment
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadApproverNames(for expenses: [Expense]) async {
        let uniquePhoneNumbers = Set(expenses.compactMap { expense in
            // For now, we'll use submittedBy as the approver
            // In a real implementation, you'd have a separate approver field
            expense.submittedBy
        })
        
        for phoneNumber in uniquePhoneNumbers {
            do {
                let db = Firestore.firestore()
                let userDoc = try await db
                    .collection(FirebaseCollections.users)
                    .whereField("phoneNumber", isEqualTo: phoneNumber)
                    .limit(to: 1)
                    .getDocuments()
                
                if let userData = userDoc.documents.first?.data(),
                   let name = userData["name"] as? String {
                    await MainActor.run {
                        self.approvers[phoneNumber] = name
                    }
                }
            } catch {
                print("Error loading approver name for \(phoneNumber): \(error)")
            }
        }
    }
    
    func getApproverName(for expense: Expense) -> String? {
        return approvers[expense.submittedBy]
    }
    
    func getCurrentUserPhoneNumber() -> String {
        // This should be passed from the parent view or retrieved from user defaults
        // For now, returning a placeholder - you may need to implement proper user management
        return UserDefaults.standard.string(forKey: "userPhoneNumber") ?? ""
    }
    
    func isOnlyDepartmentInAnyPhase(department: String, projectId: String) async -> Bool {
        do {
            let customerID = try await FirebasePathHelper.shared.fetchEffectiveUserID()
            
            // Get all phases
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerID, projectId: projectId)
                .getDocuments()
            
            // Check if any phase has only this department
            for doc in phasesSnapshot.documents {
                if let phase = try? doc.data(as: Phase.self) {
                    if phase.departments[department] != nil && phase.departments.count == 1 {
                        // Update phasesWithOnlyThisDepartment if not already loaded
                        await MainActor.run {
                            if !self.phasesWithOnlyThisDepartment.contains(where: { $0.id == doc.documentID }) {
                                self.phasesWithOnlyThisDepartment.append((id: doc.documentID, name: phase.phaseName))
                            }
                        }
                        return true
                    }
                }
            }
            
            return false
        } catch {
            return false
        }
    }
    
    func updateDepartmentBudget(department: String, projectId: String, newBudget: Double) async {
        do {
            let customerID = try await FirebasePathHelper.shared.fetchEffectiveUserID()
            
            // Update budget in all phases that contain this department
            // We need to distribute the new budget across all phases
            // For simplicity, we'll set the same budget in each phase
            // Or you could calculate proportional distribution
            
            // First, get all phases with this department
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerID, projectId: projectId)
                .getDocuments()
            
            var phasesWithDepartment: [(id: String, currentBudget: Double)] = []
            for doc in phasesSnapshot.documents {
                if let phase = try? doc.data(as: Phase.self) {
                    if let currentBudget = phase.departments[department] {
                        phasesWithDepartment.append((id: doc.documentID, currentBudget: currentBudget))
                    }
                }
            }
            
            guard !phasesWithDepartment.isEmpty else { return }
            
            // Calculate total current budget to maintain proportions
            let totalCurrentBudget = phasesWithDepartment.reduce(0) { $0 + $1.currentBudget }
            
            // Update each phase proportionally
            for phaseData in phasesWithDepartment {
                let phaseRef = FirebasePathHelper.shared
                    .phasesCollection(customerId: customerID, projectId: projectId)
                    .document(phaseData.id)
                
                // Calculate proportional budget for this phase
                let proportion = totalCurrentBudget > 0 ? (phaseData.currentBudget / totalCurrentBudget) : (1.0 / Double(phasesWithDepartment.count))
                let newPhaseBudget = newBudget * proportion
                
                try await phaseRef.updateData([
                    "departments.\(department)": newPhaseBudget
                ])
            }
            
            // Update project budget after changing department budget
            await updateProjectBudget(projectId: projectId, customerId: customerID)
            
            // Reload expenses to refresh the budget
            await MainActor.run {
                self.totalBudget = newBudget
                // Notify parent views to refresh
                NotificationCenter.default.post(name: NSNotification.Name("DepartmentBudgetUpdated"), object: nil)
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update budget: \(error.localizedDescription)"
            }
        }
    }
    
    // Helper function to update project budget
    private func updateProjectBudget(projectId: String, customerId: String) async {
        do {
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .getDocuments()
            
            var totalBudget: Double = 0
            for doc in phasesSnapshot.documents {
                if let phase = try? doc.data(as: Phase.self) {
                    totalBudget += phase.departments.values.reduce(0, +)
                }
            }
            
            // Update project budget
            try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .updateData([
                    "budget": totalBudget,
                    "updatedAt": Timestamp()
                ])
        } catch {
            print("Error updating project budget: \(error.localizedDescription)")
        }
    }
    
    func deleteDepartment(department: String, projectId: String) async {
        do {
            let customerID = try await FirebasePathHelper.shared.fetchEffectiveUserID()
            let currentTimestamp = Timestamp()
            let db = Firestore.firestore()
            
            // Get all phases
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerID, projectId: projectId)
                .getDocuments()
            
            // Collect phase IDs that contain this department
            var phaseIdsToUpdate: [String] = []
            
            // Delete department from all phases that contain it
            for doc in phasesSnapshot.documents {
                if let phase = try? doc.data(as: Phase.self) {
                    if phase.departments[department] != nil {
                        let phaseRef = FirebasePathHelper.shared
                            .phasesCollection(customerId: customerID, projectId: projectId)
                            .document(doc.documentID)
                        
                        // Remove the department from the departments dictionary
                        try await phaseRef.updateData([
                            "departments.\(department)": FieldValue.delete()
                        ])
                        
                        // Track this phase ID for expense updates
                        phaseIdsToUpdate.append(doc.documentID)
                    }
                }
            }
            
            // Update all expenses with matching department and phaseId
            for phaseId in phaseIdsToUpdate {
                let expensesSnapshot = try await FirebasePathHelper.shared
                    .expensesCollection(customerId: customerID, projectId: projectId)
                    .whereField("department", isEqualTo: department)
                    .whereField("phaseId", isEqualTo: phaseId)
                    .getDocuments()
                
                // Batch update expenses
                let batch = db.batch()
                for expenseDoc in expensesSnapshot.documents {
                    let expenseRef = expenseDoc.reference
                    batch.updateData([
                        "isAnonymous": true,
                        "originalDepartment": department,
                        "departmentDeletedAt": currentTimestamp,
                        "updatedAt": currentTimestamp
                    ], forDocument: expenseRef)
                }
                
                // Commit batch update
                try await batch.commit()
            }
            
            // Update project budget after deleting department
            await updateProjectBudget(projectId: projectId, customerId: customerID)
            
            // Notify parent views to refresh
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("DepartmentDeleted"), object: nil)
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete department: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteDepartmentFromPhase(department: String, projectId: String, phaseId: String) async {
        do {
            let customerID = try await FirebasePathHelper.shared.fetchEffectiveUserID()
            let currentTimestamp = Timestamp()
            let db = Firestore.firestore()
            
            let phaseRef = FirebasePathHelper.shared
                .phasesCollection(customerId: customerID, projectId: projectId)
                .document(phaseId)
            
            // Remove the department from the departments dictionary
            try await phaseRef.updateData([
                "departments.\(department)": FieldValue.delete()
            ])
            
            // Find all expenses with matching department and phaseId
            let expensesSnapshot = try await FirebasePathHelper.shared
                .expensesCollection(customerId: customerID, projectId: projectId)
                .whereField("department", isEqualTo: department)
                .whereField("phaseId", isEqualTo: phaseId)
                .getDocuments()
            
            // Batch update expenses to mark them as anonymous
            let batch = db.batch()
            for expenseDoc in expensesSnapshot.documents {
                let expenseRef = expenseDoc.reference
                batch.updateData([
                    "isAnonymous": true,
                    "originalDepartment": department,
                    "departmentDeletedAt": currentTimestamp,
                    "updatedAt": currentTimestamp
                ], forDocument: expenseRef)
            }
            
            // Commit batch update
            try await batch.commit()
            
            // Update project budget after deleting department from phase
            await updateProjectBudget(projectId: projectId, customerId: customerID)
            
            // Notify parent views to refresh
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("DepartmentDeleted"), object: nil)
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete department: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    DepartmentBudgetDetailView(
        department: "Costumes",
        projectId: "128YgC7uVnge9RLxVrgG",
        role: .APPROVER,
        phoneNumber: "9876543218",
        phaseId: nil
    )
}

// MARK: - Inline Date Range Popover
struct InlineDateRangePopover: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isActive: Bool
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Date Range")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Start Date").font(.caption).foregroundColor(.secondary)
                DatePicker("Start", selection: $startDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                
                Text("End Date").font(.caption).foregroundColor(.secondary)
                DatePicker("End", selection: $endDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            
            if endDate < startDate {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text("End date must be after start date").font(.caption).foregroundColor(.orange)
                }
            }
            
            HStack(spacing: 12) {
                Button {
                    isActive = false
                    onClose()
                } label: {
                    Text("Clear").foregroundColor(.red)
                }
                Spacer()
                Button {
                    guard endDate >= startDate else { return }
                    isActive = true
                    onClose()
                } label: {
                    Text("Apply").fontWeight(.semibold)
                }
                .disabled(endDate < startDate)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
    }
}

// MARK: - Edit Budget Sheet
struct EditBudgetSheet: View {
    let department: String
    let projectId: String
    let currentBudget: Double
    let onSave: (Double) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var budgetText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    private var isFormValid: Bool {
        if let value = Double(removeFormatting(from: budgetText)), value >= 0 {
            return true
        }
        return false
    }
    
    // MARK: - Indian Number Formatting Helpers
    
    // Helper to remove formatting (commas, spaces, etc.)
    private func removeFormatting(from value: String) -> String {
        return value.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    // Format number according to Indian numbering system (lakhs, crores)
    private func formatIndianNumber(_ number: Double) -> String {
        let integerPart = Int(number)
        let decimalPart = number - Double(integerPart)
        let integerString = String(integerPart)
        let digits = Array(integerString)
        let count = digits.count
        
        if count < 4 {
            var result = integerString
            if decimalPart > 0.0001 {
                let decimalString = String(format: "%.2f", decimalPart)
                if let dotIndex = decimalString.firstIndex(of: ".") {
                    let afterDot = String(decimalString[decimalString.index(after: dotIndex)...])
                    result += "." + afterDot
                }
            }
            return result
        }
        
        var groups: [String] = []
        var remainingDigits = digits
        
        if remainingDigits.count >= 3 {
            let lastThree = String(remainingDigits.suffix(3))
            groups.append(lastThree)
            remainingDigits = Array(remainingDigits.dropLast(3))
        } else {
            groups.append(String(remainingDigits))
            remainingDigits = []
        }
        
        while remainingDigits.count >= 2 {
            let lastTwo = String(remainingDigits.suffix(2))
            groups.insert(lastTwo, at: 0)
            remainingDigits = Array(remainingDigits.dropLast(2))
        }
        
        if remainingDigits.count == 1 {
            groups.insert(String(remainingDigits[0]), at: 0)
        }
        
        let result = groups.joined(separator: ",")
        var finalResult = result
        if decimalPart > 0.0001 {
            let decimalString = String(format: "%.2f", decimalPart)
            if let dotIndex = decimalString.firstIndex(of: ".") {
                let afterDot = String(decimalString[decimalString.index(after: dotIndex)...])
                finalResult += "." + afterDot
            }
        }
        
        return finalResult
    }
    
    // Method to format amount as user types
    func formatAmountInput(_ input: String) -> String {
        let cleaned = removeFormatting(from: input)
        guard !cleaned.isEmpty else { return "" }
        guard let number = Double(cleaned) else { return cleaned }
        return formatIndianNumber(number)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Edit budget for \(department)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 2)
                }
                
                Section {
                    HStack {
                        TextField("Budget (₹)", text: Binding(
                            get: { budgetText },
                            set: { newValue in
                                budgetText = formatAmountInput(newValue)
                            }
                        ))
                            .keyboardType(.decimalPad)
                        
                        if let amount = Double(removeFormatting(from: budgetText)) {
                            Text(Int(amount).formattedCurrency)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Budget Details").textCase(.uppercase)
                } footer: {
                    Text("Current budget: \(Int(currentBudget).formattedCurrency)")
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isFormValid || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                budgetText = formatIndianNumber(currentBudget)
            }
        }
    }
    
    private func save() {
        guard let newBudget = Double(removeFormatting(from: budgetText)), newBudget >= 0 else {
            errorMessage = "Please enter a valid budget amount"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        onSave(newBudget)
        
        // The onSave closure will handle the async save
        isSaving = false
    }
}

// MARK: - Add Department Sheet For Delete
struct AddDepartmentSheetForDelete: View {
    let projectId: String
    let phaseId: String
    let phaseName: String
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var departmentName: String = ""
    @State private var budgetText: String = "0"
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case name, budget }

    private var isFormValid: Bool {
        !departmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Indian Number Formatting Helpers
    
    // Helper to remove formatting (commas, spaces, etc.)
    private func removeFormatting(from value: String) -> String {
        return value.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    // Format number according to Indian numbering system (lakhs, crores)
    private func formatIndianNumber(_ number: Double) -> String {
        let integerPart = Int(number)
        let decimalPart = number - Double(integerPart)
        let integerString = String(integerPart)
        let digits = Array(integerString)
        let count = digits.count
        
        if count < 4 {
            var result = integerString
            if decimalPart > 0.0001 {
                let decimalString = String(format: "%.2f", decimalPart)
                if let dotIndex = decimalString.firstIndex(of: ".") {
                    let afterDot = String(decimalString[decimalString.index(after: dotIndex)...])
                    result += "." + afterDot
                }
            }
            return result
        }
        
        var groups: [String] = []
        var remainingDigits = digits
        
        if remainingDigits.count >= 3 {
            let lastThree = String(remainingDigits.suffix(3))
            groups.append(lastThree)
            remainingDigits = Array(remainingDigits.dropLast(3))
        } else {
            groups.append(String(remainingDigits))
            remainingDigits = []
        }
        
        while remainingDigits.count >= 2 {
            let lastTwo = String(remainingDigits.suffix(2))
            groups.insert(lastTwo, at: 0)
            remainingDigits = Array(remainingDigits.dropLast(2))
        }
        
        if remainingDigits.count == 1 {
            groups.insert(String(remainingDigits[0]), at: 0)
        }
        
        let result = groups.joined(separator: ",")
        var finalResult = result
        if decimalPart > 0.0001 {
            let decimalString = String(format: "%.2f", decimalPart)
            if let dotIndex = decimalString.firstIndex(of: ".") {
                let afterDot = String(decimalString[decimalString.index(after: dotIndex)...])
                finalResult += "." + afterDot
            }
        }
        
        return finalResult
    }
    
    // Method to format amount as user types
    func formatAmountInput(_ input: String) -> String {
        let cleaned = removeFormatting(from: input)
        guard !cleaned.isEmpty else { return "" }
        guard let number = Double(cleaned) else { return cleaned }
        return formatIndianNumber(number)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add a department to \(phaseName)")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 2)
                }

                Section {
                    TextField("Department name", text: $departmentName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .name)

                    HStack {
                        TextField("Budget (₹)", text: Binding(
                            get: { budgetText },
                            set: { newValue in
                                budgetText = formatAmountInput(newValue)
                            }
                        ))
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .budget)
                        if let amount = Double(removeFormatting(from: budgetText)) {
                            Text(Int(amount).formattedCurrency)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: { Text("Department Details").textCase(.uppercase) } footer: { Text("Budget is optional and can be 0.") }

                if let error = errorMessage {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .navigationTitle("Add Department")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isFormValid || isSaving)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { focusedField = .name }
        }
    }

    private func save() {
        let amount = Double(removeFormatting(from: budgetText)) ?? 0
        isSaving = true
        errorMessage = nil

        Task {
            do {
                // Get customerId from Firebase Auth
                guard let customerId = try? await FirebasePathHelper.shared.fetchEffectiveUserID() else {
                    await MainActor.run {
                        isSaving = false
                        errorMessage = "Customer ID not found. Please log in again."
                    }
                    return
                }
                
                let phaseRef = FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: projectId)
                    .document(phaseId)
                
                // Use updateData with the department key path to properly merge
                try await phaseRef.updateData([
                    "departments.\(departmentName)": amount
                ])
                
                // Update project budget after adding department
                await updateProjectBudget(projectId: projectId, customerId: customerId)
                
                await MainActor.run {
                    isSaving = false
                    onSaved()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Helper function to update project budget
    private func updateProjectBudget(projectId: String, customerId: String) async {
        do {
            let phasesSnapshot = try await FirebasePathHelper.shared
                .phasesCollection(customerId: customerId, projectId: projectId)
                .getDocuments()
            
            var totalBudget: Double = 0
            for doc in phasesSnapshot.documents {
                if let phase = try? doc.data(as: Phase.self) {
                    totalBudget += phase.departments.values.reduce(0, +)
                }
            }
            
            // Update project budget
            try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .updateData([
                    "budget": totalBudget,
                    "updatedAt": Timestamp()
                ])
        } catch {
            print("Error updating project budget: \(error.localizedDescription)")
        }
    }
}
