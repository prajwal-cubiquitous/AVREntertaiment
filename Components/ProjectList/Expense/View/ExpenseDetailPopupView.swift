import SwiftUI
import SafariServices

struct ExpenseDetailPopupView: View {
    let expense: Expense
    @Binding var isPresented: Bool
    @State private var showingAttachment = false
    @State private var reviewerNote: String = ""
    @State private var showingRemarkEditor = false
    let onApprove: ((String) -> Void)?
    let onReject: ((String) -> Void)?
    let isPendingApproval: Bool
    
    // These would come from your view model in a real implementation
    let budgetBefore: Double = 98000
    let budgetAfter: Double = 90100
    
    init(expense: Expense, 
         isPresented: Binding<Bool>, 
         onApprove: ((String) -> Void)? = nil,
         onReject: ((String) -> Void)? = nil,
         isPendingApproval: Bool = false) {
        self.expense = expense
        self._isPresented = isPresented
        self.onApprove = onApprove
        self.onReject = onReject
        self.isPendingApproval = isPendingApproval
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPresented = false
                        }
                    }
                
                // Popup content
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Expense Detail")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.gray)
                                .font(.title3)
                        }
                    }
                    .padding()
                    
                    // Content
                    ScrollView {
                        VStack(spacing: 16) {
                            // Status
                            HStack {
                                Text("Status:")
                                    .font(.body)
                                Spacer()
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(expense.status.color)
                                        .frame(width: 10, height: 10)
                                    Text(expense.status.rawValue.capitalized)
                                        .font(.body)
                                        .foregroundColor(expense.status.color)
                                }
                            }
                            
                            // Basic Info
                            detailRow(title: "Department:", value: expense.department)
                            detailRow(title: "Subcategory:", value: expense.categories.first ?? "")
                            detailRow(title: "Date:", value: expense.dateFormatted)
                            detailRow(title: "Amount:", value: expense.amountFormatted)
                            detailRow(title: "Submitted By", value: expense.submittedBy)
                            
                            // Attachment
                            if let attachmentName = expense.attachmentName {
                                HStack {
                                    Text("Invoice Attachment")
                                        .font(.body)
                                    Spacer()
                                    Button {
                                        showingAttachment = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "doc.text")
                                                .foregroundColor(.blue)
                                            Text("View Full")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Notes
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes:")
                                    .font(.body)
                                Text("\"\(expense.description)\"")
                                    .italic()
                                    .foregroundColor(.secondary)
                            }
                            
                            // Show existing remark if any
                            if let remark = expense.remark {
                                Divider()
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Remark:")
                                        .font(.body)
                                    Text("\"\(remark)\"")
                                        .italic()
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if isPendingApproval {
                                Divider()
                                
                                // Budget Info (only for pending approval)
                                VStack(spacing: 8) {
                                    Text("Budget Remaining BEFORE: ₹\(Int(budgetBefore))")
                                        .font(.body)
                                    Text("Budget Remaining AFTER Approval: ₹\(Int(budgetAfter))")
                                        .font(.body)
                                }
                                
                                // Remark Editor
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Add Remark:")
                                        .font(.body)
                                    TextEditor(text: $reviewerNote)
                                        .frame(height: 100)
                                        .padding(8)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(8)
                                }
                                
                                // Action Buttons (only for pending approval)
                                HStack(spacing: 12) {
                                    Button(action: {
                                        onApprove?(reviewerNote)
                                    }) {
                                        Label("Approve", systemImage: "checkmark")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.green)
                                            .cornerRadius(8)
                                    }
                                    
                                    Button(action: {
                                        onReject?(reviewerNote)
                                    }) {
                                        Label("Reject", systemImage: "xmark")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.red)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .frame(width: min(geometry.size.width * 0.9, 400))
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 10)
            }
        }
        .sheet(isPresented: $showingAttachment) {
            if let attachmentURL = expense.attachmentURL,
               let url = URL(string: attachmentURL) {
                SafariView(url: url)
            }
        }
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            Text(value)
                .font(.body)
        }
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No update needed
    }
} 