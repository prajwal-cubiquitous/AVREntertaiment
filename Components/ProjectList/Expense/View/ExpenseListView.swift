import SwiftUI
import FirebaseFirestore

@available(iOS 14.0, *)
struct ExpenseListView: View {
    let project: Project
    @StateObject private var viewModel: ExpenseListViewModel
    let currentUserPhone: String
    @State private var showingExpenseChat = false
    @State private var selectedExpenseForChat: Expense?
    
    init(project: Project, currentUserPhone: String) {
        self.project = project
        self._viewModel = StateObject(wrappedValue: ExpenseListViewModel(project: project, currentUserPhone : currentUserPhone))
        self.currentUserPhone = currentUserPhone
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(title: "Recent Expenses")
            
            if viewModel.isLoading {
                loadingView
            } else if viewModel.expenses.isEmpty {
                emptyStateView
            } else {
                expensesList
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .onAppear {
            viewModel.fetchExpenses()
        }
        .sheet(isPresented: $viewModel.showingFullList) {
            FullExpenseListView(
                viewModel: viewModel,
                currentUserPhone: currentUserPhone,
                projectId: project.id ?? ""
            )
        }
        .sheet(isPresented: $showingExpenseChat) {
            if let expense = selectedExpenseForChat {
                ExpenseChatView(
                    expense: expense,
                    userPhoneNumber: currentUserPhone,
                    projectId: project.id ?? "",
                    role: .USER // You might want to get this from user context
                )
            }
        }
    }
    
    // MARK: - Loading State
    private var loadingView: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                CompatibleProgressView()
                    .scaleEffect(0.8)
                Text("Loading expenses...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 20)
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
    
    // MARK: - Expenses List
    private var expensesList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.expenses.prefix(5)) { expense in
                ExpenseRowView(
                    expense: expense,
                    onChatTapped: {
                        selectedExpenseForChat = expense
                        showingExpenseChat = true
                    }
                )
            }
            
            Button("View All Expenses (\(viewModel.expenses.count))") {
                viewModel.showingFullList = true
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .padding(.top, 8)
        }
    }
}

// MARK: - Expense Row View
struct ExpenseRowView: View {
    let expense: Expense
    let onChatTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator
            Circle()
                .fill(expense.status.color)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(expense.department)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(expense.amountFormatted)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Text(expense.description)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack {
                    Text(expense.categoriesString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(expense.dateFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if expense.status == .pending{
                // Message Button
                Button {
                    onChatTapped()
                } label: {
                    Image(systemName: "message")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Supporting Views
private struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.secondary)
            .padding(.bottom, 5)
    }
}

// MARK: - Preview
#Preview {
    ExpenseListView(project: Project.sampleData[0], currentUserPhone: "9876543211")
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
} 
