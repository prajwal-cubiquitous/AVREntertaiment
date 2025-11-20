import SwiftUI
import FirebaseFirestore

struct NotificationView: View {
    @ObservedObject var viewModel: ProjectListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedExpense: (String, Expense)? // (projectId, expense)
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.pendingExpenses.isEmpty {
                    emptyStateView
                } else {
                    ForEach(viewModel.projects) { project in
                        let projectExpenses = viewModel.pendingExpenses.filter { $0.projectId == project.id }
                        if !projectExpenses.isEmpty {
                            Section(header: Text(project.name)) {
                                ForEach(projectExpenses) { expense in
                                    NotificationItemView(expense: expense)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedExpense = (project.id ?? "", expense)
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Pending Approvals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.fetchPendingExpenses()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .overlay {
                if let (projectId, expense) = selectedExpense {
                    ExpenseDetailPopupView(
                        expense: expense,
                        isPresented: Binding(
                            get: { selectedExpense != nil },
                            set: { if !$0 { selectedExpense = nil } }
                        ),
                        onApprove: { remark in
                            await viewModel.updateExpenseStatus(
                                projectId: projectId,
                                expense: expense,
                                status: .approved,
                                remark: remark
                            )
                            await MainActor.run {
                                selectedExpense = nil
                            }
                        },
                        onReject: { remark in
                            await viewModel.updateExpenseStatus(
                                projectId: projectId,
                                expense: expense,
                                status: .rejected,
                                remark: remark
                            )
                            await MainActor.run {
                                selectedExpense = nil
                            }
                        },
                        isPendingApproval: true
                    )
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Pending Approvals",
            systemImage: "checkmark.circle",
            description: Text("You're all caught up! No expenses need your approval.")
        )
    }
}

struct NotificationItemView: View {
    let expense: Expense
    @State private var submitterName: String?
    
    // Helper function to extract department name (everything after first underscore)
    private func extractDepartmentName(from departmentString: String) -> String {
        if let underscoreIndex = departmentString.firstIndex(of: "_") {
            let departmentName = String(departmentString[departmentString.index(after: underscoreIndex)...])
            return departmentName.isEmpty ? departmentString : departmentName
        }
        return departmentString
    }
    
    // Helper function to load user name from users collection
    private func loadUserName(phoneNumber: String) async {
        do {
            let db = Firestore.firestore()
            var cleanPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanPhone.hasPrefix("+91") {
                cleanPhone = String(cleanPhone.dropFirst(3))
            }
            cleanPhone = cleanPhone.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let userDoc = try await db.collection("users").document(cleanPhone).getDocument()
            
            if let userData = userDoc.data(),
               let name = userData["name"] as? String, !name.isEmpty {
                await MainActor.run {
                    submitterName = name
                }
            }
        } catch {
            print("Error loading user name for \(phoneNumber): \(error)")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(extractDepartmentName(from: expense.department))
                    .font(.headline)
                Spacer()
                Text(expense.amountFormatted)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Text(expense.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label(expense.dateFormatted, systemImage: "calendar")
                Spacer()
                Label("Submitted by: \(submitterName ?? expense.submittedBy.formatPhoneNumber)", systemImage: "person")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("Pending", systemImage: "clock")
                    .foregroundColor(.orange)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
        .task {
            await loadUserName(phoneNumber: expense.submittedBy)
        }
    }
} 
