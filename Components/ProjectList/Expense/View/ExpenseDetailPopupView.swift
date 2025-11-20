import SwiftUI
import SafariServices
import FirebaseFirestore
import FirebaseAuth

struct ExpenseDetailPopupView: View {
    let expense: Expense
    @Binding var isPresented: Bool
    @State private var showingAttachment = false
    @State private var showingPaymentProof = false
    @State private var reviewerNote: String = ""
    @State private var showingRemarkEditor = false
    @State private var approverName: String?
    @State private var rejectorName: String?
    @State private var submitterName: String?
    @State private var projectName: String?
    @State private var isLoading = false
    @State private var loadingAction: LoadingAction? = nil
    let onApprove: ((String) async -> Void)?
    let onReject: ((String) async -> Void)?
    let isPendingApproval: Bool
    
    enum LoadingAction {
        case approve
        case reject
    }
    
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
    
    // Helper function to load project name
    private func loadProjectName(projectId: String) async {
        do {
            let customerId = try await FirebasePathHelper.shared.fetchEffectiveUserID()
            let projectDoc = try await FirebasePathHelper.shared
                .projectDocument(customerId: customerId, projectId: projectId)
                .getDocument()
            
            if let projectData = projectDoc.data(),
               let name = projectData["name"] as? String, !name.isEmpty {
                await MainActor.run {
                    projectName = name
                }
            }
        } catch {
            print("Error loading project name for \(projectId): \(error)")
        }
    }
    
    // These would come from your view model in a real implementation
    let budgetBefore: Double = 98000
    let budgetAfter: Double = 90100
    
    init(expense: Expense, 
         isPresented: Binding<Bool>, 
         onApprove: ((String) async -> Void)? = nil,
         onReject: ((String) async -> Void)? = nil,
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
                        if !isLoading {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPresented = false
                            }
                        }
                    }
                    .allowsHitTesting(!isLoading)
                
                // Popup content
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Expense Detail")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        Button {
                            if !isLoading {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPresented = false
                                }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.gray)
                                .font(.title3)
                        }
                        .disabled(isLoading)
                    }
                    .padding()
                    
                    // Content
                    ScrollView {
                        VStack(spacing: 16) {
                            // Project and Phase Info Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Project Information")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if let projectName = projectName {
                                    detailRow(title: "Project:", value: projectName)
                                }
                                
                                if let phaseName = expense.phaseName {
                                    detailRow(title: "Phase:", value: phaseName)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            
                            Divider()
                            
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
                            detailRow(title: "Department:", value: extractDepartmentName(from: expense.department))
                            detailRow(title: "Subcategory:", value: expense.categories.first ?? "")
                            detailRow(title: "Date:", value: expense.dateFormatted)
                            detailRow(title: "Amount:", value: expense.amountFormatted)
                            
                            // Payment Mode
                            detailRow(title: "Payment Mode:", value: expense.modeOfPayment.rawValue)
                            
                            // Submitted By
                            detailRow(title: "Submitted By:", value: submitterName ?? expense.submittedBy.formatPhoneNumber)
                            
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
                                        Task {
                                            isLoading = true
                                            loadingAction = .approve
                                            HapticManager.selection()
                                            await onApprove?(reviewerNote)
                                            isLoading = false
                                            loadingAction = nil
                                        }
                                    }) {
                                        HStack {
                                            if loadingAction == .approve {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(0.8)
                                            } else {
                                                Label("Approve", systemImage: "checkmark")
                                            }
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(loadingAction == .approve ? Color.green.opacity(0.7) : Color.green)
                                        .cornerRadius(8)
                                    }
                                    .disabled(isLoading)
                                    
                                    Button(action: {
                                        Task {
                                            isLoading = true
                                            loadingAction = .reject
                                            HapticManager.selection()
                                            await onReject?(reviewerNote)
                                            isLoading = false
                                            loadingAction = nil
                                        }
                                    }) {
                                        HStack {
                                            if loadingAction == .reject {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(0.8)
                                            } else {
                                                Label("Reject", systemImage: "xmark")
                                            }
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(loadingAction == .reject ? Color.red.opacity(0.7) : Color.red)
                                        .cornerRadius(8)
                                    }
                                    .disabled(isLoading)
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
                .overlay {
                    // Loading overlay
                    if isLoading {
                        ZStack {
                            Color.black.opacity(0.3)
                                .cornerRadius(12)
                            
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                
                                Text(loadingAction == .approve ? "Approving..." : loadingAction == .reject ? "Rejecting..." : "Processing...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            )
                        }
                    }
                }
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
            await loadUserName(phoneNumber: expense.submittedBy)
            await loadProjectName(projectId: expense.projectId)
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