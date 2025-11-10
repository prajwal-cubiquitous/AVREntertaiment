import SwiftUI
import SafariServices
import FirebaseFirestore

struct ExpenseDetailPopupView: View {
    let expense: Expense
    @Binding var isPresented: Bool
    @State private var showingAttachment = false
    @State private var showingPaymentProof = false
    @State private var reviewerNote: String = ""
    @State private var showingRemarkEditor = false
    @State private var approverName: String?
    @State private var rejectorName: String?
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
                            
                            // Payment Mode
                            detailRow(title: "Payment Mode:", value: expense.modeOfPayment.rawValue)
                            
                            // Receipt (Attachment)
                            if let attachmentURL = expense.attachmentURL, !attachmentURL.isEmpty {
                                HStack {
                                    Text("Receipt")
                                        .font(.body)
                                    Spacer()
                                    Button {
                                        HapticManager.selection()
                                        showingAttachment = true
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: fileIcon(for: expense.attachmentName ?? ""))
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14))
                                            Text("View Full")
                                                .foregroundColor(.blue)
                                                .font(.body)
                                        }
                                    }
                                }
                            }
                            
                            // Payment Proof
                            if let paymentProofURL = expense.paymentProofURL, !paymentProofURL.isEmpty {
                                HStack {
                                    Text("Payment Proof")
                                        .font(.body)
                                    Spacer()
                                    Button {
                                        HapticManager.selection()
                                        showingPaymentProof = true
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: fileIcon(for: expense.paymentProofName ?? ""))
                                                .foregroundColor(.green)
                                                .font(.system(size: 14))
                                            Text("View Full")
                                                .foregroundColor(.green)
                                                .font(.body)
                                        }
                                    }
                                }
                            }
                            
                            // Approved By / Rejected By
                            if expense.status == .approved, let approvedBy = expense.approvedBy {
                                detailRow(title: "Approved By:", value: approverName ?? approvedBy)
                            } else if expense.status == .rejected, let rejectedBy = expense.rejectedBy {
                                detailRow(title: "Rejected By:", value: rejectorName ?? rejectedBy)
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
                FileViewerSheet(fileURL: url, fileName: expense.attachmentName)
            }
        }
        .sheet(isPresented: $showingPaymentProof) {
            if let paymentProofURL = expense.paymentProofURL,
               let url = URL(string: paymentProofURL) {
                FileViewerSheet(fileURL: url, fileName: expense.paymentProofName)
            }
        }
        .task {
            await loadApproverRejectorNames()
        }
    }
    
    // MARK: - Helper Methods
    private func loadApproverRejectorNames() async {
        let db = Firestore.firestore()
        
        // Load approver name if approved
        if expense.status == .approved, let approvedBy = expense.approvedBy {
            do {
                let userDoc = try await db
                    .collection(FirebaseCollections.users)
                    .whereField("phoneNumber", isEqualTo: approvedBy)
                    .limit(to: 1)
                    .getDocuments()
                
                if let userData = userDoc.documents.first?.data(),
                   let name = userData["name"] as? String {
                    await MainActor.run {
                        self.approverName = name
                    }
                }
            } catch {
                print("Error loading approver name: \(error)")
            }
        }
        
        // Load rejector name if rejected
        if expense.status == .rejected, let rejectedBy = expense.rejectedBy {
            do {
                let userDoc = try await db
                    .collection(FirebaseCollections.users)
                    .whereField("phoneNumber", isEqualTo: rejectedBy)
                    .limit(to: 1)
                    .getDocuments()
                
                if let userData = userDoc.documents.first?.data(),
                   let name = userData["name"] as? String {
                    await MainActor.run {
                        self.rejectorName = name
                    }
                }
            } catch {
                print("Error loading rejector name: \(error)")
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