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
        let expenses = viewModel.expenses
        
        // If a specific phase is selected, filter departments by that phase
        if let selectedPhase = selectedPhase {
            let departments = expenses
                .filter { expense in
                    // Match expenses that have the selected phase name
                    expense.phaseName == selectedPhase
                }
                .map { $0.department }
            
            return Array(Set(departments)).sorted()
        } else {
            // If "All" is selected for phase, show all departments
            return Array(Set(expenses.map { $0.department })).sorted()
        }
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
                    .popover(isPresented: $showingFilterSheet, arrowEdge: .top) {
                        CompactFilterPopover(
                            selectedPaymentMode: $selectedPaymentMode,
                            selectedPhase: $selectedPhase,
                            selectedDepartment: $selectedDepartment,
                            selectedStatus: $selectedStatus,
                            sortOption: $sortOption,
                            startDate: $startDate,
                            endDate: $endDate,
                            isDateRangeActive: $isDateRangeActive,
                            availablePhases: availablePhases,
                            availableDepartments: availableDepartments,
                            onClear: {
                                clearAllFilters()
                            }
                        )
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }
        }
        .presentationDetents([.large, .fraction(0.90)])
        .onAppear {
            viewModel.fetchAllExpenses()
        }
        .onChange(of: selectedPhase) { _ in
            // When phase changes, check if selected department is still valid
            if let selectedDept = selectedDepartment {
                let validDepartments = availableDepartments
                if !validDepartments.contains(selectedDept) {
                    // Clear department if it's not in the filtered list
                    selectedDepartment = nil
                }
            }
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
    
    // Clear all filters
    private func clearAllFilters() {
        selectedPaymentMode = nil
        selectedPhase = nil
        selectedDepartment = nil
        selectedStatus = nil
        sortOption = .dateDescending
        isDateRangeActive = false
        startDate = Date()
        endDate = Date()
        HapticManager.selection()
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

// MARK: - Compact Filter Popover
struct CompactFilterPopover: View {
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
    let onClear: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Filter & Sort")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            
            Divider()
            
            // Scrollable Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Sort Option
                    filterRow(
                        title: "Sort By",
                        value: sortOption.displayName,
                        menu: {
                            ForEach(ExpenseSortOption.allCases, id: \.self) { option in
                                Button(action: {
                                    HapticManager.selection()
                                    sortOption = option
                                }) {
                                    HStack {
                                        Text(option.displayName)
                                        Spacer()
                                        if sortOption == option {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    }
                                }
                            }
                        }
                    )
                    
                    divider
                    
                    // Payment Mode Filter
                    filterRow(
                        title: "Payment Mode",
                        value: selectedPaymentMode?.rawValue ?? "All",
                        menu: {
                            Button(action: {
                                HapticManager.selection()
                                selectedPaymentMode = nil
                            }) {
                                HStack {
                                    Text("All")
                                    Spacer()
                                    if selectedPaymentMode == nil {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                }
                            }
                            
                            ForEach(PaymentMode.allCases, id: \.self) { mode in
                                Button(action: {
                                    HapticManager.selection()
                                    selectedPaymentMode = mode
                                }) {
                                    HStack {
                                        Text(mode.rawValue)
                                        Spacer()
                                        if selectedPaymentMode == mode {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    }
                                }
                            }
                        }
                    )
                    
                    // Phase Filter
                    if !availablePhases.isEmpty {
                        divider
                        
                        filterRow(
                            title: "Phase",
                            value: selectedPhase ?? "All",
                            isTruncatable: selectedPhase != nil,
                            menu: {
                                Button(action: {
                                    HapticManager.selection()
                                    selectedPhase = nil
                                }) {
                                    HStack {
                                        Text("All")
                                        Spacer()
                                        if selectedPhase == nil {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    }
                                }
                                
                                ForEach(availablePhases, id: \.self) { phase in
                                    Button(action: {
                                        HapticManager.selection()
                                        selectedPhase = phase
                                    }) {
                                        HStack {
                                            TruncatedTextWithTooltip(
                                                phase,
                                                font: .body,
                                                foregroundColor: .primary,
                                                lineLimit: 1
                                            )
                                            Spacer()
                                            if selectedPhase == phase {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                        }
                                    }
                                }
                            }
                        )
                    }
                    
                    // Department Filter
                    if !availableDepartments.isEmpty {
                        divider
                        
                        filterRow(
                            title: "Department",
                            value: selectedDepartment ?? "All",
                            isTruncatable: selectedDepartment != nil,
                            menu: {
                                Button(action: {
                                    HapticManager.selection()
                                    selectedDepartment = nil
                                }) {
                                    HStack {
                                        Text("All")
                                        Spacer()
                                        if selectedDepartment == nil {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    }
                                }
                                
                                ForEach(availableDepartments, id: \.self) { dept in
                                    Button(action: {
                                        HapticManager.selection()
                                        selectedDepartment = dept
                                    }) {
                                        HStack {
                                            TruncatedTextWithTooltip(
                                                dept,
                                                font: .body,
                                                foregroundColor: .primary,
                                                lineLimit: 1
                                            )
                                            Spacer()
                                            if selectedDepartment == dept {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                        }
                                    }
                                }
                            }
                        )
                    }
                    
                    // Status Filter
                    divider
                    
                    filterRow(
                        title: "Status",
                        value: {
                            if let status = selectedStatus {
                                return status.rawValue.capitalized
                            } else {
                                return "All"
                            }
                        }(),
                        statusIndicator: selectedStatus?.color,
                        menu: {
                            Button(action: {
                                HapticManager.selection()
                                selectedStatus = nil
                            }) {
                                HStack {
                                    Text("All")
                                    Spacer()
                                    if selectedStatus == nil {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                }
                            }
                            
                            ForEach(ExpenseStatus.allCases, id: \.self) { status in
                                Button(action: {
                                    HapticManager.selection()
                                    selectedStatus = status
                                }) {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(status.color)
                                            .frame(width: 10, height: 10)
                                        Text(status.rawValue.capitalized)
                                        Spacer()
                                        if selectedStatus == status {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    }
                                }
                            }
                        }
                    )
                    
                    // Date Range Toggle
                    divider
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Date Range")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Toggle("", isOn: $isDateRangeActive)
                                .tint(.blue)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        if isDateRangeActive {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Start")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(width: 60, alignment: .leading)
                                    DatePicker("", selection: $startDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("End")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(width: 60, alignment: .leading)
                                    DatePicker("", selection: $endDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }
                    .background(Color(UIColor.systemBackground))
                }
            }
            .frame(maxHeight: 400)
            
            // Fixed Floating Clear Button
            Divider()
            
            Button(action: {
                HapticManager.selection()
                onClear()
            }) {
                HStack {
                    Spacer()
                    Text("Clear All Filters")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.vertical, 14)
            }
            .padding(.horizontal, 16)
            .background(Color(UIColor.systemBackground))
        }
        .frame(width: 280)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
    }
    
    // MARK: - Helper Views
    
    private var divider: some View {
        Divider()
            .padding(.leading, 16)
    }
    
    private func filterRow(
        title: String,
        value: String,
        statusIndicator: Color? = nil,
        isTruncatable: Bool = false,
        @ViewBuilder menu: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            Menu {
                menu()
            } label: {
                HStack(spacing: 8) {
                    if let color = statusIndicator {
                        Circle()
                            .fill(color)
                            .frame(width: 10, height: 10)
                    }
                    if isTruncatable {
                        TruncatedTextWithTooltip(
                            value,
                            font: .system(size: 15, weight: .regular),
                            foregroundColor: .primary,
                            lineLimit: 1
                        )
                    } else {
                        Text(value)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
} 
