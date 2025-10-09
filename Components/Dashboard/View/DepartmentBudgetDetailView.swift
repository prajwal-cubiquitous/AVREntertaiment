//
//  DepartmentBudgetDetailView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/1/25.
//

import SwiftUI
import FirebaseFirestore

struct DepartmentBudgetDetailView: View {
    let department: String
    let projectId: String
    @StateObject private var viewModel = DepartmentBudgetDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: ExpenseStatus? = nil
    @State private var searchText = ""
    
    private var filteredExpenses: [Expense] {
        var expenses = viewModel.expenses
        
        // Filter by status
        if let status = selectedFilter {
            expenses = expenses.filter { $0.status == status }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            expenses = expenses.filter { expense in
                expense.description.localizedCaseInsensitiveContains(searchText) ||
                expense.categoriesString.localizedCaseInsensitiveContains(searchText) ||
                expense.submittedBy.contains(searchText)
            }
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
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            // Department stats
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Budget")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.totalBudgetFormatted)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.totalSpentFormatted)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.remainingBudgetFormatted)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.remainingBudget >= 0 ? .blue : .red)
                }
            }
            .padding(.horizontal, 20)
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
            
            // Status filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    DepartmentFilterChip(
                        title: "All",
                        isSelected: selectedFilter == nil,
                        color: .blue
                    ) {
                        selectedFilter = nil
                    }
                    
                    ForEach(ExpenseStatus.allCases, id: \.self) { status in
                        DepartmentFilterChip(
                            title: status.rawValue.capitalized,
                            isSelected: selectedFilter == status,
                            color: status.color
                        ) {
                            selectedFilter = selectedFilter == status ? nil : status
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
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
                    DepartmentExpenseRowView(expense: expense, approverName: viewModel.getApproverName(for: expense))
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with amount and status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.amountFormatted)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(expense.dateFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: expense.status.icon)
                            .font(.caption)
                            .foregroundColor(expense.status.color)
                        
                        Text(expense.status.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(expense.status.color)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(expense.status.color.opacity(0.1))
                    .cornerRadius(8)
                    
                    if let approver = approverName {
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
            
            // Remark if available
            if let remark = expense.remark, !remark.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remark:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(remark)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(6)
                }
            }
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
                    print("Loaded project: \(loadedProject)")
                

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
}

#Preview {
    DepartmentBudgetDetailView(
        department: "Costumes",
        projectId: "128YgC7uVnge9RLxVrgG"
    )
}
