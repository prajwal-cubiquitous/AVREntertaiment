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
    let stateManager: DashboardStateManager?
    @Environment(\.dismiss) private var dismiss
    @State private var remark: String = ""
    @State private var showingActionSheet = false
    @State private var isProcessing = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    
    // Budget Context State
    @State private var allocatedBudget: Double = 0
    @State private var spentAmount: Double = 0
    @State private var isLoadingBudget = false
    @State private var phaseName: String? = nil
    @State private var showingFileViewer = false
    
    // User Name State
    @State private var submitterName: String? = nil
    
    private let db = Firestore.firestore()
    private let currentUserPhone: String
    private let currentUserRole: UserRole
    
    // Helper function to extract department name (everything after first underscore)
    private func extractDepartmentName(from departmentString: String) -> String {
        if let underscoreIndex = departmentString.firstIndex(of: "_") {
            let departmentName = String(departmentString[departmentString.index(after: underscoreIndex)...])
            return departmentName.isEmpty ? departmentString : departmentName
        }
        return departmentString
    }
    
    init(expense: Expense, role: UserRole? = nil, stateManager: DashboardStateManager? = nil) {
        self.expense = expense
        self.stateManager = stateManager
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
                        
                        // Budget Context Card (only show for pending expenses)
                        if expense.phaseId != nil && expense.status == .pending {
                            budgetContextCard
                        }
                        
                        // Payment Information Card
                        paymentInfoCard
                        
                        // Receipt Card (if exists)
                        if let attachmentURL = expense.attachmentURL, !attachmentURL.isEmpty {
                            attachmentCard
                        }
                        
                        // Payment Proof Card (if exists)
                        if let paymentProofURL = expense.paymentProofURL, !paymentProofURL.isEmpty {
                            paymentProofCard
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
        .onAppear {
            // Only load budget context for pending expenses (this also loads phase name)
            if expense.phaseId != nil && expense.status == .pending {
                loadBudgetContext()
            } else if expense.phaseId != nil && expense.phaseName == nil {
                // Load phase name if missing for approved/rejected expenses
                loadPhaseName()
            }
            // Load submitter name
            loadSubmitterName()
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
            
            // Phase, Department and Categories
            VStack(alignment: .leading, spacing: 8) {
                // Phase (if available)
                if let phaseName = phaseName ?? expense.phaseName {
                    HStack {
                        Text("Phase:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TruncatedTextWithTooltip(
                            phaseName,
                            font: .subheadline,
                            fontWeight: .medium,
                            foregroundColor: .primary,
                            lineLimit: 1,
                            truncationLength: 15
                        )
                        
                        Spacer()
                    }
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
                    
                    TruncatedTextWithTooltip(
                        expense.categoriesString,
                        font: .subheadline,
                        fontWeight: .medium,
                        foregroundColor: .primary,
                        lineLimit: 2
                    )
                    
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
                DetailRow(title: "Submitted By", value: submitterName ?? (expense.submittedBy.lowercased() == "admin" ? "Admin" : expense.submittedBy.formatPhoneNumber))
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
                        
                        // Remaining portion (green) - after spent portion
                        if remainingBudget > 0 && remainingPercentage > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green)
                                .frame(
                                    width: max(0, min(CGFloat(remainingPercentage / 100) * geometry.size.width, geometry.size.width)),
                                    height: 8
                                )
                                .offset(x: max(0, min(CGFloat(spentPercentage / 100) * geometry.size.width, geometry.size.width)))
                        }
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .redacted(reason: isLoadingBudget ? .placeholder : [])
    }
    
    // MARK: - Budget Context Computed Properties
    private var remainingBudget: Double {
        allocatedBudget - spentAmount
    }
    
    private var spentPercentage: Double {
        guard allocatedBudget > 0 else { return 0 }
        return (spentAmount / allocatedBudget) * 100
    }
    
    private var remainingPercentage: Double {
        guard allocatedBudget > 0 else { return 0 }
        return (remainingBudget / allocatedBudget) * 100
    }
    
    // MARK: - Load Submitter Name
    private func loadSubmitterName() {
        // Check if it's "Admin" first
        if expense.submittedBy.lowercased() == "admin" {
            submitterName = "Admin"
            return
        }
        
        Task {
            do {
                let db = Firestore.firestore()
                // Try to get user by document ID (phone number)
                let userDoc = try await db
                    .collection(FirebaseCollections.users)
                    .document(expense.submittedBy)
                    .getDocument()
                
                if let userData = userDoc.data(),
                   let name = userData["name"] as? String {
                    await MainActor.run {
                        self.submitterName = name
                    }
                    return
                }
                
                // Fallback: try query by phoneNumber field
                let userQuery = try await db
                    .collection(FirebaseCollections.users)
                    .whereField("phoneNumber", isEqualTo: expense.submittedBy)
                    .limit(to: 1)
                    .getDocuments()
                
                if let userData = userQuery.documents.first?.data(),
                   let name = userData["name"] as? String {
                    await MainActor.run {
                        self.submitterName = name
                    }
                } else {
                    // If no user found, use formatted phone number as fallback
                    await MainActor.run {
                        self.submitterName = expense.submittedBy.formatPhoneNumber
                    }
                }
            } catch {
                print("Error loading submitter name for \(expense.submittedBy): \(error)")
                // On error, use formatted phone number as fallback
                await MainActor.run {
                    self.submitterName = expense.submittedBy.formatPhoneNumber
                }
            }
        }
    }
    
    // MARK: - Load Phase Name
    private func loadPhaseName() {
        guard let phaseId = expense.phaseId else { return }
        
        Task {
            do {
                let customerId = try await FirebasePathHelper.shared.fetchEffectiveUserID()
                
                // Fetch phase to get phase name
                let phaseDoc = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: expense.projectId)
                    .document(phaseId)
                    .getDocument()
                
                if let phase = try? phaseDoc.data(as: Phase.self) {
                    await MainActor.run {
                        self.phaseName = phase.phaseName
                    }
                }
            } catch {
                print("Error loading phase name: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Load Budget Context
    private func loadBudgetContext() {
        guard let phaseId = expense.phaseId else { return }
        
        isLoadingBudget = true
        
        Task {
            do {
                let customerId = try await FirebasePathHelper.shared.fetchEffectiveUserID()
                
                // Fetch phase to get department budget
                let phaseDoc = try await FirebasePathHelper.shared
                    .phasesCollection(customerId: customerId, projectId: expense.projectId)
                    .document(phaseId)
                    .getDocument()
                
                if let phase = try? phaseDoc.data(as: Phase.self) {
                    // Get allocated budget for this department in this phase
                    // Try new format first (phaseId_departmentName), then old format (departmentName)
                    let compositeKey = "\(phaseId)_\(expense.department)"
                    var departmentBudget: Double = 0
                    
                    if let newFormatBudget = phase.departments[compositeKey] {
                        departmentBudget = newFormatBudget
                    } else if let oldFormatBudget = phase.departments[expense.department] {
                        departmentBudget = oldFormatBudget
                    }
                    
                    // Store phase name
                    await MainActor.run {
                        self.phaseName = phase.phaseName
                        self.allocatedBudget = departmentBudget
                    }
                    
                    // Fetch all approved expenses for this phase and department
                    let expensesSnapshot = try await FirebasePathHelper.shared
                        .expensesCollection(customerId: customerId, projectId: expense.projectId)
                        .whereField("phaseId", isEqualTo: phaseId)
                        .whereField("department", isEqualTo: expense.department)
                        .whereField("status", isEqualTo: ExpenseStatus.approved.rawValue)
                        .getDocuments()
                    
                    // Calculate total spent
                    var totalSpent: Double = 0
                    for expenseDoc in expensesSnapshot.documents {
                        if let expense = try? expenseDoc.data(as: Expense.self) {
                            totalSpent += expense.amount
                        }
                    }
                    
                    await MainActor.run {
                        self.spentAmount = totalSpent
                        self.isLoadingBudget = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingBudget = false
                    }
                }
            } catch {
                print("Error loading budget context: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingBudget = false
                }
            }
        }
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
            Text("Receipt")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Button(action: {
                HapticManager.selection()
                showingFileViewer = true
            }) {
                HStack {
                    Image(systemName: fileIcon(for: expense.attachmentName ?? ""))
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
                    
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingFileViewer) {
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
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
                
                var customerID: String {
                    get async throws {
                        try await FirebasePathHelper.shared.fetchEffectiveUserID()
                    }
                }
                // Find the project and update the expense
                let projectsSnapshot: QuerySnapshot
                
                if currentUserRole == .ADMIN {
                    // Admin can approve expenses from all projects
                    projectsSnapshot = try await db.collection("customers").document(customerID).collection("projects").getDocuments()
                } else {
                    // Regular users can approve expenses from their managed projects or where they are temp approver
                    projectsSnapshot = try await db.collection("customers").document(customerID).collection("projects")
                        .whereFilter(
                            Filter.orFilter([
                                Filter.whereField("managerIds", arrayContains: currentUserPhone),
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
                            let adminNote = status == .approved ? "Admin approved" : "Admin Rejected"
                            updateData["remark"] = adminNote
                        } else if !remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            updateData["remark"] = remark.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        
                        try await expenseRef.updateData(updateData)
                        
                        // Update state manager immediately for instant UI updates
                        await MainActor.run {
                            // Update state manager directly if available
                            if let stateManager = stateManager,
                               let phaseId = expense.phaseId,
                               let oldStatus = ExpenseStatus(rawValue: expense.status.rawValue) {
                                stateManager.updateExpenseStatus(
                                    expenseId: expenseId,
                                    phaseId: phaseId,
                                    department: expense.department,
                                    oldStatus: oldStatus,
                                    newStatus: status,
                                    amount: expense.amount
                                )
                            }
                            
                            // Also post notification for other listeners
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ExpenseStatusUpdated"),
                                object: nil,
                                userInfo: [
                                    "expenseId": expenseId,
                                    "phaseId": expense.phaseId as Any,
                                    "department": expense.department,
                                    "oldStatus": expense.status.rawValue,
                                    "newStatus": status.rawValue,
                                    "amount": expense.amount
                                ]
                            )
                            
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
