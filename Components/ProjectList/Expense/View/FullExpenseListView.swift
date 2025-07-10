import SwiftUI

struct FullExpenseListView: View {
    @ObservedObject var viewModel: ExpenseListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedExpense: Expense?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.expenses.isEmpty {
                    emptyStateView
                } else {
                    expensesList
                }
            }
            .navigationTitle("All Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
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
            
            Text("No Expenses Recorded")
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
    
    // MARK: - Expenses List
    private var expensesList: some View {
        List {
            ForEach(viewModel.expenses) { expense in
                ExpenseRowView(expense: expense)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                    .onTapGesture {
                        selectedExpense = expense
                    }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color(UIColor.systemGroupedBackground))
    }
} 