import SwiftUI

struct FullExpenseListView: View {
    @ObservedObject var viewModel: ExpenseListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedExpense: Expense?
    @State private var showingExpenseChat = false
    @State private var selectedExpenseForChat: Expense?
    @State private var showingEditExpense = false
    @State private var selectedExpenseForEdit: Expense?
    @State private var searchText = ""
    @State private var searchType: SearchType = .all
    @State private var showingFilterSheet = false
    
    // Filter states
    @State private var selectedPaymentMode: PaymentMode?
    @State private var selectedPhase: String?
    @State private var selectedDepartment: String?
    @State private var selectedStatus: ExpenseStatus?
    @State private var sortOption: ExpenseSortOption = .dateDescending
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isDateRangeActive = false
    
    let currentUserPhone: String
    let projectId: String
    let project: Project
    let CustomerId: String?
    
    // Computed property for filtered and sorted expenses
    private var filteredExpenses: [Expense] {
        var expenses = viewModel.expenses
        
        // Search filter
        if !searchText.isEmpty {
            expenses = expenses.filter { expense in
                switch searchType {
                case .all:
                    return matchesAllSearch(expense: expense, searchText: searchText)
                case .amount:
                    return matchesAmountSearch(expense: expense, searchText: searchText)
                case .description:
                    return expense.description.localizedCaseInsensitiveContains(searchText)
                case .category:
                    return expense.categoriesString.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        
        // Payment mode filter
        if let paymentMode = selectedPaymentMode {
            expenses = expenses.filter { $0.modeOfPayment == paymentMode }
        }
        
        // Phase filter
        if let phase = selectedPhase {
            expenses = expenses.filter { $0.phaseId == phase || $0.phaseName == phase }
        }
        
        // Department filter
        if let department = selectedDepartment {
            expenses = expenses.filter { $0.department == department }
        }
        
        // Status filter
        if let status = selectedStatus {
            expenses = expenses.filter { $0.status == status }
        }
        
        // Date range filter
        if isDateRangeActive {
            expenses = expenses.filter { expense in
                let expenseDate = expense.createdAt.dateValue()
                return expenseDate >= startDate && expenseDate <= endDate
            }
        }
        
        // Sort
        switch sortOption {
        case .dateDescending:
            expenses = expenses.sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
        case .dateAscending:
            expenses = expenses.sorted { $0.createdAt.dateValue() < $1.createdAt.dateValue() }
        case .amountDescending:
            expenses = expenses.sorted { $0.amount > $1.amount }
        case .amountAscending:
            expenses = expenses.sorted { $0.amount < $1.amount }
        }
        
        return expenses
    }
    
    // Helper methods for search
    private func matchesAllSearch(expense: Expense, searchText: String) -> Bool {
        let searchLower = searchText.lowercased()
        return expense.description.localizedCaseInsensitiveContains(searchText) ||
               expense.categoriesString.localizedCaseInsensitiveContains(searchText) ||
               String(format: "%.0f", expense.amount).contains(searchText) ||
               expense.amountFormatted.lowercased().contains(searchLower)
    }
    
    private func matchesAmountSearch(expense: Expense, searchText: String) -> Bool {
        // Try to parse as number
        if let amount = Double(searchText) {
            return expense.amount == amount || String(format: "%.0f", expense.amount).contains(searchText)
        }
        return expense.amountFormatted.lowercased().contains(searchText.lowercased())
    }
    
    // Get unique values for filters
    private var availablePhases: [String] {
        Array(Set(viewModel.expenses.compactMap { $0.phaseName }.filter { !$0.isEmpty })).sorted()
    }
    
    private var availableDepartments: [String] {
        Array(Set(viewModel.expenses.map { $0.department })).sorted()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.vertical, DesignSystem.Spacing.small)
                    .background(Color(UIColor.systemGroupedBackground))
                
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.expenses.isEmpty {
                    emptyStateView
                } else if filteredExpenses.isEmpty {
                    noResultsView
                } else {
                    expensesList
                }
            }
            .navigationTitle("All Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.selection()
                        showingFilterSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            if hasActiveFilters {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.large, .fraction(0.90)])
        .onAppear {
            viewModel.fetchAllExpenses()
        }
        .overlay {
            if let expense = selectedExpense {
                ExpenseDetailPopupView(
                    expense: expense,
                    isPresented: Binding(
                        get: { selectedExpense != nil },
                        set: { if !$0 { selectedExpense = nil } }
                    ),
                    isPendingApproval: false
                )
            }
        }
        .sheet(isPresented: $showingExpenseChat) {
            if let expense = selectedExpenseForChat {
                ExpenseChatView(
                    expense: expense,
                    userPhoneNumber: currentUserPhone,
                    projectId: projectId,
                    role: .USER // You might want to get this from user context
                )
            }
        }
        .sheet(isPresented: $showingEditExpense) {
            if let expense = selectedExpenseForEdit {
                EditExpenseView(expense: expense, project: project, customerId: CustomerId)
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterAndSortSheet(
                selectedPaymentMode: $selectedPaymentMode,
                selectedPhase: $selectedPhase,
                selectedDepartment: $selectedDepartment,
                selectedStatus: $selectedStatus,
                sortOption: $sortOption,
                startDate: $startDate,
                endDate: $endDate,
                isDateRangeActive: $isDateRangeActive,
                availablePhases: availablePhases,
                availableDepartments: availableDepartments
            )
        }
    }
    
    // Check if any filters are active
    private var hasActiveFilters: Bool {
        selectedPaymentMode != nil ||
        selectedPhase != nil ||
        selectedDepartment != nil ||
        selectedStatus != nil ||
        isDateRangeActive ||
        sortOption != .dateDescending
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search expenses...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: {
                        HapticManager.selection()
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(DesignSystem.Spacing.small)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(DesignSystem.CornerRadius.medium)
            
            // Search Type Picker
            Picker("Search Type", selection: $searchType) {
                ForEach(SearchType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Loading State
    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading expenses...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Expenses")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Expenses will appear here once submitted")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - No Results View
    private var noResultsView: some View {
        VStack(spacing: 15) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Results Found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Try adjusting your search or filters")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if hasActiveFilters || !searchText.isEmpty {
                Button(action: {
                    HapticManager.selection()
                    clearAllFiltersAndSearch()
                }) {
                    Text("Clear Filters")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private func clearAllFiltersAndSearch() {
        searchText = ""
        selectedPaymentMode = nil
        selectedPhase = nil
        selectedDepartment = nil
        selectedStatus = nil
        sortOption = .dateDescending
        isDateRangeActive = false
        startDate = Date()
        endDate = Date()
    }
    
    // MARK: - Expenses List
    private var expensesList: some View {
        List {
            ForEach(filteredExpenses) { expense in
                ExpenseRowView(
                    expense: expense,
                    onChatTapped: {
                        selectedExpenseForChat = expense
                        showingExpenseChat = true
                    },
                    onEditTapped: {
                        selectedExpenseForEdit = expense
                        showingEditExpense = true
                    }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.selection()
                    selectedExpense = expense
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Search Type Enum
enum SearchType: String, CaseIterable {
    case all = "All"
    case amount = "Amount"
    case description = "Description"
    case category = "Category"
    
    var displayName: String {
        rawValue
    }
}

// MARK: - Sort Option Enum
enum ExpenseSortOption: String, CaseIterable {
    case dateDescending = "Date (Newest)"
    case dateAscending = "Date (Oldest)"
    case amountDescending = "Amount (High to Low)"
    case amountAscending = "Amount (Low to High)"
    
    var displayName: String {
        rawValue
    }
}

// MARK: - Filter and Sort Sheet
struct FilterAndSortSheet: View {
    @Binding var selectedPaymentMode: PaymentMode?
    @Binding var selectedPhase: String?
    @Binding var selectedDepartment: String?
    @Binding var selectedStatus: ExpenseStatus?
    @Binding var sortOption: ExpenseSortOption
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isDateRangeActive: Bool
    let availablePhases: [String]
    let availableDepartments: [String]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Sort Section
                Section {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(ExpenseSortOption.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                } header: {
                    Text("Sort Options")
                }
                
                // Filter Section
                Section {
                    // Payment Mode Filter
                    Picker("Payment Mode", selection: $selectedPaymentMode) {
                        Text("All").tag(nil as PaymentMode?)
                        ForEach(PaymentMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode as PaymentMode?)
                        }
                    }
                    
                    // Phase Filter
                    if !availablePhases.isEmpty {
                        Picker("Phase", selection: $selectedPhase) {
                            Text("All").tag(nil as String?)
                            ForEach(availablePhases, id: \.self) { phase in
                                Text(phase).tag(phase as String?)
                            }
                        }
                    }
                    
                    // Department Filter
                    if !availableDepartments.isEmpty {
                        Picker("Department", selection: $selectedDepartment) {
                            Text("All").tag(nil as String?)
                            ForEach(availableDepartments, id: \.self) { dept in
                                Text(dept).tag(dept as String?)
                            }
                        }
                    }
                    
                    // Status Filter
                    Picker("Status", selection: $selectedStatus) {
                        Text("All").tag(nil as ExpenseStatus?)
                        ForEach(ExpenseStatus.allCases, id: \.self) { status in
                            HStack {
                                Circle()
                                    .fill(status.color)
                                    .frame(width: 8, height: 8)
                                Text(status.rawValue.capitalized)
                            }
                            .tag(status as ExpenseStatus?)
                        }
                    }
                } header: {
                    Text("Filters")
                }
                
                // Date Range Filter
                Section {
                    Toggle("Filter by Date Range", isOn: $isDateRangeActive)
                    
                    if isDateRangeActive {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Date Range")
                } footer: {
                    if isDateRangeActive {
                        Text("Only expenses within the selected date range will be shown.")
                    }
                }
                
                // Clear Filters Section
                Section {
                    Button(role: .destructive) {
                        HapticManager.selection()
                        clearAllFilters()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Clear All Filters")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.selection()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func clearAllFilters() {
        selectedPaymentMode = nil
        selectedPhase = nil
        selectedDepartment = nil
        selectedStatus = nil
        sortOption = .dateDescending
        isDateRangeActive = false
        startDate = Date()
        endDate = Date()
    }
} 
