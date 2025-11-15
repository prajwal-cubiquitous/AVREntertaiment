import SwiftUI
import FirebaseFirestore

struct ExpenseListView: View {
    let project: Project
    @StateObject private var viewModel: ExpenseListViewModel
    let currentUserPhone: String
    @State private var selectedExpenseForChat: Expense?
    @State private var selectedExpenseForEdit: Expense?
    @State private var selectedExpenseForDetail: Expense?
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
        .task(id: project.id) {
            // Update customerId in ViewModel when it becomes available
            if let customerId = customerId {
                viewModel.updateCustomerId(customerId)
            }
            // Only fetch if customerId is available
            if customerId != nil {
                viewModel.fetchExpenses()
            }
        }
        .onChange(of: customerId) { oldValue, newValue in
            // When customerId becomes available, update and fetch
            if let newValue = newValue, oldValue == nil {
                viewModel.updateCustomerId(newValue)
                viewModel.fetchExpenses()
            }
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
        .sheet(item: $selectedExpenseForDetail) { expense in
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
        HStack(alignment: .top, spacing: 12) {
            
            // Status Dot
            Circle()
                .fill(expense.status.color)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
            
            // Left content (phase, dept, payment, etc.)
            VStack(alignment: .leading, spacing: 6) {
                // Phase and Department
                VStack(alignment: .leading, spacing: 2) {
                    if let phaseName = expense.phaseName {
                        TruncatedTextWithTooltip(
                            phaseName,
                            font: .caption,
                            fontWeight: .medium,
                            foregroundColor: .blue,
                            lineLimit: 1
                        )
                    }
                    TruncatedTextWithTooltip(
                        expense.department,
                        font: .subheadline,
                        fontWeight: .semibold,
                        foregroundColor: .primary,
                        lineLimit: 1
                    )
                }

                // Payment Mode
                Text("\(expense.modeOfPayment.rawValue)")
                    .font(.caption)
                    .foregroundColor(.primary)

                // Category + Date
                HStack(spacing: 6) {
                    TruncatedTextWithTooltip(
                        expense.categoriesString,
                        font: .caption2,
                        foregroundColor: .secondary,
                        lineLimit: 1
                    )
                    
                    //                    Spacer(minLength: 0)
                    
                }
            }

            Spacer()

            // Right Side: Amount & Action Icons
            VStack(alignment: .trailing, spacing: 8) {
                // Amount (Top Right)
                Text(expense.amountFormatted)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                // File Buttons (Receipt & Proof)
                HStack(spacing: 6) {
                    if let attachmentURL = expense.attachmentURL, !attachmentURL.isEmpty {
                        Button {
                            HapticManager.selection()
                            showingReceiptViewer = true
                        } label: {
                            Image(systemName: fileIcon(for: expense.attachmentName ?? ""))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    if let paymentProofURL = expense.paymentProofURL, !paymentProofURL.isEmpty {
                        Button {
                            HapticManager.selection()
                            showingPaymentProofViewer = true
                        } label: {
                            Image(systemName: fileIcon(for: expense.paymentProofName ?? ""))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Edit + Chat (for pending)
                if expense.status == .pending {
                    HStack(spacing: 6) {
                        Button(action: onEditTapped) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)

                        Button(action: onChatTapped) {
                            Image(systemName: "message")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }else{
                    HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .medium))
                                .opacity(0)
                            Image(systemName: "message")
                                .font(.system(size: 14, weight: .medium))
                                .opacity(0)
                        }
                        .allowsHitTesting(false) 
                }
//                Spacer()
                Text(expense.dateFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(10)
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

    // MARK: - Helper
    private func fileIcon(for fileName: String) -> String {
        let lowercased = fileName.lowercased()
        if lowercased.hasSuffix(".pdf") {
            return "doc.text.fill"
        } else if lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".jpeg") || lowercased.hasSuffix(".png") {
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
