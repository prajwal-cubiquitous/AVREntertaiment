import SwiftUI
import FirebaseFirestore

struct ExpenseListView: View {
    let project: Project
    @StateObject private var viewModel: ExpenseListViewModel
    let currentUserPhone: String
    @State private var selectedExpenseForChat: Expense?
    @State private var selectedExpenseForEdit: Expense?
    @State private var selectedExpenseForDetail: Expense?
    @State private var showingExpenseDetail = false
    @EnvironmentObject var authService: FirebaseAuthService
    
    init(project: Project, currentUserPhone: String) {
        self.project = project
        self._viewModel = StateObject(wrappedValue: ExpenseListViewModel(project: project, currentUserPhone: currentUserPhone, customerId: nil))
        self.currentUserPhone = currentUserPhone
    }
    
    private var customerId: String? {
        authService.currentCustomerId
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
            // Update customerId in ViewModel when it becomes available
            if let customerId = customerId {
                viewModel.updateCustomerId(customerId)
            }
            viewModel.fetchExpenses()
        }
        .sheet(isPresented: $viewModel.showingFullList) {
            FullExpenseListView(
                viewModel: viewModel,
                currentUserPhone: currentUserPhone,
                projectId: project.id ?? "",
                project: project, CustomerId: customerId
            )
        }
        .sheet(item: $selectedExpenseForChat) { expense in
            ExpenseChatView(
                expense: expense,
                userPhoneNumber: currentUserPhone,
                projectId: project.id ?? "",
                role: .USER // adjust as needed
            )
        }
        .sheet(item: $selectedExpenseForEdit) { expense in
            EditExpenseView(expense: expense, project: project, customerId: customerId)
        }
        .sheet(isPresented: $showingExpenseDetail) {
            if let expense = selectedExpenseForDetail {
                ExpenseDetailPopupView(
                    expense: expense,
                    isPresented: Binding(
                        get: { selectedExpenseForDetail != nil },
                        set: { if !$0 { selectedExpenseForDetail = nil } }
                    ),
                    isPendingApproval: false
                )
            }

        }

    }
    
    // MARK: - Loading State
    private var loadingView: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                ProgressView()
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
        LazyVStack(spacing: 12) {
            ForEach(viewModel.expenses.prefix(5)) { expense in
                ExpenseRowView(
                    expense: expense,
                    onChatTapped: {
                        selectedExpenseForChat = expense
                    },
                    onEditTapped: {
                        selectedExpenseForEdit = expense
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.selection()
                    selectedExpenseForDetail = expense
                    showingExpenseDetail = true
                }
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
    let onEditTapped: () -> Void
    @State private var showingReceiptViewer = false
    @State private var showingPaymentProofViewer = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator
            Circle()
                .fill(expense.status.color)
                .frame(width: 10, height: 10)
            
            // Content area - tappable
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            if let phaseName = expense.phaseName {
                                Text(phaseName)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .fontWeight(.medium)
                            }
//                            
//                            // Receipt icon indicator
//                            if let attachmentURL = expense.attachmentURL, !attachmentURL.isEmpty {
//                                Image(systemName: fileIcon(for: expense.attachmentName ?? ""))
//                                    .font(.system(size: 12, weight: .medium))
//                                    .foregroundColor(.blue)
//                            }
//                            
//                            // Payment proof icon indicator
//                            if let paymentProofURL = expense.paymentProofURL, !paymentProofURL.isEmpty {
//                                Image(systemName: fileIcon(for: expense.paymentProofName ?? ""))
//                                    .font(.system(size: 12, weight: .medium))
//                                    .foregroundColor(.green)
//                            }
                        }
                        
                        Text(expense.department)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
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
            
            // Action buttons - horizontal layout with compact spacing
            VStack(spacing: 6) {
                // First row: Receipt and Payment Proof icons
                HStack(spacing: 8) {
                    // Receipt icon (if exists) - clickable
                    if let attachmentURL = expense.attachmentURL, !attachmentURL.isEmpty {
                        Button {
                            HapticManager.selection()
                            showingReceiptViewer = true
                        } label: {
                            Image(systemName: fileIcon(for: expense.attachmentName ?? ""))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Payment proof icon (if exists) - clickable
                    if let paymentProofURL = expense.paymentProofURL, !paymentProofURL.isEmpty {
                        Button {
                            HapticManager.selection()
                            showingPaymentProofViewer = true
                        } label: {
                            Image(systemName: fileIcon(for: expense.paymentProofName ?? ""))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Second row: Edit and Message buttons (only for pending)
                if expense.status == .pending {
                    HStack(spacing: 8) {
                        // Edit Button
                        Button {
                            onEditTapped()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.orange)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        
                        // Message Button
                        Button {
                            onChatTapped()
                        } label: {
                            Image(systemName: "message")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(8)
        .sheet(isPresented: $showingReceiptViewer) {
            if let urlString = expense.attachmentURL,
               let url = URL(string: urlString) {
                FileViewerSheet(fileURL: url, fileName: expense.attachmentName)
            }
        }
        .sheet(isPresented: $showingPaymentProofViewer) {
            if let urlString = expense.paymentProofURL,
               let url = URL(string: urlString) {
                FileViewerSheet(fileURL: url, fileName: expense.paymentProofName)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func fileIcon(for fileName: String) -> String {
        let lowercased = fileName.lowercased()
        if lowercased.hasSuffix(".pdf") {
            return "doc.fill"
        } else if lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".jpeg") {
            return "photo.fill"
        } else if lowercased.hasSuffix(".png") {
            return "photo.fill"
        } else {
            return "doc.fill"
        }
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
