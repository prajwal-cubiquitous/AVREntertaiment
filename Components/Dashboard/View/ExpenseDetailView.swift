//
//  ExpenseDetailView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/26/25.
//

import SwiftUI
import FirebaseFirestore

struct ExpenseDetailView: View {
    let expense: Expense
    @Environment(\.dismiss) private var dismiss
    @State private var remark: String = ""
    @State private var showingActionSheet = false
    @State private var isProcessing = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    
    private let db = Firestore.firestore()
    private let currentUserPhone: String
    private let currentUserRole: UserRole
    
    init(expense: Expense, role: UserRole? = nil) {
        self.expense = expense
        self.currentUserPhone = UserDefaults.standard.string(forKey: "currentUserPhone") ?? ""
        self.currentUserRole = role ?? .USER
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
                        
                        // Payment Information Card
                        paymentInfoCard
                        
                        // Attachment Card (if exists)
                        if expense.attachmentURL != nil {
                            attachmentCard
                        }
                        
                        // Remark Section
                        remarkSection
                        
                        // Action Buttons
                        actionButtons
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
                    Button("Close") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Approve or Reject"),
                message: Text("Choose an action for this expense"),
                buttons: [
                    .default(Text("Approve")) {
                        processExpense(.approved)
                    },
                    .destructive(Text("Reject")) {
                        processExpense(.rejected)
                    },
                    .cancel()
                ]
            )
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(successMessage)
        }
        .overlay {
            if isProcessing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.medium) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Processing...")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(DesignSystem.Spacing.large)
                .background(Color(.systemGray6))
                .cornerRadius(DesignSystem.CornerRadius.large)
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
                
                // Status Badge
                HStack(spacing: 4) {
                    Image(systemName: expense.status.icon)
                        .font(.caption)
                    
                    Text(expense.status.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(expense.status.color)
                .cornerRadius(8)
            }
            
            // Department and Categories
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Department:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(expense.department)
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
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
                DetailRow(title: "Submitted By", value: expense.submittedBy.formatPhoneNumber)
                DetailRow(title: "Description", value: expense.description)
                
                if let existingRemark = expense.remark, !existingRemark.isEmpty {
                    DetailRow(title: "Current Remark", value: existingRemark)
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Payment Information Card
    private var paymentInfoCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Payment Information")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack {
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
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Attachment Card
    private var attachmentCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Attachment")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: "doc.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
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
                
                Button("View") {
                    // Handle attachment view
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Remark Section
    private var remarkSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("Add Remark")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            TextEditor(text: $remark)
                .font(.subheadline)
                .padding(DesignSystem.Spacing.small)
                .background(Color(.systemGray6))
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            
            Text("Add any comments or instructions for this expense")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            Button {
                HapticManager.impact(.medium)
                showingActionSheet = true
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("Approve or Reject")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.medium)
                .background(Color.accentColor)
                .cornerRadius(DesignSystem.CornerRadius.large)
            }
            .disabled(isProcessing)
        }
    }
    
    // MARK: - Helper Methods
    private func processExpense(_ status: ExpenseStatus) {
        isProcessing = true
        
        Task {
            do {
                // Find the project and update the expense
                let projectsSnapshot: QuerySnapshot
                
                if currentUserRole == .ADMIN {
                    // Admin can approve expenses from all projects
                    projectsSnapshot = try await db.collection("projects_ios").getDocuments()
                } else {
                    // Regular users can approve expenses from their managed projects or where they are temp approver
                    projectsSnapshot = try await db.collection("projects_ios")
                        .whereFilter(
                            Filter.orFilter([
                                Filter.whereField("managerId", isEqualTo: currentUserPhone),
                                Filter.whereField("tempApproverID", isEqualTo: currentUserPhone)
                            ])
                        )
                        .getDocuments()
                }
                
                for projectDoc in projectsSnapshot.documents {
                    guard let expenseId = expense.id else { continue }
                    
                    let expenseRef = projectDoc.reference.collection("expenses").document(expenseId)
                    
                    // Check if expense exists in this project
                    let expenseDoc = try await expenseRef.getDocument()
                    if expenseDoc.exists {
                        var updateData: [String: Any] = [
                            "status": status.rawValue,
                            "approvedAt": Date(),
                            "approvedBy": currentUserPhone
                        ]
                        
                        // Add remark if provided or if admin
                        if currentUserRole == .ADMIN {
                            let adminNote = "Admin approved"
                            updateData["remark"] = adminNote
                        } else if !remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            updateData["remark"] = remark.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        
                        try await expenseRef.updateData(updateData)
                        
                        await MainActor.run {
                            isProcessing = false
                            successMessage = "Expense \(status.rawValue.lowercased()) successfully"
                            showingSuccessAlert = true
                        }
                        return
                    }
                }
                
                await MainActor.run {
                    isProcessing = false
                    // Handle case where expense not found
                }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    // Handle error
                }
            }
        }
    }
}

// MARK: - Detail Row Component
struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

#Preview {
    ExpenseDetailView(expense: Expense.sampleData[0])
} 