//
//  ExpenseDetailReadOnlyView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/1/25.
//

import SwiftUI
import FirebaseFirestore

struct ExpenseDetailReadOnlyView: View {
    let expense: Expense
    @Environment(\.dismiss) private var dismiss
    @State private var approverName: String?
    @State private var rejectorName: String?
    @State private var submitterName: String?
    @State private var phaseName: String?
    @State private var allocatedBudget: Double = 0
    @State private var spentAmount: Double = 0
    @State private var isLoadingBudget = false
    
    // Helper function to extract department name (everything after first underscore)
    private func extractDepartmentName(from departmentString: String) -> String {
        if let underscoreIndex = departmentString.firstIndex(of: "_") {
            let departmentName = String(departmentString[departmentString.index(after: underscoreIndex)...])
            return departmentName.isEmpty ? departmentString : departmentName
        }
        return departmentString
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.large) {
                        // Header Card
                        headerCard
                        
                        // Expense Details Card
                        expenseDetailsCard
                        
                        // Budget Context Card (only show for pending expenses)
                        if expense.phaseId != nil && expense.status == .pending {
                            budgetContextCard
                        }
                        
                        // Payment Information Card
                        paymentInfoCard
                        
                        // Attachment Card (if exists)
                        if let attachmentURL = expense.attachmentURL, !attachmentURL.isEmpty {
                            attachmentCard
                        }
                        
                        // Payment Proof Card (if exists)
                        if let paymentProofURL = expense.paymentProofURL, !paymentProofURL.isEmpty {
                            paymentProofCard
                        }
                        
                        // Approval Information Card
                        approvalInfoCard
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.bottom, DesignSystem.Spacing.extraLarge)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Expense Details")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
        .task {
            await loadAllNames()
            // Only load budget context for pending expenses
            if expense.phaseId != nil && expense.status == .pending {
                await loadBudgetContext()
            }
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            // Amount and Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(expense.amountFormatted)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Status Badge with enhanced styling
                HStack(spacing: 6) {
                    Image(systemName: expense.status.icon)
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text(expense.status.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(expense.status.color)
                        .shadow(color: expense.status.color.opacity(0.3), radius: 4, x: 0, y: 2)
                )
            }
            
            // Department and Categories
            VStack(alignment: .leading, spacing: 8) {
                
                HStack {
                    Text("Phase:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let phaseName = phaseName ?? expense.phaseName {
                        HStack(spacing: 4) {
                            TruncatedTextWithTooltip(
                                phaseName,
                                font: .subheadline,
                                fontWeight: .medium,
                                foregroundColor: .primary,
                                lineLimit: 1,
                                truncationLength: 15
                            )
                        }
                    }
                    Spacer()
                }

                HStack {
                    Text("Department:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(extractDepartmentName(from: expense.department))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                HStack {
                    Text("Categories:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(expense.categoriesString)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Spacer()
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Expense Details Card
    private var expenseDetailsCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Expense Details")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: DesignSystem.Spacing.small) {
                DetailRow(title: "Date", value: expense.dateFormatted)
                DetailRow(title: "Submitted By", value: submitterName ?? (expense.submittedBy.lowercased() == "admin" ? "Admin" : expense.submittedBy.formatPhoneNumber))
                DetailRow(title: "Description", value: expense.description)
                
                if let existingRemark = expense.remark, !existingRemark.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Remark:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(existingRemark)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Payment Information Card
    private var paymentInfoCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Payment Information")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                Image(systemName: expense.modeOfPayment.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Payment Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(expense.modeOfPayment.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Attachment Card
    @State private var showingAttachmentViewer = false
    
    private var attachmentCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Receipt")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Button(action: {
                HapticManager.selection()
                showingAttachmentViewer = true
            }) {
                HStack {
                    Image(systemName: fileIcon(for: expense.attachmentName ?? ""))
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(expense.attachmentName ?? "Document")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Tap to view")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .sheet(isPresented: $showingAttachmentViewer) {
            if let urlString = expense.attachmentURL,
               let url = URL(string: urlString) {
                FileViewerSheet(fileURL: url, fileName: expense.attachmentName)
            }
        }
    }
    
    // MARK: - Payment Proof Card
    @State private var showingPaymentProofViewer = false
    
    private var paymentProofCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Payment Proof")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Button(action: {
                HapticManager.selection()
                showingPaymentProofViewer = true
            }) {
                HStack {
                    Image(systemName: fileIcon(for: expense.paymentProofName ?? ""))
                        .font(.title2)
                        .foregroundColor(.green)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(expense.paymentProofName ?? "Document")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Tap to view")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
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
    
    // MARK: - Approval Information Card
    private var approvalInfoCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Approval Information")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: DesignSystem.Spacing.small) {
                // Show updated timestamp if available
                if expense.status == .approved {
                    DetailRow(title: "Approved at", value: expense.updatedAt.dateValue().formatted(date: .abbreviated, time: .shortened))
                } else if expense.status == .rejected {
                    DetailRow(title: "Rejected at", value: expense.updatedAt.dateValue().formatted(date: .abbreviated, time: .shortened))
                }
                
                // Approved By / Rejected By
                if expense.status == .approved, let approvedBy = expense.approvedBy {
                    DetailRow(title: "Approved By", value: approverName ?? approvedBy.formatPhoneNumber)
                } else if expense.status == .rejected, let rejectedBy = expense.rejectedBy {
                    DetailRow(title: "Rejected By", value: rejectorName ?? rejectedBy.formatPhoneNumber)
                }
                
                // Show status-specific information
                if expense.status == .approved {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("This expense has been approved and processed")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                    )
                } else if expense.status == .rejected {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("This expense has been rejected")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    )
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Budget Context Card
    private var budgetContextCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Title with icon
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text("Budget Context")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // Phase and Department Pills
            HStack(spacing: DesignSystem.Spacing.small) {
                if let phaseName = phaseName ?? expense.phaseName {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.caption2)
                        TruncatedTextWithTooltip(
                            phaseName,
                            font: .caption,
                            fontWeight: .medium,
                            foregroundColor: .primary,
                            lineLimit: 1,
                            truncationLength: 15
                        )
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "building.2.fill")
                        .font(.caption2)
                    TruncatedTextWithTooltip(
                        extractDepartmentName(from: expense.department),
                        font: .caption,
                        fontWeight: .medium,
                        foregroundColor: .primary,
                        lineLimit: 1,
                        truncationLength: 15
                    )
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
            
            // Budget Breakdown
            if !isLoadingBudget {
                let remainingBudget = allocatedBudget - spentAmount
                let spentPercentage = allocatedBudget > 0 ? (spentAmount / allocatedBudget) * 100 : 0
                
                VStack(spacing: DesignSystem.Spacing.small) {
                    // Allocated
                    HStack {
                        Text("Allocated")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(Double(allocatedBudget).formattedCurrency)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    // Spent
                    HStack {
                        Text("Spent")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(Double(spentAmount).formattedCurrency)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                    
                    // Remaining
                    HStack {
                        Text("Remaining")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Text(Double(remainingBudget).formattedCurrency)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(remainingBudget >= 0 ? .green : .red)
                            
                            // Percentage pill
                            if allocatedBudget > 0 {
                                Text("\(Int(spentPercentage))%")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(6)
                            }
                        }
                    }
                    
                    // Progress Bar
                    if allocatedBudget > 0 {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 8)
                                
                                // Spent portion (orange) - from left
                                if spentPercentage > 0 {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.orange)
                                        .frame(
                                            width: max(0, min(CGFloat(spentPercentage / 100) * geometry.size.width, geometry.size.width)),
                                            height: 8
                                        )
                                }
                            }
                        }
                        .frame(height: 8)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Methods
    private func loadAllNames() async {
        // Load submitter name - check for "Admin" first
        if expense.submittedBy.lowercased() == "admin" {
            await MainActor.run {
                self.submitterName = "Admin"
            }
        } else {
            await loadUserName(phoneNumber: expense.submittedBy) { name in
                self.submitterName = name
            }
        }
        
        // Load approver name if approved
        if expense.status == .approved, let approvedBy = expense.approvedBy {
            if approvedBy.lowercased() == "admin" {
                await MainActor.run {
                    self.approverName = "Admin"
                }
            } else {
                await loadUserName(phoneNumber: approvedBy) { name in
                    self.approverName = name
                }
            }
        }
        
        // Load rejector name if rejected
        if expense.status == .rejected, let rejectedBy = expense.rejectedBy {
            if rejectedBy.lowercased() == "admin" {
                await MainActor.run {
                    self.rejectorName = "Admin"
                }
            } else {
                await loadUserName(phoneNumber: rejectedBy) { name in
                    self.rejectorName = name
                }
            }
        }
    }
    
    private func loadUserName(phoneNumber: String, completion: @escaping (String?) -> Void) async {
        // Check if it's "Admin" first
        if phoneNumber.lowercased() == "admin" {
            await MainActor.run {
                completion("Admin")
            }
            return
        }
        
        do {
            let db = Firestore.firestore()
            // Try to get user by document ID (phone number)
            let userDoc = try await db
                .collection(FirebaseCollections.users)
                .document(phoneNumber)
                .getDocument()
            
            if let userData = userDoc.data(),
               let name = userData["name"] as? String {
                await MainActor.run {
                    completion(name)
                }
                return
            }
            
            // Fallback: try query by phoneNumber field
            let userQuery = try await db
                .collection(FirebaseCollections.users)
                .whereField("phoneNumber", isEqualTo: phoneNumber)
                .limit(to: 1)
                .getDocuments()
            
            if let userData = userQuery.documents.first?.data(),
               let name = userData["name"] as? String {
                await MainActor.run {
                    completion(name)
                }
            } else {
                // If no user found, return formatted phone number as fallback
                await MainActor.run {
                    completion(phoneNumber.formatPhoneNumber)
                }
            }
        } catch {
            print("Error loading user name for \(phoneNumber): \(error)")
            // On error, return formatted phone number as fallback
            await MainActor.run {
                completion(phoneNumber.formatPhoneNumber)
            }
        }
    }
    
    private func loadBudgetContext() async {
        guard let phaseId = expense.phaseId else { return }
        
        isLoadingBudget = true
        
        do {
            let db = Firestore.firestore()
            
            // Find the project
            let projectsSnapshot = try await db
                .collection("customers")
                .getDocuments()
            
            for customerDoc in projectsSnapshot.documents {
                let projectsRef = customerDoc.reference.collection("projects")
                let projectsQuery = try await projectsRef
                    .whereField("__name__", isEqualTo: expense.projectId)
                    .limit(to: 1)
                    .getDocuments()
                
                if let projectDoc = projectsQuery.documents.first {
                    // Get phase name
                    let phaseDoc = try await projectDoc.reference
                        .collection("phases")
                        .document(phaseId)
                        .getDocument()
                    
                    if let phaseData = phaseDoc.data(),
                       let name = phaseData["name"] as? String {
                        await MainActor.run {
                            self.phaseName = name
                        }
                    }
                    
                    // Get budget information
                    let budgetDoc = try await projectDoc.reference
                        .collection("budgets")
                        .whereField("phaseId", isEqualTo: phaseId)
                        .whereField("department", isEqualTo: expense.department)
                        .limit(to: 1)
                        .getDocuments()
                    
                    if let budgetData = budgetDoc.documents.first?.data() {
                        let allocated = budgetData["allocated"] as? Double ?? 0
                        let spent = budgetData["spent"] as? Double ?? 0
                        
                        await MainActor.run {
                            self.allocatedBudget = allocated
                            self.spentAmount = spent
                            self.isLoadingBudget = false
                        }
                        return
                    }
                }
            }
            
            await MainActor.run {
                self.isLoadingBudget = false
            }
        } catch {
            print("Error loading budget context: \(error)")
            await MainActor.run {
                self.isLoadingBudget = false
            }
        }
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    ExpenseDetailReadOnlyView(expense: Expense.sampleData[0])
}
