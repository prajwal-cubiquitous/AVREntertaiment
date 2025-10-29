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
    @StateObject private var viewModel = DepartmentBudgetDetailViewModel()
    @Environment(\.dismiss) private var dismiss
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
    
    private var filteredExpenses: [Expense] {
        var expenses = viewModel.expenses
        
        // Filter by status
        if let status = selectedFilter {
            expenses = expenses.filter { $0.status == status }
        }
        
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
                        
                        Text("Department Expenses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
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
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            // Department stats
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Total Budget
                    VStack(spacing: 4) {
                        Text("Total Budget")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(viewModel.totalBudgetFormatted)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: geometry.size.width / 3, alignment: .leading)
                    
                    // Spent
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
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: geometry.size.width / 3, alignment: .center)
                    
                    // Remaining
                    VStack(spacing: 4) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(viewModel.remainingBudgetFormatted)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(viewModel.remainingBudget >= 0 ? .blue : .red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.trailing)
                    }
                    .frame(width: geometry.size.width / 3, alignment: .trailing)
                }
            }
            .frame(height: 80)
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)

            // Unified Filter & Sort Menu
            HStack {
                Menu {
                    // Status Section
                    Section("Status") {
                        Button(action: { selectedFilter = nil }) {
                            HStack {
                                Text("All")
                                if selectedFilter == nil { Spacer(); Image(systemName: "checkmark") }
                            }
                        }
                        ForEach(ExpenseStatus.allCases, id: \.self) { status in
                            Button(action: { selectedFilter = status }) {
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

                Spacer()

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
            
            Text("No expenses have been recorded for the \(department) department yet.")
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
    
    var remainingBudget: Double {
        totalBudget - totalSpent
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
                let db = Firestore.firestore()
                
                let projectSnapshot = try await db
                        .collection("projects_ios")
                        .document(projectId)
                        .getDocument()
                    
                let loadedProject = try projectSnapshot.data(as: Project.self)
                

                // Load expenses for the department
                let expensesSnapshot = try await db
                    .collection("projects_ios")
                    .document(projectId)
                    .collection("expenses")
                    .whereField("department", isEqualTo: department)
                    .order(by: "createdAt", descending: true)
                    .getDocuments()
                
                let loadedExpenses = expensesSnapshot.documents.compactMap { doc in
                    try? doc.data(as: Expense.self)
                }
                
                // Calculate totals
                let totalSpent = loadedExpenses
                    .filter { $0.status == .approved }
                    .reduce(0) { $0 + $1.amount }
                
                // Load approver names
                await loadApproverNames(for: loadedExpenses)
                
                await MainActor.run {
                    self.totalBudget = loadedProject.departments[department] ?? 0
                    self.expenses = loadedExpenses
                    self.totalSpent = totalSpent
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
}

#Preview {
    DepartmentBudgetDetailView(
        department: "Costumes",
        projectId: "128YgC7uVnge9RLxVrgG",
        role: .APPROVER,
        phoneNumber: "9876543218"
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
